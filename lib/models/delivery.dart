class DeliveryStatus {
  static const String assigned = 'assigned';
  static const String pickedUp = 'picked_up';
  static const String inTransit = 'in_transit';
  static const String arrived = 'arrived';
  static const String completed = 'completed';

  static const List<String> all = [
    assigned,
    pickedUp,
    inTransit,
    arrived,
    completed,
  ];

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
      default:
        return status;
    }
  }
}

class Delivery {
  final String id;
  final String customerName;
  final String customerPhone;
  final String pickup;
  final String destination;
  final String assignedDriverId;
  final String vehicleId;
  final String status;
  final String? eta;
  final String? proofPhotoUrl;
  final DateTime? createdAt;
  final DateTime? completedAt;

  const Delivery({
    required this.id,
    this.customerName = 'Valued Customer',
    this.customerPhone = '',
    this.pickup = 'Central Logistics Hub, Bay 3',
    required this.destination,
    required this.assignedDriverId,
    this.vehicleId = '',
    this.status = DeliveryStatus.assigned,
    this.eta,
    this.proofPhotoUrl,
    this.createdAt,
    this.completedAt,
  });

  // Backwards compatibility helpers for existing code
  String get deliveryId => id;
  String get driverId => assignedDriverId;
  String get address => destination;

  bool get isAssigned => status == DeliveryStatus.assigned;
  bool get isPickedUp => status == DeliveryStatus.pickedUp;
  bool get isInTransit => status == DeliveryStatus.inTransit;
  bool get isArrived => status == DeliveryStatus.arrived;
  bool get isCompleted => status == DeliveryStatus.completed;

  factory Delivery.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return Delivery(
      id: documentId ?? map['deliveryId'] as String? ?? map['id'] as String? ?? '',
      customerName: map['customerName'] as String? ?? 'Valued Customer',
      customerPhone: map['customerPhone'] as String? ?? '',
      pickup: map['pickup'] as String? ?? 'Central Logistics Hub',
      destination: map['destination'] as String? ?? map['address'] as String? ?? '',
      assignedDriverId: map['assignedDriverId'] as String? ?? map['driverId'] as String? ?? '',
      vehicleId: map['vehicleId'] as String? ?? '',
      status: map['status'] as String? ?? DeliveryStatus.assigned,
      eta: map['eta'] as String?,
      proofPhotoUrl: map['proofPhotoUrl'] as String? ?? map['proofPhotoURL'] as String?,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] is DateTime
              ? map['createdAt'] as DateTime
              : DateTime.tryParse(map['createdAt'].toString()))
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
      'customerName': customerName,
      'customerPhone': customerPhone,
      'pickup': pickup,
      'destination': destination,
      'address': destination,
      'assignedDriverId': assignedDriverId,
      'driverId': assignedDriverId,
      'vehicleId': vehicleId,
      'status': status,
      'eta': eta,
      'proofPhotoUrl': proofPhotoUrl,
      'createdAt': createdAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  Delivery copyWith({
    String? id,
    String? customerName,
    String? customerPhone,
    String? pickup,
    String? destination,
    String? assignedDriverId,
    String? vehicleId,
    String? status,
    String? eta,
    String? proofPhotoUrl,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return Delivery(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      pickup: pickup ?? this.pickup,
      destination: destination ?? this.destination,
      assignedDriverId: assignedDriverId ?? this.assignedDriverId,
      vehicleId: vehicleId ?? this.vehicleId,
      status: status ?? this.status,
      eta: eta ?? this.eta,
      proofPhotoUrl: proofPhotoUrl ?? this.proofPhotoUrl,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}