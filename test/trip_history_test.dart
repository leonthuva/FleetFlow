import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_flow/models/trip.dart';
import 'package:fleet_flow/models/trip_summary.dart';
import 'package:fleet_flow/services/trip_service.dart';

void main() {
  final now = DateTime(2026, 10, 8, 12);

  group('Trip model', () {
    test('toMap/fromMap round-trips all fields', () {
      final trip = Trip(
        id: 'T1',
        driverId: 'd1',
        vehicleId: 'v1',
        startTime: DateTime(2026, 10, 1, 8),
        endTime: DateTime(2026, 10, 1, 10, 30),
        status: TripStatus.completed,
        startLat: 1.5,
        startLng: 2.5,
        endLat: 3.5,
        endLng: 4.5,
        distanceKm: 42.5,
      );
      final data = trip.toMap();
      final copy = Trip.fromMap(data, documentId: 'T1');
      expect(copy.id, 'T1');
      expect(data.containsKey('id'), isFalse);
      expect(data['startTime'], isA<Timestamp>());
      expect(data['endTime'], isA<Timestamp>());
      expect(copy.driverId, 'd1');
      expect(copy.vehicleId, 'v1');
      expect(copy.startTime, trip.startTime);
      expect(copy.endTime, trip.endTime);
      expect(copy.status, TripStatus.completed);
      expect(copy.startLat, 1.5);
      expect(copy.endLng, 4.5);
      expect(copy.distanceKm, 42.5);
    });

    test('fromMap parses real Firestore Timestamp values and document identity',
        () {
      final trip = Trip.fromMap({
        'driverId': 'uid-1',
        'vehicleId': 'vehicle-1',
        'status': TripStatus.active,
        'startTime': Timestamp.fromDate(DateTime(2026, 10, 1, 8)),
        'distanceKm': 10,
      }, documentId: 'doc1');
      expect(trip.id, 'doc1');
      expect(trip.driverId, 'uid-1');
      expect(trip.startTime, DateTime(2026, 10, 1, 8));
      expect(trip.endTime, isNull);
      expect(trip.startLat, isNull);
      expect(trip.distanceKm, 10.0);
    });

    test('fromMap rejects a completed trip without an end timestamp', () {
      expect(
        () => Trip.fromMap(
          {
            'driverId': 'driver-uid',
            'vehicleId': 'vehicle-1',
            'status': TripStatus.completed,
            'startTime': Timestamp.fromDate(now),
          },
          documentId: 'T-invalid',
        ),
        throwsFormatException,
      );
    });

    test('active trip duration is measured up to now', () {
      final trip = Trip(
        id: 'T',
        driverId: 'd',
        vehicleId: 'v',
        startTime: now.subtract(const Duration(hours: 2)),
        status: TripStatus.active,
      );
      expect(trip.isActive, isTrue);
      expect(trip.duration(now: now), const Duration(hours: 2));
    });

    test('averageSpeedKmh is distance over duration, zero when no duration',
        () {
      final start = DateTime(2026, 10, 1, 8);
      final trip = Trip(
        id: 'T',
        driverId: 'd',
        vehicleId: 'v',
        startTime: start,
        endTime: start.add(const Duration(hours: 2)),
        status: TripStatus.completed,
        distanceKm: 100,
      );
      expect(trip.averageSpeedKmh(), 50);
      expect(trip.copyWith(endTime: start).averageSpeedKmh(), 0);
    });

    test('copyWith can clear an end time and coordinates', () {
      final ended = Trip(
        id: 'T',
        driverId: 'driver-uid',
        vehicleId: 'vehicle-1',
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
        status: TripStatus.completed,
        endLat: 1,
        endLng: 2,
      );
      final active = ended.copyWith(
        endTime: null,
        endLat: null,
        endLng: null,
        status: TripStatus.active,
      );
      expect(active.endTime, isNull);
      expect(active.endLat, isNull);
      expect(active.endLng, isNull);
    });
  });

  group('TripSummary', () {
    test('aggregates count, completed, distance and time', () {
      final summary =
          TripSummary.fromTrips(TripService.demoTrips(now), now: now);
      expect(summary.tripCount, 6);
      expect(summary.completedCount, 4);
      expect(summary.totalDistanceKm, closeTo(232.4, 0.001));
      expect(summary.averageDistanceKm, closeTo(232.4 / 6, 0.001));
    });

    test('empty input gives zeros', () {
      final summary = TripSummary.fromTrips(const []);
      expect(summary.tripCount, 0);
      expect(summary.averageDistanceKm, 0);
      expect(summary.totalDuration, Duration.zero);
    });
  });

  group('TripService (local)', () {
    late TripService service;

    setUp(() => service = TripService.localDemo(now: now));

    test('returns trips newest first', () async {
      final trips = await service.fetchTrips();
      expect(trips.length, 6);
      for (var i = 1; i < trips.length; i++) {
        expect(trips[i - 1].startTime.isAfter(trips[i].startTime), isTrue);
      }
    });

    test('filters by driver, vehicle and status', () async {
      final byDriver = await service.fetchTrips(driverId: 'demo-driver-1');
      expect(byDriver.length, 3);
      expect(byDriver.every((t) => t.driverId == 'demo-driver-1'), isTrue);

      final byVehicle = await service.fetchTrips(vehicleId: 'FL-204');
      expect(byVehicle.length, 2);

      final active = await service.fetchTrips(status: TripStatus.active);
      expect(active.single.id, 'TRP-1006');
    });

    test('filters by date range with exclusive end', () async {
      final from = now.subtract(const Duration(days: 4));
      final to = now.subtract(const Duration(days: 1));
      final trips = await service.fetchTrips(from: from, to: to);
      expect(trips.map((t) => t.id), ['TRP-1005', 'TRP-1004', 'TRP-1003']);
    });

    test('limit caps the result size', () async {
      final trips = await service.fetchTrips(limit: 2);
      expect(trips.length, 2);
      expect(trips.first.id, 'TRP-1006');
    });

    test('getTripById finds existing and returns null for unknown', () async {
      expect(
          (await service.getTripById('TRP-1003'))?.driverId, 'demo-driver-1');
      expect(await service.getTripById('nope'), isNull);
    });

    test('saveTrip adds new and replaces existing', () async {
      final newTrip = Trip(
        id: 'TRP-2000',
        driverId: 'demo-driver-3',
        vehicleId: 'FL-412',
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
        status: TripStatus.completed,
        distanceKm: 10,
      );
      await service.saveTrip(newTrip);
      expect((await service.fetchTrips()).length, 7);

      await service.saveTrip(newTrip.copyWith(distanceKm: 12));
      expect((await service.fetchTrips()).length, 7);
      expect((await service.getTripById('TRP-2000'))?.distanceKm, 12);
    });
  });
}
