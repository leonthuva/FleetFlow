import 'package:flutter_test/flutter_test.dart';

import 'package:fleet_flow/models/app_notification.dart';
import 'package:fleet_flow/models/trip.dart';
import 'package:fleet_flow/models/user.dart';
import 'package:fleet_flow/providers/history_provider.dart';
import 'package:fleet_flow/services/trip_alert_service.dart';
import 'package:fleet_flow/services/trip_service.dart';

class _SentAlert {
  final String recipientId;
  final String message;
  final String type;
  final String? title;
  final Map<String, dynamic>? metadata;

  _SentAlert(this.recipientId, this.message, this.type, this.title, this.metadata);
}

void main() {
  final now = DateTime(2026, 10, 8, 12);

  late List<_SentAlert> sent;

  Future<void> record({
    required String recipientId,
    required String message,
    required String type,
    String? title,
    Map<String, dynamic>? metadata,
  }) async {
    sent.add(_SentAlert(recipientId, message, type, title, metadata));
  }

  Future<void> failing({
    required String recipientId,
    required String message,
    required String type,
    String? title,
    Map<String, dynamic>? metadata,
  }) async {
    throw Exception('push failed');
  }

  late TripAlertService alerts;

  setUp(() {
    sent = [];
    alerts = TripAlertService(sender: record);
  });

  Trip trip(String id, String status, {Duration length = const Duration(hours: 2), double km = 40}) {
    return Trip(
      id: id,
      driverId: 'Marcus Vance',
      vehicleId: 'FL-101',
      startTime: now.subtract(length),
      endTime: status == TripStatus.active ? null : now,
      status: status,
      distanceKm: km,
    );
  }

  group('TripAlertService', () {
    test('trip completed alert goes to managers with trip details', () async {
      final result = await alerts.notifyTripCompleted(trip('T1', TripStatus.completed, km: 72.4));

      expect(result, isTrue);
      final alert = sent.single;
      expect(alert.recipientId, 'all_managers');
      expect(alert.title, 'Trip Completed');
      expect(alert.type, NotificationType.statusChange);
      expect(alert.message, contains('Marcus Vance'));
      expect(alert.message, contains('T1'));
      expect(alert.message, contains('72.4 km'));
      expect(alert.metadata?['tripId'], 'T1');
    });

    test('completed alert is sent once per trip and only for completed trips', () async {
      final completed = trip('T1', TripStatus.completed);
      expect(await alerts.notifyTripCompleted(completed), isTrue);
      expect(await alerts.notifyTripCompleted(completed), isFalse);
      expect(await alerts.notifyTripCompleted(trip('T2', TripStatus.active)), isFalse);
      expect(await alerts.notifyTripCompleted(trip('T3', TripStatus.cancelled)), isFalse);
      expect(sent.length, 1);
    });

    test('long active trip raises a safety alert once; short trips do not', () async {
      final long = trip('L1', TripStatus.active, length: const Duration(hours: 5));
      expect(await alerts.notifyLongTrip(long, now: now), isTrue);
      expect(await alerts.notifyLongTrip(long, now: now), isFalse);
      expect(await alerts.notifyLongTrip(trip('S1', TripStatus.active), now: now), isFalse);

      expect(sent.length, 1);
      expect(sent.single.type, NotificationType.safetyAlert);
      expect(sent.single.title, 'Long-Running Trip');
      expect(sent.single.message, contains('5h 0m'));
    });

    test('completed trips are never flagged as long', () async {
      final done = trip('C1', TripStatus.completed, length: const Duration(hours: 9));
      expect(await alerts.notifyLongTrip(done, now: now), isFalse);
    });

    test('checkLongTrips returns the number of new alerts', () async {
      final trips = [
        trip('L1', TripStatus.active, length: const Duration(hours: 6)),
        trip('L2', TripStatus.active, length: const Duration(hours: 4)),
        trip('S1', TripStatus.active, length: const Duration(hours: 1)),
        trip('C1', TripStatus.completed),
      ];
      expect(await alerts.checkLongTrips(trips, now: now), 2);
      expect(await alerts.checkLongTrips(trips, now: now), 0);
    });
  });

  group('TripService.saveTrip alerts', () {
    test('alerts when a trip becomes completed, not on later re-saves', () async {
      final service = TripService(seed: const [], alerts: alerts);
      final active = trip('T1', TripStatus.active);

      await service.saveTrip(active);
      expect(sent, isEmpty);

      final done = active.copyWith(status: TripStatus.completed, endTime: now);
      await service.saveTrip(done);
      expect(sent.length, 1);

      await service.saveTrip(done.copyWith(distanceKm: 99));
      expect(sent.length, 1);
    });

    test('a failing alert does not block the save, and the alert retries on the next completion', () async {
      var failNext = true;
      final flaky = TripAlertService(sender: ({
        required String recipientId,
        required String message,
        required String type,
        String? title,
        Map<String, dynamic>? metadata,
      }) async {
        if (failNext) throw Exception('push failed');
        sent.add(_SentAlert(recipientId, message, type, title, metadata));
      });
      final service = TripService(seed: const [], alerts: flaky);
      final done = trip('T1', TripStatus.completed);

      await service.saveTrip(done); // alert fails, save must still succeed
      expect((await service.getTripById('T1'))?.id, 'T1');
      expect(sent, isEmpty);

      failNext = false;
      expect(await flaky.notifyTripCompleted(done), isTrue); // not stuck as "already sent"
      expect(sent.length, 1);
    });

    test('works without an alert service', () async {
      final service = TripService(seed: const []);
      await service.saveTrip(trip('T1', TripStatus.completed));
      expect((await service.fetchTrips()).length, 1);
    });
  });

  group('HistoryProvider long-trip check', () {
    final longActive = Trip(
      id: 'L1',
      driverId: 'Marcus Vance',
      vehicleId: 'FL-101',
      startTime: DateTime.now().subtract(const Duration(hours: 6)),
      status: TripStatus.active,
    );

    const manager = AppUser(id: 'm', email: 'm@x.com', displayName: 'Mia', role: UserRole.admin);
    const driver = AppUser(id: 'd', email: 'd@x.com', displayName: 'Marcus Vance', role: UserRole.driver);

    test('manager load flags long trips', () async {
      final provider = HistoryProvider(
        service: TripService(seed: [longActive]),
        alerts: alerts,
      );
      await provider.loadForUser(manager);
      expect(sent.length, 1);
      expect(sent.single.metadata?['tripId'], 'L1');
    });

    test('driver load does not alert', () async {
      final provider = HistoryProvider(
        service: TripService(seed: [longActive]),
        alerts: alerts,
      );
      await provider.loadForUser(driver);
      expect(sent, isEmpty);
      expect(provider.trips.length, 1);
    });

    test('a failing alert sender does not break history loading', () async {
      final provider = HistoryProvider(
        service: TripService(seed: [longActive]),
        alerts: TripAlertService(sender: failing),
      );
      await provider.load();

      expect(provider.errorMessage, isNull);
      expect(provider.trips.length, 1);
      expect(provider.isLoading, isFalse);
    });
  });
}
