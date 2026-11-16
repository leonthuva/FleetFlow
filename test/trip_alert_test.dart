import 'package:flutter_test/flutter_test.dart';

import 'package:fleet_flow/models/trip.dart';
import 'package:fleet_flow/services/trip_alert_service.dart';
import 'package:fleet_flow/services/trip_service.dart';

class _Alert {
  final List<String> recipientIds;
  final List<String> recipientRoles;
  final String audience;
  final String title;
  final String message;
  final String type;
  final Map<String, dynamic>? metadata;

  _Alert({
    required this.recipientIds,
    required this.recipientRoles,
    required this.audience,
    required this.title,
    required this.message,
    required this.type,
    this.metadata,
  });
}

void main() {
  final now = DateTime(2026, 10, 8, 12);
  final sent = <_Alert>[];

  TripAlertService alerts({bool fail = false}) => TripAlertService(
        managerTargets: () async => ['manager-uid-1', 'dispatcher-uid-1'],
        sender: ({
          required recipientIds,
          required recipientRoles,
          required audience,
          required title,
          required message,
          required type,
          metadata,
        }) async {
          if (fail) throw StateError('notification service unavailable');
          sent.add(_Alert(
            recipientIds: recipientIds,
            recipientRoles: recipientRoles,
            audience: audience,
            title: title,
            message: message,
            type: type,
            metadata: metadata,
          ));
        },
      );

  Trip trip(String id, String status,
      {Duration length = const Duration(hours: 2), double km = 40}) {
    return Trip(
      id: id,
      driverId: 'driver-uid-1',
      vehicleId: 'vehicle-1',
      startTime: now.subtract(length),
      endTime: status == TripStatus.active ? null : now,
      status: status,
      distanceKm: km,
    );
  }

  setUp(() => sent.clear());

  test(
      'completion alert uses concrete manager UID targets and canonical fields',
      () async {
    final service = alerts();
    expect(await service.notifyTripCompleted(trip('T1', TripStatus.completed)),
        isTrue);
    expect(sent.single.recipientIds, ['manager-uid-1', 'dispatcher-uid-1']);
    expect(sent.single.recipientRoles, ['admin', 'dispatcher']);
    expect(sent.single.audience, 'managers');
    expect(sent.single.type, 'status_change');
    expect(sent.single.metadata?['driverId'], 'driver-uid-1');
  });

  test('completion alert is sent once per service instance', () async {
    final service = alerts();
    final done = trip('T1', TripStatus.completed);
    expect(await service.notifyTripCompleted(done), isTrue);
    expect(await service.notifyTripCompleted(done), isFalse);
    expect(await service.notifyTripCompleted(trip('T2', TripStatus.active)),
        isFalse);
    expect(sent, hasLength(1));
  });

  test('long active trip raises one safety alert at the configured threshold',
      () async {
    final service = alerts();
    final longTrip =
        trip('L1', TripStatus.active, length: const Duration(hours: 5));
    expect(await service.notifyLongTrip(longTrip, now: now), isTrue);
    expect(await service.notifyLongTrip(longTrip, now: now), isFalse);
    expect(
        await service.notifyLongTrip(trip('S1', TripStatus.active), now: now),
        isFalse);
    expect(sent.single.type, 'safety_alert');
    expect(sent.single.title, 'Long-Running Trip');
    expect(sent.single.message, contains('5h 0m'));
  });

  test('empty manager targets and sender failures are surfaced and retryable',
      () async {
    final emptyTargets = TripAlertService(
      managerTargets: () async => [],
      sender: ({
        required recipientIds,
        required recipientRoles,
        required audience,
        required title,
        required message,
        required type,
        metadata,
      }) async {},
    );
    await expectLater(
      emptyTargets.notifyTripCompleted(trip('T1', TripStatus.completed)),
      throwsStateError,
    );

    final failing = alerts(fail: true);
    await expectLater(
      failing.notifyTripCompleted(trip('T2', TripStatus.completed)),
      throwsStateError,
    );
  });

  test('local demo service alerts on first completion transition only',
      () async {
    final serviceAlerts = alerts();
    final service =
        TripService.localDemo(seed: const [], alerts: serviceAlerts);
    final active = trip('T1', TripStatus.active);

    await service.saveTrip(active);
    expect(sent, isEmpty);

    final done = active.copyWith(status: TripStatus.completed, endTime: now);
    await service.saveTrip(done);
    expect(sent, hasLength(1));

    await service.saveTrip(done.copyWith(distanceKm: 99));
    expect(sent, hasLength(1));
  });

  test(
      'failed completion alert is retried when the completed trip is saved again',
      () async {
    var fail = true;
    final retryableAlerts = TripAlertService(
      managerTargets: () async => ['manager-uid-1'],
      sender: ({
        required recipientIds,
        required recipientRoles,
        required audience,
        required title,
        required message,
        required type,
        metadata,
      }) async {
        if (fail) throw StateError('temporary notification failure');
        sent.add(_Alert(
          recipientIds: recipientIds,
          recipientRoles: recipientRoles,
          audience: audience,
          title: title,
          message: message,
          type: type,
          metadata: metadata,
        ));
      },
    );
    final service =
        TripService.localDemo(seed: const [], alerts: retryableAlerts);
    final done = trip('T-retry', TripStatus.completed);

    await expectLater(service.saveTrip(done), throwsStateError);
    fail = false;
    await service.saveTrip(done);
    expect(sent, hasLength(1));
  });

  test('long-trip scan counts only newly sent alerts', () async {
    final service = alerts();
    final trips = [
      trip('L1', TripStatus.active, length: const Duration(hours: 5)),
      trip('L2', TripStatus.active, length: const Duration(hours: 4)),
      trip('S1', TripStatus.active, length: const Duration(hours: 1)),
      trip('C1', TripStatus.completed, length: const Duration(hours: 9)),
    ];
    expect(await service.checkLongTrips(trips, now: now), 2);
    expect(await service.checkLongTrips(trips, now: now), 0);
  });
}
