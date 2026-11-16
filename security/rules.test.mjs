import {readFileSync} from 'node:fs';
import {before,after,beforeEach,test} from 'node:test';
import {initializeTestEnvironment,assertSucceeds,assertFails} from '@firebase/rules-unit-testing';
import {doc,getDoc,setDoc,updateDoc,getDocs,collection,query,where,serverTimestamp} from 'firebase/firestore';
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
