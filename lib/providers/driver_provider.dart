import 'dart:async';
import '../services/delivery_service.dart';
import 'package:flutter/foundation.dart';
import '../models/delivery.dart';
import '../models/vehicle.dart';

class DriverProvider extends ChangeNotifier {
  bool _isShiftActive = false;
  DateTime? _shiftStartTime;
  DateTime? _shiftEndTime;
  Vehicle _activeVehicle = const Vehicle(
    id: '',
    licensePlate: 'Unassigned',
    model: 'No assigned vehicle',
    status: VehicleStatus.inUse,
  );

  List<Delivery> _deliveries = [];
  String? _errorMessage;

  DriverProvider({DeliveryService? service})
      : _service = service ?? DeliveryService();
  final DeliveryService _service;
  StreamSubscription<List<Delivery>>? _subscription;
  String? _uid;
  bool _loading = false;
  bool _disposed = false;
  int _session = 0;
  final Set<String> _pending = {};
  String? get notificationWarning => _service.notificationWarning;
  bool get isLoading => _loading;
  bool isUpdating(String id) => _pending.contains(id);
  void bindUser(String? uid) {
    if (uid == _uid) return;
    _uid = uid;
    final session = ++_session;
    _subscription?.cancel();
    _deliveries = [];
    _errorMessage = null;
    _pending.clear();
    _loading = uid != null;
    if (uid != null) {
      _subscription = _service.watchDeliveries(driverId: uid).listen((items) {
        if (_disposed || session != _session) return;
        _deliveries = items;
        _loading = false;
        notifyListeners();
      }, onError: (Object e) {
        if (_disposed || session != _session) return;
        _deliveries = [];
        _errorMessage = 'Assignments unavailable: $e';
        _loading = false;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  // Getters
  bool get isShiftActive => _isShiftActive;
  DateTime? get shiftStartTime => _shiftStartTime;
  DateTime? get shiftEndTime => _shiftEndTime;
  Vehicle get activeVehicle => _activeVehicle;
  List<Delivery> get deliveries => List.unmodifiable(_deliveries);
  String? get errorMessage => _errorMessage;

  /// Returns the current active delivery (e.g. in_transit, arrived, or picked_up)
  Delivery? get activeDelivery {
    return _deliveries.cast<Delivery?>().firstWhere(
          (d) => d != null && (d.isInTransit || d.isArrived || d.isPickedUp),
          orElse: () => _deliveries.cast<Delivery?>().firstWhere(
                (d) => d != null && d.isAssigned,
                orElse: () => null,
              ),
        );
  }

  // Shift & Metrics getters
  int get totalAssigned => _deliveries.length;
  int get completedCount => _deliveries.where((d) => d.isCompleted).length;
  int get pendingCount => _deliveries.where((d) => d.isAssigned).length;
  int get inProgressCount => _deliveries
      .where((d) => d.isPickedUp || d.isInTransit || d.isArrived)
      .length;

  double get completionRate =>
      totalAssigned > 0 ? (completedCount / totalAssigned) * 100 : 0.0;

  Duration get shiftDuration {
    if (_shiftStartTime == null) return Duration.zero;
    final end = _shiftEndTime ?? DateTime.now();
    return end.difference(_shiftStartTime!);
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Start a driver shift with an assigned vehicle
  void startShift({Vehicle? vehicle}) {
    _isShiftActive = true;
    _shiftStartTime = DateTime.now();
    _shiftEndTime = null;
    if (vehicle != null) {
      _activeVehicle = vehicle;
    }
    _errorMessage = null;
    notifyListeners();
  }

  /// End a driver shift and record end time
  void endShift() {
    _isShiftActive = false;
    _shiftEndTime = DateTime.now();
    _errorMessage = null;
    notifyListeners();
  }

  /// Lookup delivery by ID
  Delivery? getDeliveryById(String id) {
    try {
      return _deliveries.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Advance delivery to next lifecycle status:
  /// assigned -> picked_up -> in_transit -> arrived -> completed
  Future<bool> advanceDeliveryStatus(String deliveryId) async {
    final delivery = getDeliveryById(deliveryId);
    if (delivery?.nextStatus == null) {
      _errorMessage = 'Delivery cannot advance';
      notifyListeners();
      return false;
    }
    return updateDeliveryStatus(deliveryId, delivery!.nextStatus!);
  }

  Future<bool> updateDeliveryStatus(String id, String status) async {
    if (_pending.contains(id)) return false;
    final session = _session;
    _pending.add(id);
    _errorMessage = null;
    notifyListeners();
    try {
      final updated =
          await _service.updateStatus(deliveryId: id, newStatus: status);
      if (_disposed || session != _session) return false;
      final index = _deliveries.indexWhere((d) => d.id == id);
      if (index >= 0) _deliveries[index] = updated;
      return true;
    } catch (e) {
      if (!_disposed && session == _session) _errorMessage = e.toString();
      return false;
    } finally {
      if (!_disposed && session == _session) {
        _pending.remove(id);
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_session;
    _subscription?.cancel();
    super.dispose();
  }
}
