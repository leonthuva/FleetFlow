import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_flow/models/user.dart';
import 'package:fleet_flow/models/trip.dart';
import 'package:fleet_flow/services/trip_service.dart';
import 'package:fleet_flow/providers/history_provider.dart';
import 'package:fleet_flow/services/delivery_service.dart';
import 'package:fleet_flow/screens/history/delivery_history_screen.dart';

void main() {
  test('history uses UID ownership, timestamps and no fixture fallback',
      () async {
    final db = FakeFirebaseFirestore();
    await db.doc('users/uid').set({'role': 'driver'});
    await db.doc('trips/own').set({
      'driverId': 'uid',
      'vehicleId': 'v',
      'status': 'completed',
      'startTime': Timestamp.fromDate(DateTime(2026)),
      'endTime': Timestamp.fromDate(DateTime(2026, 1, 1, 1)),
      'distanceKm': 10
    });
    await db
        .doc('trips/other')
        .set({'driverId': 'other', 'startTime': Timestamp.now()});
    final service = TripService(firestore: db, currentUid: () => 'uid');
    expect((await service.fetchTrips()).map((t) => t.id), ['own']);
    await expectLater(service.fetchTrips(driverId: 'other'), throwsStateError);
    final provider = HistoryProvider(service: service);
    addTearDown(provider.dispose);
    await provider.loadForUser(const AppUser(
        id: 'uid',
        email: 'x@y.z',
        displayName: 'Different display name',
        role: 'driver'));
    expect(provider.driverFilter, 'uid');
    expect(provider.summary.totalDistanceKm, 10);
    await provider.setDriverFilter('other');
    expect(provider.trips.single.id, 'own');
    await db.doc('users/uid').update({'role': 'invalid'});
    await provider.load();
    expect(provider.trips, isEmpty);
    expect(provider.errorMessage, isNotNull);
  });
  test('trip timestamp model roundtrip and duration', () {
    final trip = Trip(
        id: 'T1',
        driverId: 'uid',
        vehicleId: 'v',
        deliveryId: 'D1',
        startTime: DateTime(2026),
        endTime: DateTime(2026, 1, 1, 1),
        status: 'completed',
        distanceKm: 50);
    final copy = Trip.fromMap(trip.toMap(), documentId: 'T1');
    expect(copy.deliveryId, 'D1');
    expect(copy.duration(), const Duration(hours: 1));
    expect(copy.averageSpeedKmh(), 50);
  });
  testWidgets('driver delivery history includes terminal records owned by UID',
      (tester) async {
    final db = FakeFirebaseFirestore();
    for (final entry in [
      ('D1', 'uid', 'completed'),
      ('D2', 'uid', 'cancelled'),
      ('D3', 'uid', 'assigned'),
      ('D4', 'other', 'completed')
    ]) {
      await db
          .doc('deliveries/${entry.$1}')
          .set({'driverId': entry.$2, 'status': entry.$3});
    }
    await tester.pumpWidget(MaterialApp(
        home: DeliveryHistoryScreen(
            user: const AppUser(
                id: 'uid', email: '', displayName: 'Driver', role: 'driver'),
            service: DeliveryService(firestore: db))));
    await tester.pumpAndSettle();
    expect(find.text('D1'), findsOneWidget);
    expect(find.text('D2'), findsOneWidget);
    expect(find.text('D3'), findsNothing);
    expect(find.text('D4'), findsNothing);
  });
}
