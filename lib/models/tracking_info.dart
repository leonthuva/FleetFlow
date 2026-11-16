import '../core/firestore_dates.dart';

/// The deliberately small, public view of a delivery. It never carries the
/// address, phone number, package details or driver contact information.
class TrackingInfo {
  final String code;
  final String deliveryId;
  final String status;
  final String recipientFirstName;
  final String? driverFirstName;
  final DateTime? updatedAt;

  const TrackingInfo({
    required this.code,
    required this.deliveryId,
    required this.status,
    required this.recipientFirstName,
    this.driverFirstName,
    this.updatedAt,
  });

  factory TrackingInfo.fromMap(Map<String, dynamic> map,
          {required String code}) =>
      TrackingInfo(
        code: code,
        deliveryId: map['deliveryId'] as String? ?? '',
        status: map['status'] as String? ?? 'assigned',
        recipientFirstName: map['recipientFirstName'] as String? ?? '',
        driverFirstName: map['driverFirstName'] as String?,
        updatedAt: parseFirestoreDate(map['updatedAt']),
      );
}
