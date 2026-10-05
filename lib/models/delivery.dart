/// Status definitions and state machine for delivery lifecycle.
/// Formal progression flow: assigned -> picked_up -> in_transit -> arrived -> completed
class DeliveryStatus {
  static const String assigned = 'assigned';
  static const String pickedUp = 'picked_up';
  static const String inTransit = 'in_transit';
  static const String arrived = 'arrived';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';

  /// The standard progression sequence for an active delivery.
  static const List<String> standardSequence = [
    assigned,
    pickedUp,
    inTransit,
    arrived,
    completed,
  ];

  /// All active/standard statuses
  static const List<String> all = [
    assigned,
    pickedUp,
    inTransit,
    arrived,
    completed,
  ];

  /// Human-friendly display label for each status.
  static String displayName(String status) {
    switch (status) {
      case assigned:
        return 'Assigned';
      case pickedUp:
        return 'Picked Up';
      case inTransit:
        return 'In Transit';
      case arrived:
        return 'Arrived';
      case completed:
        return 'Completed';
      case cancelled:
        return 'Cancelled';
      default:
        return status;
    }
  }

  /// Label helper matching Member 5 UI requirements
  static String getLabel(String status) {
    switch (status) {
      case assigned:
        return 'Assigned';
      case pickedUp:
        return 'Picked Up';
      case inTransit:
        return 'In Transit';
      case arrived:
        return 'Arrived';
      case completed:
        return 'Delivered';
      case cancelled:
        return 'Cancelled';
      default:
        return status;
    }
  }

  /// Returns the next logical status in the standard progression sequence,
  /// or null if the delivery is already completed or cancelled.
  static String? nextStatus(String currentStatus) {
    final currentIndex = standardSequence.indexOf(currentStatus);
    if (currentIndex != -1 && currentIndex < standardSequence.length - 1) {
      return standardSequence[currentIndex + 1];
    }
    return null;
  }

  /// Validates whether transitioning from [current] to [target] is permitted.
  static bool isValidTransition(String current, String target) {
    if (current == target) return false;
    if (current == completed || current == cancelled) return false;
    if (target == cancelled) return true; // Cancellation allowed prior to completion

    final currentIndex = standardSequence.indexOf(current);
    final targetIndex = standardSequence.indexOf(target);

    // Strict linear step progression (cannot skip states)
    return currentIndex != -1 && targetIndex == currentIndex + 1;
  }

  /// Returns a 0-indexed step number for stepper / progress indicator (0 to 4).
  static int stepIndex(String status) {
    final index = standardSequence.indexOf(status);
    return index >= 0 ? index : 0;
  }
}

class Delivery {
  final String id;
  final String driverId;
  final String vehicleId;
  final String address;
  final String status;
  final String recipientName;
  final String recipientPhone;
  final String pickup;
  final double latitude;
  final double longitude;
  final String packageDescription;
  final String specialInstructions;
  final String priority; // 'standard', 'high', 'urgent'
  final String? eta;
  final String? proofPhotoUrl;
  final String? signatureNotes;
  final DateTime? createdAt;
  final DateTime? pickedUpAt;
  final DateTime? inTransitAt;
  final DateTime? arrivedAt;
  final DateTime? completedAt;

  const Delivery({
    required this.id,
    String? driverId,
    String? assignedDriverId,
    this.vehicleId = '',
    String? address,
    String? destination,
    this.status = DeliveryStatus.assigned,
    String? recipientName,
    String? customerName,
    String? recipientPhone,
    String? customerPhone,
    this.pickup = 'Central Logistics Hub, Bay 3',
    this.latitude = 37.7749,
    this.longitude = -122.4194,
    this.packageDescription = 'Standard Parcel Delivery',
    this.specialInstructions = 'Deliver to front desk or designated receiving area.',
    this.priority = 'standard',
    this.eta,
    this.proofPhotoUrl,
    this.signatureNotes,
    this.createdAt,
    this.pickedUpAt,
    this.inTransitAt,
    this.arrivedAt,
    this.completedAt,
  })  : driverId = driverId ?? assignedDriverId ?? '',
        address = address ?? destination ?? '',
        recipientName = recipientName ?? customerName ?? 'Valued Customer',
        recipientPhone = recipientPhone ?? customerPhone ?? '+1 (555) 019-2834';

  // Backwards compatibility helpers
  String get deliveryId => id;
  String get assignedDriverId => driverId;
  String get destination => address;
  String get customerName => recipientName;
  String get customerPhone => recipientPhone;

  // Status check getters
  bool get isAssigned => status == DeliveryStatus.assigned;
  bool get isPickedUp => status == DeliveryStatus.pickedUp;
  bool get isInTransit => status == DeliveryStatus.inTransit;
  bool get isArrived => status == DeliveryStatus.arrived;
  bool get isCompleted => status == DeliveryStatus.completed;
  bool get isCancelled => status == DeliveryStatus.cancelled;

  /// Whether this delivery is currently active and requires driver action
  bool get isActive => !isCompleted && !isCancelled;

  /// Human-readable status string
  String get statusDisplayName => DeliveryStatus.displayName(status);

