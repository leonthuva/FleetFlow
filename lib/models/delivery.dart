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
  final double latitude;
  final double longitude;
  final String packageDescription;
  final String specialInstructions;
  final String priority; // 'standard', 'high', 'urgent'
  final String? proofPhotoUrl;
  final String? signatureNotes;
  final DateTime createdAt;
  final DateTime? pickedUpAt;
  final DateTime? inTransitAt;
  final DateTime? arrivedAt;
  final DateTime? completedAt;

  Delivery({
    required this.id,
    required this.driverId,
    required this.vehicleId,
    required this.address,
    required this.status,
    this.recipientName = 'Valued Customer',
    this.recipientPhone = '+1 (555) 019-2834',
    this.latitude = 37.7749,
    this.longitude = -122.4194,
    this.packageDescription = 'Standard Parcel Delivery',
    this.specialInstructions = 'Deliver to front desk or designated receiving area.',
    this.priority = 'standard',
    this.proofPhotoUrl,
    this.signatureNotes,
    DateTime? createdAt,
    this.pickedUpAt,
    this.inTransitAt,
    this.arrivedAt,
    this.completedAt,
  }) : createdAt = createdAt ?? DateTime.now();

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
      id: documentId ?? map['id'] as String? ?? '',
      driverId: map['driverId'] as String? ?? '',
      vehicleId: map['vehicleId'] as String? ?? '',
      address: map['address'] as String? ?? '',
      status: map['status'] as String? ?? DeliveryStatus.assigned,
      recipientName: map['recipientName'] as String? ?? 'Valued Customer',
      recipientPhone: map['recipientPhone'] as String? ?? '+1 (555) 019-2834',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 37.7749,
      longitude: (map['longitude'] as num?)?.toDouble() ?? -122.4194,
      packageDescription: map['packageDescription'] as String? ?? 'Standard Parcel Delivery',
      specialInstructions: map['specialInstructions'] as String? ?? 'Deliver to front desk.',
      priority: map['priority'] as String? ?? 'standard',
      proofPhotoUrl: map['proofPhotoUrl'] as String?,
      signatureNotes: map['signatureNotes'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      pickedUpAt: map['pickedUpAt'] != null
          ? DateTime.tryParse(map['pickedUpAt'].toString())
          : null,
      inTransitAt: map['inTransitAt'] != null
          ? DateTime.tryParse(map['inTransitAt'].toString())
          : null,
      arrivedAt: map['arrivedAt'] != null
          ? DateTime.tryParse(map['arrivedAt'].toString())
          : null,
      completedAt: map['completedAt'] != null
          ? DateTime.tryParse(map['completedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'driverId': driverId,
      'vehicleId': vehicleId,
      'address': address,
      'status': status,
      'recipientName': recipientName,
      'recipientPhone': recipientPhone,
      'latitude': latitude,
      'longitude': longitude,
      'packageDescription': packageDescription,
      'specialInstructions': specialInstructions,
      'priority': priority,
      'proofPhotoUrl': proofPhotoUrl,
      'signatureNotes': signatureNotes,
      'createdAt': createdAt.toIso8601String(),
      'pickedUpAt': pickedUpAt?.toIso8601String(),
      'inTransitAt': inTransitAt?.toIso8601String(),
      'arrivedAt': arrivedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  Delivery copyWith({
    String? id,
    String? driverId,
    String? vehicleId,
    String? address,
    String? status,
    String? recipientName,
    String? recipientPhone,
    double? latitude,
    double? longitude,
    String? packageDescription,
    String? specialInstructions,
    String? priority,
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
      driverId: driverId ?? this.driverId,
      vehicleId: vehicleId ?? this.vehicleId,
      address: address ?? this.address,
      status: status ?? this.status,
      recipientName: recipientName ?? this.recipientName,
      recipientPhone: recipientPhone ?? this.recipientPhone,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      packageDescription: packageDescription ?? this.packageDescription,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      priority: priority ?? this.priority,
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