import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_flow/core/tracking_code.dart';
import 'package:fleet_flow/models/delivery.dart';
import 'package:fleet_flow/services/delivery_service.dart';

void main() {
  late FakeFirebaseFirestore db;
  late String actor;
  late DeliveryService service;
  const draft = Delivery(
      id: '',
      driverId: 'driver',
      recipientName: 'Recipient',
      recipientPhone: '0771234567',
      pickup: 'Depot',
      address: 'Colombo',
      packageDescription: 'Parcel',
      latitude: 6.9,
      longitude: 79.8);
  setUp(() async {
    db = FakeFirebaseFirestore();
    actor = 'manager';
    service = DeliveryService(firestore: db, currentUid: () => actor);
    await db.doc('users/manager').set({'role': 'admin'});
    await db.doc('users/driver').set({'role': 'driver', 'onShift': true});
  });
  test('allocation, UID assignment and timestamps persist before success',
      () async {
    final id = await service.createAndAssign(draft);
    expect(id, 'DEL-0001');
    final data = (await db.doc('deliveries/$id').get()).data()!;
    expect(data['driverId'], 'driver');
    expect(data['createdAt'], isA<Timestamp>());
    expect(Delivery.fromMap(data, documentId: id).createdAt, isNotNull);
    expect(await service.createAndAssign(draft), 'DEL-0002');
  });
  test('driver stream only returns own assignments', () async {
    await service.createAndAssign(draft);
    await db
        .doc('deliveries/other')
        .set(draft.copyWith(driverId: 'someone').toMap());
    expect(
        (await service.watchDeliveries(driverId: 'driver').first)
            .map((d) => d.id),
        ['DEL-0001']);
  });
  test('valid stages persist, skipping backwards and completion fail',
      () async {
    final id = await service.createAndAssign(draft);
    actor = 'driver';
    await expectLater(
        service.updateStatus(deliveryId: id, newStatus: 'arrived'),
        throwsStateError);
    for (final stage in ['picked_up', 'in_transit', 'arrived']) {
      await service.updateStatus(deliveryId: id, newStatus: stage);
      expect((await db.doc('deliveries/$id').get()).data()!['status'], stage);
    }
    await expectLater(
        service.updateStatus(deliveryId: id, newStatus: 'picked_up'),
        throwsStateError);
    await expectLater(
        service.updateStatus(deliveryId: id, newStatus: 'completed'),
        throwsStateError);
    await expectLater(
        service.submitProofOfDelivery(deliveryId: id, location: {}),
        throwsStateError);
    expect((await db.doc('deliveries/$id').get()).data()!['status'], 'arrived');
  });
  test('ownership, manager creation and cancellation boundaries', () async {
    final id = await service.createAndAssign(draft);
    actor = 'other';
    await expectLater(
        service.updateStatus(deliveryId: id, newStatus: 'picked_up'),
        throwsStateError);
    actor = 'driver';
    await expectLater(service.createAndAssign(draft), throwsStateError);
    await expectLater(service.cancel(id, 'No access'), throwsStateError);
    actor = 'manager';
    await expectLater(service.cancel(id, ' '), throwsArgumentError);
    await service.cancel(id, 'Recipient unavailable');
    await expectLater(service.cancel(id, 'Again'), throwsStateError);
  });
  test('counter conflict cannot overwrite delivery', () async {
    await db.doc('deliveries/DEL-0001').set({'status': 'cancelled'});
    await expectLater(service.createAndAssign(draft), throwsStateError);
    expect((await db.doc('deliveries/DEL-0001').get()).data()!['status'],
        'cancelled');
  });
  test('cancellation audit fields survive Timestamp roundtrip', () {
    final date = DateTime(2026, 11, 16);
    final delivery = const Delivery(id: 'D1', driverId: 'driver').copyWith(
        status: 'cancelled',
        cancelReason: 'Recipient unavailable',
        cancelledAt: date,
        assignedAt: date,
        updatedAt: date,
        createdBy: 'manager');
    final restored = Delivery.fromMap(delivery.toMap(), documentId: 'D1');
    expect(restored.cancelReason, 'Recipient unavailable');
    expect(restored.cancelledAt, date);
    expect(restored.createdBy, 'manager');
    expect(DeliveryStatus.all, contains('cancelled'));
  });
  group('customer tracking link', () {
    test('creation stores a minimal public record with no private data',
        () async {
      await db.doc('users/driver').update({'displayName': 'Nimal Perera'});
      final id = await service.createAndAssign(draft);
      final code = service.lastTrackingCode!;
      expect(TrackingCode.isValid(code), isTrue);
      expect(
          (await db.doc('deliveries/$id').get()).data()!['trackingCode'], code);
      final link = (await db.doc('trackingLinks/$code').get()).data()!;
      expect(link['deliveryId'], id);
      expect(link['status'], 'assigned');
      expect(link['recipientFirstName'], 'Recipient');
      expect(link['driverFirstName'], 'Nimal');
      expect(link.keys.toSet(), {
        'deliveryId',
        'status',
        'recipientFirstName',
        'driverFirstName',
        'createdAt',
        'updatedAt'
      });
      expect(link.toString(), isNot(contains('Colombo')));
      expect(link.toString(), isNot(contains('0771234567')));
    });
    test('driver stages and manager cancellation mirror onto the link',
        () async {
      final id = await service.createAndAssign(draft);
      final code = service.lastTrackingCode!;
      actor = 'driver';
      for (final stage in ['picked_up', 'in_transit', 'arrived']) {
        await service.updateStatus(deliveryId: id, newStatus: stage);
        expect((await db.doc('trackingLinks/$code').get()).data()!['status'],
            stage);
      }
      actor = 'manager';
      await service.cancel(id, 'Recipient absent');
      expect((await db.doc('trackingLinks/$code').get()).data()!['status'],
          'cancelled');
    });
    test('customer lookup streams the status and rejects malformed codes',
        () async {
      await service.createAndAssign(draft);
      final code = service.lastTrackingCode!;
      final info = await service.watchTracking(TrackingCode.format(code)).first;
      expect(info!.status, 'assigned');
      expect(await service.watchTracking('abc').first, isNull);
      expect(await service.watchTracking('AAAAAAAAAAAA').first, isNull);
    });
    test('older deliveries without a tracking code still update', () async {
      await db
          .doc('deliveries/OLD')
          .set(draft.copyWith(status: 'assigned', driverId: 'driver').toMap());
      actor = 'driver';
      await service.updateStatus(deliveryId: 'OLD', newStatus: 'picked_up');
      expect((await db.doc('deliveries/OLD').get()).data()!['status'],
          'picked_up');
    });
  });
}
