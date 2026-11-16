import {readFileSync} from 'node:fs';
import {before,after,beforeEach,test} from 'node:test';
import {initializeTestEnvironment,assertSucceeds,assertFails} from '@firebase/rules-unit-testing';
import {doc,getDoc,setDoc,updateDoc,deleteDoc,getDocs,collection,query,where,serverTimestamp} from 'firebase/firestore';
let env;
const db=uid=>uid?env.authenticatedContext(uid).firestore():env.unauthenticatedContext().firestore();
const write=(uid,path,data)=>setDoc(doc(db(uid),path),data);
const change=(uid,data)=>updateDoc(doc(db(uid),'deliveries/D1'),data);
before(async()=>{env=await initializeTestEnvironment({projectId:'demo-fleetflow',firestore:{rules:readFileSync('../firestore.rules','utf8')}})});
after(async()=>{await env?.cleanup()});
beforeEach(async()=>{
 await env.clearFirestore();
 await env.withSecurityRulesDisabled(async context=>{
  const store=context.firestore();
  for(const [uid,role] of [['manager','admin'],['driver','driver'],['other','driver']])await setDoc(doc(store,'users',uid),{role,onShift:true});
  await setDoc(doc(store,'deliveries/D1'),{driverId:'driver',status:'assigned',recipientName:'Recipient',address:'Colombo'});
  await setDoc(doc(store,'notificationTargets/managers'),{uids:['manager']});
  await setDoc(doc(store,'notifications/N1'),{recipientIds:['manager','driver'],readBy:[]});
 });
});
test('unauthenticated reads and writes denied',async()=>{
 await assertFails(getDoc(doc(db(),'deliveries/D1')));
 await assertFails(write(null,'users/anonymous',{role:'driver'}));
});
test('manager reads all, driver only its assigned query',async()=>{
 await assertSucceeds(getDocs(collection(db('manager'),'deliveries')));
 await assertSucceeds(getDocs(query(collection(db('driver'),'deliveries'),where('driverId','==','driver'))));
 await assertFails(getDocs(collection(db('driver'),'deliveries')));
 await assertFails(getDoc(doc(db('other'),'deliveries/D1')));
});
test('valid driver stages permitted and skips/backwards rejected',async()=>{
 await assertFails(change('driver',{status:'in_transit',updatedAt:serverTimestamp()}));
 await assertSucceeds(change('driver',{status:'picked_up',pickedUpAt:serverTimestamp(),updatedAt:serverTimestamp()}));
 await assertFails(change('driver',{status:'assigned',updatedAt:serverTimestamp()}));
 await assertSucceeds(change('driver',{status:'in_transit',inTransitAt:serverTimestamp(),updatedAt:serverTimestamp()}));
 await assertSucceeds(change('driver',{status:'arrived',arrivedAt:serverTimestamp(),updatedAt:serverTimestamp()}));
 await assertFails(change('driver',{status:'completed',completedAt:serverTimestamp(),updatedAt:serverTimestamp(),proofPhotoUrl:'https://fake'}));
});
test('other driver, reassignment and driver cancellation denied',async()=>{
 await assertFails(change('other',{status:'picked_up',pickedUpAt:serverTimestamp(),updatedAt:serverTimestamp()}));
 await assertFails(change('driver',{driverId:'other'}));
 await assertFails(change('driver',{status:'cancelled',cancelReason:'No',cancelledAt:serverTimestamp(),updatedAt:serverTimestamp()}));
});
test('manager cancellation requires reason and terminal cannot change',async()=>{
 await assertFails(change('manager',{status:'cancelled',cancelReason:'',cancelledAt:serverTimestamp(),updatedAt:serverTimestamp()}));
 await assertSucceeds(change('manager',{status:'cancelled',cancelReason:'Recipient absent',cancelledAt:serverTimestamp(),updatedAt:serverTimestamp()}));
 await assertFails(change('manager',{status:'assigned',updatedAt:serverTimestamp()}));
});
const as=(uid,email)=>env.authenticatedContext(uid,{email}).firestore();
const profile=(extra={})=>({uid:'new',email:'x@y.z',displayName:'X',role:'driver',onShift:false,createdAt:serverTimestamp(),updatedAt:serverTimestamp(),...extra});
test('a new user may self-register only as an off-shift driver',async()=>{
 await assertSucceeds(setDoc(doc(as('new','x@y.z'),'users/new'),profile()));
 await assertSucceeds(setDoc(doc(as('new2','X@Y.Z'),'users/new2'),profile({uid:'new2',email:'x@y.z',phone:'0771234567'})));
});
test('self-registration cannot choose a privileged role or spoof another account',async()=>{
 for(const role of ['admin','dispatcher'])await assertFails(setDoc(doc(as('new','x@y.z'),'users/new'),profile({role})));
 await assertFails(setDoc(doc(as('new','x@y.z'),'users/someone-else'),profile()));
 await assertFails(setDoc(doc(as('new','x@y.z'),'users/new'),profile({email:'other@y.z'})));
 await assertFails(setDoc(doc(as('new','x@y.z'),'users/new'),profile({onShift:true})));
 await assertFails(setDoc(doc(as('new','x@y.z'),'users/new'),profile({isAdmin:true})));
 await assertFails(setDoc(doc(as('new','x@y.z'),'users/new'),profile({displayName:''})));
});
test('users cannot self provision or escalate approved roles',async()=>{
 await assertFails(write('new','users/new',{role:'driver',email:'x@y.z',displayName:'X'}));
 await assertFails(updateDoc(doc(db('driver'),'users/driver'),{role:'admin'}));
});
test('proof documents rejected while secure object storage is unavailable',async()=>{
 await env.withSecurityRulesDisabled(async c=>updateDoc(doc(c.firestore(),'deliveries/D1'),{status:'arrived'}));
 await assertFails(write('driver','deliveryProofs/D1',{driverId:'driver',deliveryId:'D1',photoUrl:'https://fake',storagePath:'proofs/D1/1.jpg',timestamp:serverTimestamp(),capturedLocation:{lat:6,lng:79}}));
});
test('counter initialization and increments are manager-only and bounded',async()=>{
 await assertFails(write('driver','counters/deliveries',{value:1}));
 await assertFails(write('manager','counters/deliveries',{value:1000}));
 await assertSucceeds(write('manager','counters/deliveries',{value:1}));
 await assertFails(write('manager','counters/deliveries',{value:3}));
 await assertSucceeds(write('manager','counters/deliveries',{value:2}));
});
test('manager cannot create a completed delivery or assign non-driver',async()=>{
 await assertFails(write('manager','deliveries/Forged',{driverId:'manager',status:'completed'}));
});
test('notification recipient targeting and reads are restricted',async()=>{
 const message={createdBy:'driver',audience:'managers',recipientRoles:['admin','dispatcher'],recipientIds:['manager'],type:'status_change',timestamp:serverTimestamp(),metadata:{deliveryId:'D1'},readBy:[]};
 await assertSucceeds(write('driver','notifications/N2',message));
 await assertFails(write('driver','notifications/N3',{...message,recipientIds:['other']}));
 await assertFails(getDoc(doc(db('other'),'notifications/N1')));
 await assertSucceeds(updateDoc(doc(db('driver'),'notifications/N1'),{readBy:['driver']}));
 await assertFails(updateDoc(doc(db('driver'),'notifications/N1'),{readBy:['driver','manager']}));
});

