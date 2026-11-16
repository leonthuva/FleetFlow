import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_flow/models/delivery.dart';
import 'package:fleet_flow/models/delivery_proof.dart';
import 'package:fleet_flow/services/delivery_service.dart';
import 'package:fleet_flow/services/notification_service.dart';
import 'package:fleet_flow/providers/notification_provider.dart';
import 'package:fleet_flow/screens/proof/proof_of_delivery_screen.dart';
import 'package:fleet_flow/screens/customer/customer_tracking_screen.dart';

void main() {
  test('proof schema uses canonical URL, owner, path and timestamp', () {
    final proof = DeliveryProof(
        id: 'D1',
        deliveryId: 'D1',
        driverId: 'uid',
        storagePath: 'proofs/D1/1.jpg',
        photoURL: 'https://example.com/photo.jpg',
        timestamp: DateTime(2026),
        capturedLocation: {'lat': 6, 'lng': 79});
    final map = proof.toMap();
    expect(map['photoUrl'], proof.photoURL);
    expect(map['timestamp'], isA<Timestamp>());
    expect(map['driverId'], 'uid');
    expect(
        DeliveryProof.fromMap(map, documentId: 'D1').timestamp, DateTime(2026));
  });
  test('proof cannot complete when secure storage is unavailable', () async {
    final service = DeliveryService();
    expect(service.currentDeliveries, isEmpty);
    await expectLater(
        service.submitProofOfDelivery(deliveryId: 'D1', location: {}),
        throwsStateError);
  });
  test('real alert recipients, timestamp and individual read receipt persist',
      () async {
    final db = FakeFirebaseFirestore();
    await db.doc('users/driver').set({'role': 'driver'});
    await db.doc('notificationTargets/managers').set({
      'uids': ['manager']
    });
    final service =
        NotificationService(firestore: db, currentUid: () => 'driver');
    final alert = await service.sendNotification(
        recipientId: 'all_managers',
        message: 'Untrusted free text',
        type: 'status_change',
        metadata: {'deliveryId': 'D1', 'status': 'arrived'});
    final data =
        (await db.doc('notifications/${alert.notificationId}').get()).data()!;
    expect(data['recipientIds'], ['manager']);
    expect(data['message'], isNot('Untrusted free text'));
    expect(data['timestamp'], isA<Timestamp>());
    expect(await service.watch('other').first, isEmpty);
    final manager =
        NotificationService(firestore: db, currentUid: () => 'manager');
    await manager.markAsRead(alert.notificationId);
    expect((await manager.watch('manager').first).single.read, isTrue);
  });
  test('notification provider clears private feed on logout', () async {
    final db = FakeFirebaseFirestore();
    await db.doc('notifications/N1').set({
      'recipientIds': ['u'],
      'timestamp': Timestamp.now()
    });
    final provider = NotificationProvider(
        service: NotificationService(firestore: db, currentUid: () => 'u'));
    addTearDown(provider.dispose);
    provider.bindUser('u');
    await Future<void>.delayed(Duration.zero);
    expect(provider.notifications, hasLength(1));
    provider.bindUser(null);
    expect(provider.notifications, isEmpty);
  });
  testWidgets('authorized tracking renders actual record, never demo default',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await db
        .doc('deliveries/D1')
        .set({'status': 'cancelled', 'address': 'Colombo'});
    await tester.pumpWidget(MaterialApp(
        home: CustomerTrackingScreen(
            deliveryId: 'D1', service: DeliveryService(firestore: db))));
    await tester.pumpAndSettle();
    expect(find.text('Cancelled'), findsOneWidget);
    expect(find.text('Colombo'), findsOneWidget);
  });
  testWidgets('camera explains local preview and has no sample photo option',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
        home: ProofOfDeliveryScreen(
            delivery: Delivery(id: 'D1', status: 'arrived'))));
    expect(
        find.textContaining('Secure Supabase proof upload is not configured'),
        findsOneWidget);
    await tester.tap(find.text('Tap to Capture Handover Photo'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Demo Sample'), findsNothing);
    await tester.tap(find.text('Take Photo with Camera'));
    await tester.pumpAndSettle();
    expect(find.text('Camera Permission Required'), findsOneWidget);
  });
}
