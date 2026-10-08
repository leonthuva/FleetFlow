import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_flow/models/trip.dart';
import 'package:fleet_flow/models/user.dart';
import 'package:fleet_flow/providers/history_provider.dart';
import 'package:fleet_flow/services/trip_service.dart';

void main() {
  final now = DateTime(2026, 10, 8, 12);

  HistoryProvider build() => HistoryProvider(service: TripService(now: now));

  const manager = AppUser(id: 'm1', email: 'm@x.com', displayName: 'Mia Manager', role: UserRole.admin);
  const driver = AppUser(id: 'd1', email: 'd@x.com', displayName: 'Marcus Vance', role: UserRole.driver);

  test('load fills trips and summary, toggling isLoading', () async {
    final provider = build();
    final states = <bool>[];
    provider.addListener(() => states.add(provider.isLoading));

    await provider.load();

    expect(states, [true, false]);
    expect(provider.trips.length, 6);
    expect(provider.summary.tripCount, 6);
    expect(provider.errorMessage, isNull);
  });

  test('manager sees all trips and can filter by driver', () async {
    final provider = build();
    await provider.loadForUser(manager);
    expect(provider.isDriverLocked, isFalse);
    expect(provider.trips.length, 6);

    await provider.setDriverFilter('Sara Connor');
    expect(provider.trips.length, 2);
    expect(provider.hasActiveFilters, isTrue);
  });

  test('driver is locked to own trips and cannot widen the filter', () async {
    final provider = build();
    await provider.loadForUser(driver);

    expect(provider.isDriverLocked, isTrue);
    expect(provider.trips.length, 3);
    expect(provider.trips.every((t) => t.driverId == 'Marcus Vance'), isTrue);

    await provider.setDriverFilter('Sara Connor');
    expect(provider.driverFilter, 'Marcus Vance');
    expect(provider.trips.length, 3);
  });

  test('status, vehicle and date filters combine; clearFilters resets them', () async {
    final provider = build();
    await provider.setStatusFilter(TripStatus.completed);
    expect(provider.trips.length, 4);

    await provider.setVehicleFilter('FL-101');
    expect(provider.trips.length, 2);

    await provider.setDateRange(now.subtract(const Duration(days: 4)), now);
    expect(provider.trips.map((t) => t.id), ['TRP-1003']);

    await provider.clearFilters();
    expect(provider.hasActiveFilters, isFalse);
    expect(provider.trips.length, 6);
  });

  test('clearFilters keeps the driver lock', () async {
    final provider = build();
    await provider.loadForUser(driver);
    await provider.clearFilters();
    expect(provider.trips.length, 3);
  });

  test('summaryByDriver and summaryByVehicle group totals', () async {
    final provider = build();
    await provider.load();

    final byDriver = provider.summaryByDriver;
    expect(byDriver.keys.toSet(), {'Marcus Vance', 'Sara Connor', 'Liam Chen'});
    expect(byDriver['Marcus Vance']!.tripCount, 3);
    expect(byDriver['Marcus Vance']!.totalDistanceKm, closeTo(127.3, 0.001));

    final byVehicle = provider.summaryByVehicle;
    expect(byVehicle['FL-204']!.tripCount, 2);
    expect(byVehicle['FL-412']!.completedCount, 1);
  });

  test('service errors surface as errorMessage with empty trips', () async {
    final provider = HistoryProvider(service: _FailingTripService());
    await provider.load();

    expect(provider.isLoading, isFalse);
    expect(provider.trips, isEmpty);
    expect(provider.errorMessage, contains('Could not load trip history'));
  });

  test('a stale slower load does not overwrite a newer one', () async {
    final service = _SlowFirstTripService(now);
    final provider = HistoryProvider(service: service);

    final first = provider.load(); // slow, unfiltered
    final second = provider.setStatusFilter(TripStatus.active); // fast
    await Future.wait([first, second]);

    expect(provider.trips.single.id, 'TRP-1006');
    expect(provider.isLoading, isFalse);
  });
}

class _FailingTripService extends TripService {
  @override
  Future<List<Trip>> fetchTrips({
    String? driverId,
    String? vehicleId,
    String? status,
    DateTime? from,
    DateTime? to,
    int? limit,
  }) async {
    throw Exception('boom');
  }
}

class _SlowFirstTripService extends TripService {
  _SlowFirstTripService(DateTime now) : super(now: now);

  bool _firstCall = true;

  @override
  Future<List<Trip>> fetchTrips({
    String? driverId,
    String? vehicleId,
    String? status,
    DateTime? from,
    DateTime? to,
    int? limit,
  }) async {
    final slow = _firstCall;
    _firstCall = false;
    final result = await super.fetchTrips(
      driverId: driverId,
      vehicleId: vehicleId,
      status: status,
      from: from,
      to: to,
      limit: limit,
    );
    if (slow) await Future<void>.delayed(const Duration(milliseconds: 50));
    return result;
  }
}
