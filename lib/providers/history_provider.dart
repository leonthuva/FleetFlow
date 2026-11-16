import 'package:flutter/foundation.dart';

import '../models/trip.dart';
import '../models/trip_summary.dart';
import '../models/user.dart';
import '../services/trip_alert_service.dart';
import '../services/trip_service.dart';

class HistoryProvider extends ChangeNotifier {
  HistoryProvider({
    required TripService service,
    TripAlertService? alerts,
  })  : _service = service,
        _alerts = alerts;

  final TripService _service;
  final TripAlertService? _alerts;

  List<Trip> _trips = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _warningMessage;
  String? _lockedDriverId;
  String? _driverFilter;
  String? _vehicleFilter;
  String? _statusFilter;
  DateTime? _from;
  DateTime? _to;
  final Set<String> _knownDrivers = {};
  final Set<String> _knownVehicles = {};
  int _loadCounter = 0;
  bool _disposed = false;

  List<Trip> get trips => List.unmodifiable(_trips);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get warningMessage => _warningMessage;
  bool get isDriverLocked => _lockedDriverId != null;
  String? get driverFilter => _lockedDriverId ?? _driverFilter;
  String? get vehicleFilter => _vehicleFilter;
  String? get statusFilter => _statusFilter;
  DateTime? get from => _from;
  DateTime? get to => _to;
  bool get hasActiveFilters =>
      _lockedDriverId != null ||
      _driverFilter != null ||
      _vehicleFilter != null ||
      _statusFilter != null ||
      _from != null ||
      _to != null;

  List<String> get driverOptions => _knownDrivers.toList()..sort();
  List<String> get vehicleOptions => _knownVehicles.toList()..sort();
  TripSummary get summary => TripSummary.fromTrips(_trips);
  Map<String, TripSummary> get summaryByDriver =>
      _groupSummaries((trip) => trip.driverId);
  Map<String, TripSummary> get summaryByVehicle =>
      _groupSummaries((trip) => trip.vehicleId);

  Future<void> loadForUser(AppUser user) {
    if (user.isDriver) {
      if (user.id.isEmpty) {
        throw ArgumentError('A driver must have a Firebase Auth UID.');
      }
      _lockedDriverId = user.id;
      _driverFilter = null;
    } else if (user.isManager) {
      _lockedDriverId = null;
    } else {
      throw ArgumentError(
          'Trip history is only available to drivers and managers.');
    }
    return load();
  }

  Future<void> load() async {
    final ticket = ++_loadCounter;
    _isLoading = true;
    _errorMessage = null;
    _warningMessage = null;
    _notify();

    try {
      final result = await _service.fetchTrips(
        driverId: driverFilter,
        vehicleId: _vehicleFilter,
        status: _statusFilter,
        from: _from,
        to: _to,
      );
      if (ticket != _loadCounter) return;
      _trips = result;
      for (final trip in result) {
        _knownDrivers.add(trip.driverId);
        _knownVehicles.add(trip.vehicleId);
      }

      if (!isDriverLocked && _alerts != null) {
        try {
          await _alerts.checkLongTrips(result);
        } catch (error) {
          if (ticket != _loadCounter) return;
          _warningMessage =
              'History loaded, but safety alerts could not be sent: $error';
        }
      }
    } catch (error) {
      if (ticket != _loadCounter) return;
      _trips = [];
      _errorMessage = 'Could not load trip history: $error';
    }

    if (ticket != _loadCounter) return;
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

  /// [to] is exclusive; pass the day after the final included day.
  Future<void> setDateRange(DateTime? from, DateTime? to) {
    _from = from;
    _to = to;
    return load();
  }

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
      for (final entry in groups.entries)
        entry.key: TripSummary.fromTrips(entry.value),
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
