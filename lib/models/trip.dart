class Trip {
  final String id;
  final String driverId;
  final String vehicleId;
  final DateTime startTime;
  final DateTime endTime;
  final String status;

  const Trip({
    required this.id,
    required this.driverId,
    required this.vehicleId,
    required this.startTime,
    required this.endTime,
    required this.status,
  });
}