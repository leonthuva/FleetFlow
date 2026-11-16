import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_flow/models/vehicle.dart';
import 'package:fleet_flow/providers/driver_provider.dart';
import 'package:fleet_flow/services/delivery_service.dart';
import 'package:fleet_flow/services/vehicle_service.dart';

const van = Vehicle(
    id: 'ignored-client-id',
    licensePlate: ' WP ABC-1234 ',
    model: ' Delivery Van ',
    status: VehicleStatus.available);

void main() {
  late FakeFirebaseFirestore db;
  late VehicleService service;
  setUp(() async {
    db = FakeFirebaseFirestore();
    await db.doc('users/manager').set({'role': 'admin'});
    await db.doc('users/dispatcher').set({'role': 'dispatcher'});
    await db.doc('users/driver').set({
      'role': 'driver',
      'displayName': 'Driver One',
      'onShift': false,
      'email': 'driver@example.test'
    });
    service = VehicleService(firestore: db, currentUid: () => 'manager');
  });

  test(
      'manager create generates document identity, trims fields and persists audit timestamps',
      () async {
    final id = await service.createVehicle(van);
    expect(id, isNotEmpty);
    expect(id, isNot(van.id));
    final data = (await db.doc('vehicles/$id').get()).data()!;
    expect(data['licensePlate'], 'WP ABC-1234');
    expect(data['model'], 'Delivery Van');
    expect(data['status'], VehicleStatus.available);
    expect(data['createdAt'], isA<Timestamp>());
    expect(data['updatedAt'], isA<Timestamp>());
    expect(data.containsKey('id'), isFalse);
    expect((await service.watchVehicles().first).single.id, id);
  });

  test(
      'dispatcher can edit core fields without overwriting legacy attributes or createdAt',
      () async {
    final id = await service.createVehicle(van);
    final before = (await db.doc('vehicles/$id').get()).data()!;
    await db
        .doc('vehicles/$id')
        .update({'type': 'Van', 'currentOdometerKm': 1500});
    final dispatcher =
        VehicleService(firestore: db, currentUid: () => 'dispatcher');
    await dispatcher.updateVehicle(van.copyWith(
        id: id, model: ' Updated Van ', status: VehicleStatus.inUse));
    final data = (await db.doc('vehicles/$id').get()).data()!;
    expect(data['model'], 'Updated Van');
    expect(data['status'], 'in_use');
    expect(data['createdAt'], before['createdAt']);
    expect(data['type'], 'Van');
    expect(data['currentOdometerKm'], 1500);
    expect(data['updatedAt'], isA<Timestamp>());
    await expectLater(dispatcher.updateVehicle(van.copyWith(id: 'missing')),
        throwsA(isA<FirebaseException>()));
  });

  test('blank, oversized and invalid status values never create a vehicle',
      () async {
    for (final invalid in [
      van.copyWith(licensePlate: '  '),
      van.copyWith(licensePlate: 'A' * 33),
      van.copyWith(model: '\t'),
      van.copyWith(model: 'M' * 101),
      van.copyWith(status: 'in-use'),
      van.copyWith(status: 'unknown')
    ]) {
      await expectLater(service.createVehicle(invalid), throwsArgumentError);
    }
    expect((await db.collection('vehicles').get()).docs, isEmpty);
  });

  test('every write requires a current authoritative manager role', () async {
    final id = await service.createVehicle(van);
    for (final uid in <String?>[null, 'driver', 'missing']) {
      final denied = VehicleService(firestore: db, currentUid: () => uid);
      await expectLater(denied.createVehicle(van), throwsStateError);
      await expectLater(
          denied.updateVehicle(van.copyWith(id: id)), throwsStateError);
      await expectLater(denied.assignVehicle(driverId: 'driver', vehicleId: id),
          throwsStateError);
    }
    await db.doc('users/manager').update({'role': 'driver'});
    await expectLater(
        service.updateVehicle(van.copyWith(id: id)), throwsStateError);
    await expectLater(service.assignVehicle(driverId: 'driver', vehicleId: id),
        throwsStateError);
  });

  test(
      'assign and unassign update only the target driver reference and audit time',
      () async {
    final id = await service.createVehicle(van);
    final before = (await db.doc('users/driver').get()).data()!;
    for (final actor in ['manager', 'dispatcher']) {
      final manager = VehicleService(firestore: db, currentUid: () => actor);
      await manager.assignVehicle(driverId: 'driver', vehicleId: id);
      final assigned = (await db.doc('users/driver').get()).data()!;
      expect(assigned['activeVehicleId'], id);
      expect(assigned['updatedAt'], isA<Timestamp>());
      for (final entry in before.entries) {
        expect(assigned[entry.key], entry.value);
      }
      await manager.assignVehicle(driverId: 'driver', vehicleId: '');
      expect(
          (await db.doc('users/driver').get()).data()!['activeVehicleId'], '');
    }
  });

  test(
      'assignment rejects nonexistent or non-driver targets and invalid vehicle references',
      () async {
    final id = await service.createVehicle(van);
    for (final driver in ['missing', 'manager', 'dispatcher']) {
      await expectLater(service.assignVehicle(driverId: driver, vehicleId: id),
          throwsStateError);
    }
    await expectLater(
        service.assignVehicle(driverId: 'driver', vehicleId: 'missing'),
        throwsStateError);
    await expectLater(
        service.assignVehicle(driverId: 'driver', vehicleId: 'bad/path'),
        throwsArgumentError);
    await expectLater(service.assignVehicle(driverId: '', vehicleId: id),
        throwsArgumentError);
    expect(
        (await db.doc('users/driver').get())
            .data()!
            .containsKey('activeVehicleId'),
        isFalse);
  });

  test(
      'roster uses real UID identities and legacy vehicle status reads as canonical',
      () async {
    await db.doc('vehicles/real-id').set({
      'id': 'stale-id',
      'licensePlate': 'LEGACY-1',
      'model': 'Old Van',
      'status': 'in-use'
    });
    final vehicle = (await service.watchVehicles().first).single;
    expect(vehicle.id, 'real-id');
    expect(vehicle.isInUse, isTrue);
    expect(vehicle.toMap()['status'], 'in_use');
    expect(vehicle.toMap().containsKey('id'), isFalse);
    final drivers = await service.watchDrivers().first;
    expect(drivers.single.id, 'driver');
    expect(drivers.single.name, 'Driver One');
  });

  test(
      'manager assignment and edits reach the bound driver provider without reload',
      () async {
    final provider = DriverProvider(
        service: DeliveryService(firestore: db, currentUid: () => 'driver'));
    addTearDown(provider.dispose);
    provider.bindUser('driver');
    await Future<void>.delayed(Duration.zero);
    final id = await service.createVehicle(van);
    await service.assignVehicle(driverId: 'driver', vehicleId: id);
    await Future<void>.delayed(Duration.zero);
    expect(provider.activeVehicle.id, id);
    expect(provider.activeVehicle.licensePlate, 'WP ABC-1234');
    await service.updateVehicle(van.copyWith(
        id: id, model: 'New Model', status: VehicleStatus.maintenance));
    await Future<void>.delayed(Duration.zero);
    expect(provider.activeVehicle.model, 'New Model');
    expect(provider.activeVehicle.isInMaintenance, isTrue);
    await service.assignVehicle(driverId: 'driver', vehicleId: '');
    await Future<void>.delayed(Duration.zero);
    expect(provider.activeVehicle.id, isEmpty);
    expect(provider.activeVehicle.licensePlate, 'Unassigned');
  });
}
