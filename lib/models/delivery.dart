class Delivery {
  final String id;
  final String driverId;
  final String vehicleId;
  final String address;
  final String status;

  const Delivery({
    required this.id,
    required this.driverId,
    required this.vehicleId,
    required this.address,
    required this.status,
  });
}