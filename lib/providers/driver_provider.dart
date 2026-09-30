import 'package:flutter/foundation.dart';
import '../models/delivery.dart';
import '../models/vehicle.dart';

class DriverProvider extends ChangeNotifier {
  bool _isShiftActive = true;
  DateTime? _shiftStartTime = DateTime.now().subtract(const Duration(hours: 3, minutes: 25));
  DateTime? _shiftEndTime;
  Vehicle _activeVehicle = const Vehicle(
    id: 'veh_01',
    licensePlate: 'FLT-882-CA',
    model: 'Ford Transit 350 High Roof',
    status: VehicleStatus.inUse,
  );

  List<Delivery> _deliveries = [];
  String? _errorMessage;

  DriverProvider() {
    _seedInitialDeliveries();
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
  int get inProgressCount =>
      _deliveries.where((d) => d.isPickedUp || d.isInTransit || d.isArrived).length;

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
  bool advanceDeliveryStatus(String deliveryId) {
    final delivery = getDeliveryById(deliveryId);
    if (delivery == null) {
      _errorMessage = 'Delivery not found';
      notifyListeners();
      return false;
    }

    final targetStatus = delivery.nextStatus;
    if (targetStatus == null) {
      _errorMessage = 'Delivery is already completed or cannot advance';
      notifyListeners();
      return false;
    }

    return updateDeliveryStatus(deliveryId, targetStatus);
  }

  /// Explicit status transition with strict state machine validation
  bool updateDeliveryStatus(String deliveryId, String newStatus) {
    final index = _deliveries.indexWhere((d) => d.id == deliveryId);
    if (index == -1) {
      _errorMessage = 'Delivery $deliveryId not found';
      notifyListeners();
      return false;
    }

    final current = _deliveries[index];
    if (!current.canTransitionTo(newStatus)) {
      _errorMessage =
          'Cannot transition status from "${current.status}" to "$newStatus".';
      notifyListeners();
      return false;
    }

    final now = DateTime.now();
    _deliveries[index] = current.copyWith(
      status: newStatus,
      pickedUpAt: newStatus == DeliveryStatus.pickedUp ? now : current.pickedUpAt,
      inTransitAt: newStatus == DeliveryStatus.inTransit ? now : current.inTransitAt,
      arrivedAt: newStatus == DeliveryStatus.arrived ? now : current.arrivedAt,
      completedAt: newStatus == DeliveryStatus.completed ? now : current.completedAt,
    );

    _errorMessage = null;
    notifyListeners();
    return true;
  }

  /// Record Proof-of-Delivery metadata (photo and signature note)
  void attachProofOfDelivery(String deliveryId, String photoUrl, String signatureNotes) {
    final index = _deliveries.indexWhere((d) => d.id == deliveryId);
    if (index != -1) {
      _deliveries[index] = _deliveries[index].copyWith(
        proofPhotoUrl: photoUrl,
        signatureNotes: signatureNotes,
      );
      notifyListeners();
    }
  }

  /// Seed initial representative data for driver flows
  void _seedInitialDeliveries() {
    _deliveries = [
      Delivery(
        id: 'DEL-2041',
        driverId: 'drv_01',
        vehicleId: 'FLT-882-CA',
        recipientName: 'Apex Health Logistics',
        recipientPhone: '+1 (415) 892-1100',
        address: '742 Evergreen Terrace, Sector 4, Springfield',
        latitude: 37.7833,
        longitude: -122.4167,
        packageDescription: '2x Temperature-Controlled Medical Cases',
        specialInstructions: 'Ring bell at Gate 2. Cold storage signature required.',
        priority: 'urgent',
        status: DeliveryStatus.inTransit,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        pickedUpAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 15)),
        inTransitAt: DateTime.now().subtract(const Duration(minutes: 40)),
      ),
      Delivery(
        id: 'DEL-2042',
        driverId: 'drv_01',
        vehicleId: 'FLT-882-CA',
        recipientName: 'Metro Tech Hub (Reception)',
        recipientPhone: '+1 (415) 555-0188',
        address: '100 Market St, Suite 500, San Francisco, CA',
        latitude: 37.7937,
        longitude: -122.3965,
        packageDescription: '1x IT Server Equipment & Cables',
        specialInstructions: 'Security check-in at ground floor reception desk.',
        priority: 'high',
        status: DeliveryStatus.assigned,
        createdAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 30)),
      ),
      Delivery(
        id: 'DEL-2043',
        driverId: 'drv_01',
        vehicleId: 'FLT-882-CA',
        recipientName: 'Bay Coffee Roasters',
        recipientPhone: '+1 (415) 321-7788',
        address: '550 Valencia Street, Mission District, CA',
        latitude: 37.7645,
        longitude: -122.4214,
        packageDescription: '4x Bulk Coffee Beans & Grinder Parts',
        specialInstructions: 'Back alley loading dock. Call upon arrival.',
        priority: 'standard',
        status: DeliveryStatus.assigned,
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      Delivery(
        id: 'DEL-2039',
        driverId: 'drv_01',
        vehicleId: 'FLT-882-CA',
        recipientName: 'Sarah Jenkins',
        recipientPhone: '+1 (415) 902-3341',
        address: '320 14th Ave, Richmond District, CA',
        latitude: 37.7812,
        longitude: -122.4721,
        packageDescription: '1x Fragile Home Goods Box',
        specialInstructions: 'Leave with front porch locker if not home.',
        priority: 'standard',
        status: DeliveryStatus.completed,
        proofPhotoUrl: 'https://storage.googleapis.com/fleetflow-dev/pod/DEL-2039.jpg',
        signatureNotes: 'Left by front door as customer requested in delivery note.',
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
        pickedUpAt: DateTime.now().subtract(const Duration(hours: 3, minutes: 20)),
        inTransitAt: DateTime.now().subtract(const Duration(hours: 3)),
        arrivedAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 30)),
        completedAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 20)),
      ),
    ];
  }
}
