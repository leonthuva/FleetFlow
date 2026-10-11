import 'package:flutter/foundation.dart';
import '../models/trip.dart';
import '../models/trip_summary.dart';
import '../models/user.dart';
import '../services/trip_alert_service.dart';
import '../services/trip_service.dart';

/// State for the trip history and report screens.
///
/// Drivers only ever see their own trips: [loadForUser] locks the driver
/// filter for driver accounts, and [setDriverFilter] is ignored while locked.
class HistoryProvider extends ChangeNotifier {
  HistoryProvider({
    TripService? service,
    TripAlertService? alerts,
    String Function(AppUser user)? driverIdFor,
  })  : _service = service ?? TripService(),
        _alerts = alerts,
        _driverIdFor = driverIdFor ?? _defaultDriverIdFor;

  /// Trips store `driverId` as a display name in the current sample data, so
  /// that is the default key. Swap this once Member 3 confirms uid vs name.
  static String _defaultDriverIdFor(AppUser user) => user.displayName;

  final TripService _service;
  final TripAlertService? _alerts;
  final String Function(AppUser user) _driverIdFor;

  List<Trip> _trips = [];
  bool _isLoading = false;
  String? _errorMessage;

  String? _lockedDriverId;
  String? _driverFilter;
  String? _vehicleFilter;
  String? _statusFilter;
  DateTime? _from;
  DateTime? _to;

  // Every driver/vehicle seen so far, so filter dropdowns don't shrink once a filter is applied.
  final Set<String> _knownDrivers = {};
  final Set<String> _knownVehicles = {};

  int _loadCounter = 0;
  bool _disposed = false;

  // Getters
  List<Trip> get trips => List.unmodifiable(_trips);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isDriverLocked => _lockedDriverId != null;
  String? get driverFilter => _lockedDriverId ?? _driverFilter;
  String? get vehicleFilter => _vehicleFilter;
  String? get statusFilter => _statusFilter;
  DateTime? get from => _from;
  DateTime? get to => _to;
  bool get hasActiveFilters =>
      _driverFilter != null ||
      _vehicleFilter != null ||
      _statusFilter != null ||
      _from != null ||
      _to != null;

  List<String> get driverOptions => _knownDrivers.toList()..sort();
  List<String> get vehicleOptions => _knownVehicles.toList()..sort();

  /// Totals for the trips currently shown.
  TripSummary get summary => TripSummary.fromTrips(_trips);

  /// Per-driver totals for the trips currently shown (manager reports).
  Map<String, TripSummary> get summaryByDriver => _groupSummaries((t) => t.driverId);

  /// Per-vehicle totals for the trips currently shown (manager reports).
  Map<String, TripSummary> get summaryByVehicle => _groupSummaries((t) => t.vehicleId);

  /// Scope the history to [user] and load it. Drivers are locked to their own trips.
  Future<void> loadForUser(AppUser user) {
    _lockedDriverId = user.isDriver ? _driverIdFor(user) : null;
    if (_lockedDriverId != null) _driverFilter = null;
    return load();
  }

  Future<void> load() async {
    final ticket = ++_loadCounter;
    _isLoading = true;
    _errorMessage = null;
    _notify();

    try {
      final result = await _service.fetchTrips(
        driverId: driverFilter,
        vehicleId: _vehicleFilter,
        status: _statusFilter,
        from: _from,
        to: _to,
      );
      if (ticket != _loadCounter) return; // a newer load superseded this one
      _trips = result;
      for (final trip in result) {
        _knownDrivers.add(trip.driverId);
        _knownVehicles.add(trip.vehicleId);
      }
      // Managers get a heads-up about trips that have run too long. Drivers don't alert on themselves.
      if (!isDriverLocked) {
        try {
          await _alerts?.checkLongTrips(result);
        } catch (e) {
          debugPrint('HistoryProvider: long-trip alert failed: $e');
        }
        if (ticket != _loadCounter) return;
      }
    } catch (e) {
      if (ticket != _loadCounter) return;
      _trips = [];
      _errorMessage = 'Could not load trip history: $e';
    }
    _isLoading = false;
    _notify();
  }

  Future<void> setDriverFilter(String? driverId) {
    if (isDriverLocked) return Future.value();
    _driverFilter = driverId;
    return load();
  }

  Future<void> setVehicleFilter(String? vehicleId) {
    _vehicleFilter = vehicleId;
    return load();
  }

  Future<void> setStatusFilter(String? status) {
    _statusFilter = status;
    return load();
  }

  /// [to] is exclusive; pass the day after the last day you want to include.
  Future<void> setDateRange(DateTime? from, DateTime? to) {
    _from = from;
    _to = to;
    return load();
  }

  /// Clears every filter except the driver lock.
  Future<void> clearFilters() {
    _driverFilter = null;
    _vehicleFilter = null;
    _statusFilter = null;
    _from = null;
    _to = null;
    return load();
  }

  Map<String, TripSummary> _groupSummaries(String Function(Trip) keyOf) {
    final groups = <String, List<Trip>>{};
    for (final trip in _trips) {
      groups.putIfAbsent(keyOf(trip), () => []).add(trip);
    }
    return {
      for (final entry in groups.entries) entry.key: TripSummary.fromTrips(entry.value),
    };
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
