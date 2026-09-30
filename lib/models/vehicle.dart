class VehicleStatus {
  static const String available = 'available';
  static const String inUse = 'in-use';
  static const String maintenance = 'maintenance';
}

class Vehicle {
  final String id;
  final String licensePlate;
  final String model;
  final String status;
  final String? type; // e.g., 'Van', 'Truck', 'Bike'
  final double? currentOdometerKm;

  const Vehicle({
    required this.id,
    required this.licensePlate,
    required this.model,
    required this.status,
    this.type = 'Delivery Van',
    this.currentOdometerKm = 12450.0,
  });

  bool get isAvailable => status == VehicleStatus.available;
  bool get isInUse => status == VehicleStatus.inUse;
  bool get isInMaintenance => status == VehicleStatus.maintenance;

  factory Vehicle.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return Vehicle(
      id: documentId ?? map['id'] as String? ?? '',
      licensePlate: map['licensePlate'] as String? ?? '',
      model: map['model'] as String? ?? '',
      status: map['status'] as String? ?? VehicleStatus.available,
      type: map['type'] as String? ?? 'Delivery Van',
      currentOdometerKm: (map['currentOdometerKm'] as num?)?.toDouble() ?? 12450.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'licensePlate': licensePlate,
      'model': model,
      'status': status,
      'type': type,
      'currentOdometerKm': currentOdometerKm,
    };
  }

  Vehicle copyWith({
    String? id,
    String? licensePlate,
    String? model,
    String? status,
    String? type,
    double? currentOdometerKm,
  }) {
    return Vehicle(
      id: id ?? this.id,
      licensePlate: licensePlate ?? this.licensePlate,
      model: model ?? this.model,
      status: status ?? this.status,
      type: type ?? this.type,
      currentOdometerKm: currentOdometerKm ?? this.currentOdometerKm,
    );
  }
}