  /// 0-indexed step index for Stepper UI
  int get statusStepIndex => DeliveryStatus.stepIndex(status);

  /// Returns the next status if one exists
  String? get nextStatus => DeliveryStatus.nextStatus(status);

  /// Validates if transition to [newStatus] is allowed
  bool canTransitionTo(String newStatus) =>
      DeliveryStatus.isValidTransition(status, newStatus);

  factory Delivery.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return Delivery(
      id: documentId ?? map['id'] as String? ?? map['deliveryId'] as String? ?? '',
      driverId: map['driverId'] as String? ?? map['assignedDriverId'] as String? ?? '',
      vehicleId: map['vehicleId'] as String? ?? '',
      address: map['address'] as String? ?? map['destination'] as String? ?? '',
      pickup: map['pickup'] as String? ?? 'Central Logistics Hub, Bay 3',
      status: map['status'] as String? ?? DeliveryStatus.assigned,
      recipientName: map['recipientName'] as String? ?? map['customerName'] as String? ?? 'Valued Customer',
      recipientPhone: map['recipientPhone'] as String? ?? map['customerPhone'] as String? ?? '+1 (555) 019-2834',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 37.7749,
      longitude: (map['longitude'] as num?)?.toDouble() ?? -122.4194,
      packageDescription: map['packageDescription'] as String? ?? 'Standard Parcel Delivery',
      specialInstructions: map['specialInstructions'] as String? ?? 'Deliver to front desk.',
      priority: map['priority'] as String? ?? 'standard',
      eta: map['eta'] as String?,
      proofPhotoUrl: map['proofPhotoUrl'] as String? ?? map['proofPhotoURL'] as String?,
      signatureNotes: map['signatureNotes'] as String?,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] is DateTime
              ? map['createdAt'] as DateTime
              : DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
      pickedUpAt: map['pickedUpAt'] != null
          ? (map['pickedUpAt'] is DateTime
              ? map['pickedUpAt'] as DateTime
              : DateTime.tryParse(map['pickedUpAt'].toString()))
          : null,
      inTransitAt: map['inTransitAt'] != null
          ? (map['inTransitAt'] is DateTime
              ? map['inTransitAt'] as DateTime
              : DateTime.tryParse(map['inTransitAt'].toString()))
          : null,
      arrivedAt: map['arrivedAt'] != null
          ? (map['arrivedAt'] is DateTime
              ? map['arrivedAt'] as DateTime
              : DateTime.tryParse(map['arrivedAt'].toString()))
          : null,
      completedAt: map['completedAt'] != null
          ? (map['completedAt'] is DateTime
              ? map['completedAt'] as DateTime
              : DateTime.tryParse(map['completedAt'].toString()))
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'deliveryId': id,
      'driverId': driverId,
      'assignedDriverId': driverId,
      'vehicleId': vehicleId,
      'address': address,
      'destination': address,
      'pickup': pickup,
      'status': status,
      'recipientName': recipientName,
      'customerName': recipientName,
      'recipientPhone': recipientPhone,
      'customerPhone': recipientPhone,
      'latitude': latitude,
      'longitude': longitude,
      'packageDescription': packageDescription,
      'specialInstructions': specialInstructions,
      'priority': priority,
      'eta': eta,
      'proofPhotoUrl': proofPhotoUrl,
      'signatureNotes': signatureNotes,
      'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
      'pickedUpAt': pickedUpAt?.toIso8601String(),
      'inTransitAt': inTransitAt?.toIso8601String(),
      'arrivedAt': arrivedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  Delivery copyWith({
    String? id,
    String? driverId,
    String? assignedDriverId,
    String? vehicleId,
    String? address,
    String? destination,
    String? status,
    String? recipientName,
    String? customerName,
    String? recipientPhone,
    String? customerPhone,
    String? pickup,
    double? latitude,
    double? longitude,
    String? packageDescription,
    String? specialInstructions,
    String? priority,
    String? eta,
    String? proofPhotoUrl,
    String? signatureNotes,
    DateTime? createdAt,
    DateTime? pickedUpAt,
    DateTime? inTransitAt,
    DateTime? arrivedAt,
    DateTime? completedAt,
  }) {
    return Delivery(
      id: id ?? this.id,
      driverId: driverId ?? assignedDriverId ?? this.driverId,
      vehicleId: vehicleId ?? this.vehicleId,
      address: address ?? destination ?? this.address,
      status: status ?? this.status,
      recipientName: recipientName ?? customerName ?? this.recipientName,
      recipientPhone: recipientPhone ?? customerPhone ?? this.recipientPhone,
      pickup: pickup ?? this.pickup,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      packageDescription: packageDescription ?? this.packageDescription,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      priority: priority ?? this.priority,
      eta: eta ?? this.eta,
      proofPhotoUrl: proofPhotoUrl ?? this.proofPhotoUrl,
      signatureNotes: signatureNotes ?? this.signatureNotes,
      createdAt: createdAt ?? this.createdAt,
      pickedUpAt: pickedUpAt ?? this.pickedUpAt,
      inTransitAt: inTransitAt ?? this.inTransitAt,
      arrivedAt: arrivedAt ?? this.arrivedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}