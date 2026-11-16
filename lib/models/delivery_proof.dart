import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/firestore_dates.dart';

class DeliveryProof {
  final String id;
  final String deliveryId;
  final String photoURL;
  final String driverId;
  final String storagePath;
  final DateTime timestamp;
  final Map<String, dynamic> capturedLocation;
  final String? notes;
  final String? recipientName;

  const DeliveryProof({
    required this.id,
    required this.deliveryId,
    required this.photoURL,
    this.driverId = '',
    this.storagePath = '',
    required this.timestamp,
    required this.capturedLocation,
    this.notes,
    this.recipientName,
  });

  factory DeliveryProof.fromMap(Map<String, dynamic> map,
      {String? documentId}) {
    return DeliveryProof(
      id: documentId ?? map['id'] as String? ?? '',
      deliveryId: map['deliveryId'] as String? ?? '',
      photoURL: map['photoURL'] as String? ?? map['photoUrl'] as String? ?? '',
      driverId: map['driverId'] as String? ?? '',
      storagePath: map['storagePath'] as String? ?? '',
      timestamp: parseFirestoreDate(map['timestamp']) ??
          (throw const FormatException('Proof timestamp missing')),
      capturedLocation: map['capturedLocation'] is Map
          ? Map<String, dynamic>.from(map['capturedLocation'] as Map)
          : {
              'lat': 0.0,
              'lng': 0.0,
              'address': 'Current Location',
            },
      notes: map['notes'] as String?,
      recipientName: map['recipientName'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'deliveryId': deliveryId,
      'photoUrl': photoURL,
      'driverId': driverId,
      'storagePath': storagePath,
      'timestamp': Timestamp.fromDate(timestamp),
      'capturedLocation': capturedLocation,
      'notes': notes,
      'recipientName': recipientName,
    };
  }
}