test('valid manager create and counter transaction persist atomically',async()=>{
 const store=db('manager');
 const {runTransaction}=await import('firebase/firestore');
 await assertSucceeds(runTransaction(store,async tx=>{
  const counter=doc(store,'counters/deliveries');await tx.get(counter);
  tx.set(counter,{value:1});
  tx.set(doc(store,'deliveries/DEL-0001'),{driverId:'driver',status:'assigned',createdBy:'manager',createdAt:serverTimestamp(),assignedAt:serverTimestamp(),updatedAt:serverTimestamp(),recipientName:'Customer',recipientPhone:'0771234567',pickupAddress:'Depot',address:'Colombo',latitude:6.9,longitude:79.8,priority:'standard'});
 }));
 await assertSucceeds(getDoc(doc(store,'deliveries/DEL-0001')));
});

test('client cannot forge stage timestamps',async()=>{
 const {Timestamp}=await import('firebase/firestore');
 await assertFails(change('driver',{status:'picked_up',pickedUpAt:Timestamp.fromMillis(1),updatedAt:serverTimestamp()}));
});
test('existing proof references cannot bypass blocked completion',async()=>{
 await env.withSecurityRulesDisabled(async c=>{
  await updateDoc(doc(c.firestore(),'deliveries/D1'),{status:'arrived'});
  await setDoc(doc(c.firestore(),'deliveryProofs/D1'),{driverId:'driver',photoUrl:'https://fake'});
 });
 const patch={status:'completed',completedAt:serverTimestamp(),updatedAt:serverTimestamp(),proofPhotoUrl:'https://fake'};
 await assertFails(change('driver',patch));await assertFails(change('manager',patch));
});
test('trips are UID-scoped read-only records until tracking writer approval',async()=>{
 await env.withSecurityRulesDisabled(async c=>setDoc(doc(c.firestore(),'trips/T1'),{driverId:'driver',status:'completed'}));
 await assertSucceeds(getDocs(query(collection(db('driver'),'trips'),where('driverId','==','driver'))));
 await assertFails(getDoc(doc(db('other'),'trips/T1')));
 await assertFails(write('driver','trips/New',{driverId:'driver'}));
 await assertFails(write('manager','trips/New',{driverId:'driver'}));
});

