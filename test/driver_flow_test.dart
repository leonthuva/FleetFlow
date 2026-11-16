import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fleet_flow/models/delivery.dart';
import 'package:fleet_flow/providers/driver_provider.dart';
import 'package:fleet_flow/services/delivery_service.dart';

void main() {
  group('Member 2: Delivery Lifecycle State Machine Tests', () {
    test('linear status progression sequence is strictly enforced', () {
      // 1. assigned -> picked_up
      expect(
        DeliveryStatus.isValidTransition(
            DeliveryStatus.assigned, DeliveryStatus.pickedUp),
        isTrue,
      );

      // 2. picked_up -> in_transit
      expect(
        DeliveryStatus.isValidTransition(
            DeliveryStatus.pickedUp, DeliveryStatus.inTransit),
        isTrue,
      );

      // 3. in_transit -> arrived
      expect(
        DeliveryStatus.isValidTransition(
            DeliveryStatus.inTransit, DeliveryStatus.arrived),
        isTrue,
      );

      // 4. arrived -> completed
      expect(
        DeliveryStatus.isValidTransition(
            DeliveryStatus.arrived, DeliveryStatus.completed),
        isTrue,
      );

      // Disallow skipping states
      expect(
        DeliveryStatus.isValidTransition(
            DeliveryStatus.assigned, DeliveryStatus.inTransit),
        isFalse,
      );
      expect(
        DeliveryStatus.isValidTransition(
            DeliveryStatus.assigned, DeliveryStatus.completed),
        isFalse,
      );
      expect(
        DeliveryStatus.isValidTransition(
            DeliveryStatus.pickedUp, DeliveryStatus.completed),
        isFalse,
      );

      // Disallow backwards transitions
      expect(
        DeliveryStatus.isValidTransition(
            DeliveryStatus.inTransit, DeliveryStatus.pickedUp),
        isFalse,
      );
      expect(
        DeliveryStatus.isValidTransition(
            DeliveryStatus.completed, DeliveryStatus.assigned),
        isFalse,
      );

      // Cancellation permitted prior to completion, but not after completion
      expect(
        DeliveryStatus.isValidTransition(
            DeliveryStatus.assigned, DeliveryStatus.cancelled),
        isTrue,
      );
      expect(
        DeliveryStatus.isValidTransition(
            DeliveryStatus.inTransit, DeliveryStatus.cancelled),
        isTrue,
      );
      expect(
        DeliveryStatus.isValidTransition(
            DeliveryStatus.completed, DeliveryStatus.cancelled),
        isFalse,
      );
    });

    test('step index and display names correctly reflect sequence', () {
      expect(DeliveryStatus.stepIndex(DeliveryStatus.assigned), 0);
      expect(DeliveryStatus.stepIndex(DeliveryStatus.pickedUp), 1);
      expect(DeliveryStatus.stepIndex(DeliveryStatus.inTransit), 2);
      expect(DeliveryStatus.stepIndex(DeliveryStatus.arrived), 3);
      expect(DeliveryStatus.stepIndex(DeliveryStatus.completed), 4);

      expect(DeliveryStatus.displayName(DeliveryStatus.assigned), 'Assigned');
      expect(DeliveryStatus.displayName(DeliveryStatus.pickedUp), 'Picked Up');
      expect(
          DeliveryStatus.displayName(DeliveryStatus.inTransit), 'In Transit');
      expect(DeliveryStatus.displayName(DeliveryStatus.arrived), 'Arrived');
      expect(DeliveryStatus.displayName(DeliveryStatus.completed), 'Completed');
    });

    test(
        'Delivery serialization preserves all lifecycle fields and coordinates',
        () {
      final now = DateTime.now();
      final delivery = Delivery(
        id: 'TEST-101',
        driverId: 'drv_test',
        vehicleId: 'veh_test',
        recipientName: 'Apex Health Corp',
        recipientPhone: '+1-555-0100',
        address: '500 Market St, San Francisco, CA',
        latitude: 37.792,
        longitude: -122.401,
        packageDescription: 'Critical Cold Box',
        specialInstructions: 'Ring bell at Gate 4',
        priority: 'urgent',
        status: DeliveryStatus.inTransit,
        createdAt: now,
      );

      final map = delivery.toMap();
      expect(map['id'], 'TEST-101');
      expect(map['recipientName'], 'Apex Health Corp');
      expect(map['status'], DeliveryStatus.inTransit);
      expect(map['latitude'], 37.792);
      expect(map['longitude'], -122.401);

      final restored = Delivery.fromMap(map);
      expect(restored.id, 'TEST-101');
      expect(restored.recipientName, 'Apex Health Corp');
      expect(restored.status, DeliveryStatus.inTransit);
      expect(restored.latitude, 37.792);
      expect(restored.longitude, -122.401);
      expect(restored.isInTransit, isTrue);
      expect(restored.canTransitionTo(DeliveryStatus.arrived), isTrue);
      expect(restored.canTransitionTo(DeliveryStatus.completed), isFalse);
    });
  });

  group('Firestore driver assignments', () {
    late FakeFirebaseFirestore db;
    late DriverProvider provider;
    setUp(() async {
      db = FakeFirebaseFirestore();
      await db.doc('users/driver').set({'role': 'driver'});
      await db
          .doc('deliveries/own')
          .set(const Delivery(id: 'own', driverId: 'driver').toMap());
      await db
          .doc('deliveries/other')
          .set(const Delivery(id: 'other', driverId: 'other').toMap());
      provider = DriverProvider(
          service: DeliveryService(firestore: db, currentUid: () => 'driver'));
    });
    tearDown(() => provider.dispose());
    test('production starts empty, subscribes only to UID and clears on logout',
        () async {
      expect(provider.deliveries, isEmpty);
      provider.bindUser('driver');
      await Future<void>.delayed(Duration.zero);
      expect(provider.deliveries.map((d) => d.id), ['own']);
      provider.bindUser(null);
      expect(provider.deliveries, isEmpty);
    });
    test('stages are persisted and completion remains blocked', () async {
      provider.bindUser('driver');
      await Future<void>.delayed(Duration.zero);
      for (final stage in ['picked_up', 'in_transit', 'arrived']) {
        expect(await provider.advanceDeliveryStatus('own'), isTrue);
        expect((await db.doc('deliveries/own').get()).data()!['status'], stage);
      }
      expect(await provider.advanceDeliveryStatus('own'), isFalse);
      expect(provider.errorMessage, contains('proof'));
      expect(
          (await db.doc('deliveries/own').get()).data()!['status'], 'arrived');
    });
    test('duplicate taps do not submit two transitions', () async {
      provider.bindUser('driver');
      await Future<void>.delayed(Duration.zero);
      final first = provider.advanceDeliveryStatus('own');
      expect(await provider.advanceDeliveryStatus('own'), isFalse);
      expect(await first, isTrue);
      expect((await db.doc('deliveries/own').get()).data()!['status'],
          'picked_up');
    });
    test('shift UI remains available without fabricated shift history', () {
      expect(provider.isShiftActive, isFalse);
      provider.startShift();
      expect(provider.isShiftActive, isTrue);
      provider.endShift();
      expect(provider.shiftEndTime, isNotNull);
    });
  });
}