const CODE='ABCDEFGHJKLM';
const linkData=(extra={})=>({deliveryId:'T1',status:'assigned',recipientFirstName:'Kamal',driverFirstName:'Nimal',createdAt:serverTimestamp(),updatedAt:serverTimestamp(),...extra});
const seedTracked=async(status='assigned')=>env.withSecurityRulesDisabled(async c=>{
 const s=c.firestore();
 await setDoc(doc(s,'deliveries/T1'),{driverId:'driver',status,recipientName:'Kamal Silva',trackingCode:CODE,address:'Colombo'});
 await setDoc(doc(s,'trackingLinks/'+CODE),{deliveryId:'T1',status,recipientFirstName:'Kamal'});
});
test('tracking links: anyone can read one by code but nobody can list',async()=>{
 await seedTracked();
 await assertSucceeds(getDoc(doc(db(),'trackingLinks/'+CODE)));
 await assertSucceeds(getDoc(doc(db('other'),'trackingLinks/'+CODE)));
 await assertFails(getDocs(collection(db(),'trackingLinks')));
 await assertFails(getDocs(collection(db('manager'),'trackingLinks')));
 await assertFails(getDoc(doc(db(),'deliveries/T1')));
});
test('tracking links: only a manager creates one, bound to its delivery',async()=>{
 const batchCreate=async(uid,code,extra={},deliveryCode=CODE)=>{
  const store=db(uid);
  const {writeBatch}=await import('firebase/firestore');
  const b=writeBatch(store);
  b.set(doc(store,'deliveries/T2'),{driverId:'driver',status:'assigned',recipientName:'Kamal Silva',trackingCode:deliveryCode,address:'Colombo',createdBy:uid,createdAt:serverTimestamp(),assignedAt:serverTimestamp(),updatedAt:serverTimestamp(),recipientPhone:'0771234567',pickupAddress:'Depot',latitude:6.9,longitude:79.8,priority:'standard'});
  b.set(doc(store,'trackingLinks/'+code),linkData({deliveryId:'T2',...extra}));
  return b.commit();
 };
 await assertSucceeds(batchCreate('manager',CODE));
 await env.clearFirestore();
 await assertFails(batchCreate('driver',CODE));
 await assertFails(batchCreate('manager','SHORT'));
 await assertFails(batchCreate('manager','abcdefghjklm'));
 await assertFails(batchCreate('manager',CODE,{address:'Colombo'}));
 await assertFails(batchCreate('manager',CODE,{phone:'0771234567'}));
 await assertFails(batchCreate('manager',CODE,{status:'completed'}));
 await assertFails(batchCreate('manager',CODE,{},'OTHERCODE234'));
 await assertFails(setDoc(doc(db(),'trackingLinks/'+CODE),linkData()));
});
test('tracking links: status may only mirror the real delivery status',async()=>{
 await seedTracked('arrived');
 const link=uid=>doc(db(uid),'trackingLinks/'+CODE);
 await assertSucceeds(updateDoc(link('driver'),{status:'arrived',updatedAt:serverTimestamp()}));
 await assertFails(updateDoc(link('driver'),{status:'completed',updatedAt:serverTimestamp()}));
 await assertFails(updateDoc(link('other'),{status:'arrived',updatedAt:serverTimestamp()}));
 await assertFails(updateDoc(link(null),{status:'arrived',updatedAt:serverTimestamp()}));
 await assertFails(updateDoc(link('driver'),{status:'arrived',recipientFirstName:'X',updatedAt:serverTimestamp()}));
 await assertFails(updateDoc(link('driver'),{status:'arrived',updatedAt:new Date()}));
 await assertSucceeds(updateDoc(link('manager'),{status:'arrived',updatedAt:serverTimestamp()}));
 await env.withSecurityRulesDisabled(async c=>updateDoc(doc(c.firestore(),'deliveries/T1'),{status:'completed'}));
 await assertSucceeds(updateDoc(link('driver'),{status:'completed',updatedAt:serverTimestamp()}));
 await assertFails(deleteDoc(link('manager')));
});
test('proof intents, locks, verified evidence and completion are server-only even for managers',async()=>{
 for(const actor of ['driver','manager']){
  await assertFails(write(actor,'proofUploads/12345678-1234-4234-8234-123456789abc',{driverId:'driver',state:'pending'}));
  await assertFails(write(actor,'proofUploadLocks/D1',{attemptId:'forged'}));
  await assertFails(getDoc(doc(db(actor),'proofUploads/forged')));
  await assertFails(write(actor,'deliveryProofs/D1',{driverId:'driver',verificationStatus:'verified',storageProvider:'supabase',storagePath:'driver/D1/forged.png'}));
 }
 await env.withSecurityRulesDisabled(async c=>{
  await updateDoc(doc(c.firestore(),'deliveries/D1'),{status:'completed'});
  await setDoc(doc(c.firestore(),'deliveryProofs/D1'),{driverId:'driver',verificationStatus:'verified',storageProvider:'supabase'});
 });
 await assertSucceeds(getDoc(doc(db('driver'),'deliveryProofs/D1')));
 await assertSucceeds(getDoc(doc(db('manager'),'deliveryProofs/D1')));
 await assertFails(getDoc(doc(db('other'),'deliveryProofs/D1')));
 await assertFails(updateDoc(doc(db('manager'),'deliveryProofs/D1'),{storagePath:'replacement'}));
});

// T4: vehicle management and narrowly scoped driver assignment.
const vehicleData=(extra={})=>({licensePlate:'WP ABC-1234',model:'Delivery Van',status:'available',createdAt:serverTimestamp(),updatedAt:serverTimestamp(),...extra});
const seedVehicles=async()=>env.withSecurityRulesDisabled(async c=>{
 const store=c.firestore();
 await setDoc(doc(store,'users/dispatcher'),{role:'dispatcher'});
 await setDoc(doc(store,'vehicles/V1'),vehicleData());
});
const assign=(actor,target='driver',vehicleId='V1',extra={})=>updateDoc(doc(db(actor),'users/'+target),{activeVehicleId:vehicleId,updatedAt:serverTimestamp(),...extra});

test('vehicles: admin and dispatcher can create and edit every canonical status',async()=>{
 await seedVehicles();
 for(const actor of ['manager','dispatcher']){
  for(const status of ['available','in_use','maintenance']){
   await assertSucceeds(write(actor,`vehicles/${actor}-${status}`,vehicleData({status})));
   await assertSucceeds(updateDoc(doc(db(actor),'vehicles/V1'),{licensePlate:'WP NEW-5678',model:'Updated Van',status,updatedAt:serverTimestamp()}));
  }
 }
 await assertSucceeds(getDoc(doc(db('driver'),'vehicles/V1')));
});
test('vehicles: unauthenticated, driver and unprovisioned users cannot mutate inventory',async()=>{
 await seedVehicles();
 for(const actor of [null,'driver','other','unprovisioned']){
  await assertFails(write(actor,'vehicles/Unauthorized',vehicleData()));
  await assertFails(updateDoc(doc(db(actor),'vehicles/V1'),{status:'maintenance',updatedAt:serverTimestamp()}));
  await assertFails(deleteDoc(doc(db(actor),'vehicles/V1')));
 }
 await assertFails(deleteDoc(doc(db('manager'),'vehicles/V1')));
});
test('vehicles: empty, malformed, oversized and noncanonical vehicle fields are denied',async()=>{
 await seedVehicles();
 const invalid=[{licensePlate:''},{licensePlate:'   '},{licensePlate:'\t'},{licensePlate:12},{licensePlate:'A'.repeat(33)},{model:''},{model:'   '},{model:null},{model:'M'.repeat(101)},{status:'in-use'},{status:'completed'},{status:null}];
 for(const fields of invalid){
  await assertFails(write('manager','vehicles/Invalid',vehicleData(fields)));
  await assertFails(updateDoc(doc(db('dispatcher'),'vehicles/V1'),{...fields,updatedAt:serverTimestamp()}));
 }
 await assertFails(write('manager','vehicles/Extra',vehicleData({isAdmin:true})));
 await assertFails(write('manager','vehicles/Missing',{licensePlate:'WP ABC-1234',status:'available',createdAt:serverTimestamp(),updatedAt:serverTimestamp()}));
});
test('vehicles: audit times cannot be forged and unrelated legacy fields are preserved',async()=>{
 await seedVehicles();
 await assertFails(write('manager','vehicles/OldTime',vehicleData({createdAt:new Date(0)})));
 await assertFails(updateDoc(doc(db('manager'),'vehicles/V1'),{status:'maintenance',updatedAt:new Date(0)}));
 await assertFails(updateDoc(doc(db('manager'),'vehicles/V1'),{model:'New',createdAt:serverTimestamp(),updatedAt:serverTimestamp()}));
 await assertFails(updateDoc(doc(db('manager'),'vehicles/V1'),{model:'New',assignedDriverId:'other',updatedAt:serverTimestamp()}));
 await env.withSecurityRulesDisabled(async c=>setDoc(doc(c.firestore(),'vehicles/Legacy'),{licensePlate:'OLD-1',model:'Old Van',status:'in-use',type:'Van',currentOdometerKm:1200}));
 await assertSucceeds(updateDoc(doc(db('manager'),'vehicles/Legacy'),{status:'in_use',updatedAt:serverTimestamp()}));
 const data=(await getDoc(doc(db('manager'),'vehicles/Legacy'))).data();
 if(data.type!=='Van'||data.currentOdometerKm!==1200)throw new Error('Legacy attributes were lost.');
});
test('vehicle assignment: admin and dispatcher may assign or unassign an existing driver',async()=>{
 await seedVehicles();
 for(const actor of ['manager','dispatcher']){
  await assertSucceeds(assign(actor));
  const profile=(await getDoc(doc(db(actor),'users/driver'))).data();
  if(profile.activeVehicleId!=='V1'||profile.role!=='driver'||profile.onShift!==true)throw new Error('Assignment changed unrelated profile fields.');
  await assertSucceeds(assign(actor,'driver',''));
 }
});
test('vehicle assignment: drivers, strangers and anonymous callers cannot assign any driver',async()=>{
 await seedVehicles();
 for(const actor of ['driver','other','unprovisioned',null]){
  await assertFails(assign(actor,'driver'));
  await assertFails(assign(actor,'other'));
  await assertFails(assign(actor,'driver',''));
 }
});
test('vehicle assignment: manager targets must be drivers and vehicle references must exist',async()=>{
 await seedVehicles();
 for(const actor of ['manager','dispatcher']){
  await assertFails(assign(actor,'manager'));
  await assertFails(assign(actor,'dispatcher'));
  await assertFails(assign(actor,'missing'));
  for(const invalid of ['missing','V1/nested/document',null,123])await assertFails(assign(actor,'driver',invalid));
  await assertFails(assign(actor,'driver','V1',{updatedAt:new Date(0)}));
  await assertFails(updateDoc(doc(db(actor),'users/driver'),{activeVehicleId:'V1'}));
 }
});
test('vehicle assignment: even admins cannot change driver roles or other profile fields',async()=>{
 await seedVehicles();
 for(const actor of ['manager','dispatcher']){
  for(const patch of [{role:'admin'},{role:'dispatcher'},{onShift:false},{displayName:'Spoofed'},{email:'spoofed@example.test'},{phone:'123'},{fcmToken:'untrusted'},{uid:'other'},{createdAt:serverTimestamp()}]){
   await assertFails(assign(actor,'driver','V1',patch));
   await assertFails(updateDoc(doc(db(actor),'users/driver'),patch));
  }
 }
});
test('vehicle assignment preserves driver self-service shift updates but not self-assignment',async()=>{
 await seedVehicles();
 await assertSucceeds(updateDoc(doc(db('driver'),'users/driver'),{onShift:false,updatedAt:serverTimestamp()}));
 await assertFails(assign('driver'));
 await assertFails(assign('driver','driver','',{role:'admin'}));
});
