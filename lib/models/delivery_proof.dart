import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/firestore_dates.dart';

class DeliveryProof {
  final String id;
  final String deliveryId;

  /// Legacy read adapter only. Supabase proofs never persist public/signed URLs.
  final String photoURL;
  final String storageProvider, bucket, verificationStatus;
  final String? sha256, mimeType, uploadId;
  final int? sizeBytes;
  final DateTime? verifiedAt;
  bool get isVerifiedPrivateProof =>
      storageProvider == 'supabase' &&
      bucket == 'delivery-proofs' &&
      verificationStatus == 'verified';
  final String driverId;
  final String storagePath;
  final DateTime timestamp;
  final Map<String, dynamic> capturedLocation;
  final String? notes;
  final String? recipientName;

  const DeliveryProof({
    required this.id,
    required this.deliveryId,
    this.photoURL = '',
    this.storageProvider = 'firebase',
    this.bucket = '',
    this.verificationStatus = '',
    this.sha256,
    this.mimeType,
    this.uploadId,
    this.sizeBytes,
    this.verifiedAt,
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
      storageProvider: map['storageProvider'] as String? ?? 'firebase',
      bucket: map['bucket'] as String? ?? '',
      verificationStatus: map['verificationStatus'] as String? ?? '',
      sha256: map['sha256'] as String?,
      mimeType: map['mimeType'] as String?,
      uploadId: map['uploadId'] as String?,
      sizeBytes: (map['sizeBytes'] as num?)?.toInt(),
      verifiedAt: parseFirestoreDate(map['verifiedAt']),
      driverId: map['driverId'] as String? ?? '',
      storagePath: map['storagePath'] as String? ?? '',
      timestamp: parseFirestoreDate(map['timestamp']) ??
          (throw const FormatException('Proof timestamp missing')),
      capturedLocation: map['capturedLocation'] is Map
          ? Map<String, dynamic>.from(map['capturedLocation'] as Map)
          : {},
      notes: map['notes'] as String?,
      recipientName: map['recipientName'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'deliveryId': deliveryId,
      if (storageProvider != 'supabase' && photoURL.isNotEmpty)
        'photoUrl': photoURL,
      'storageProvider': storageProvider,
      'bucket': bucket,
      'verificationStatus': verificationStatus,
      'sha256': sha256,
      'mimeType': mimeType,
      'uploadId': uploadId,
      'sizeBytes': sizeBytes,
      'verifiedAt': verifiedAt == null ? null : Timestamp.fromDate(verifiedAt!),
      'driverId': driverId,
      'storagePath': storagePath,
      'timestamp': Timestamp.fromDate(timestamp),
      'capturedLocation': capturedLocation,
      'notes': notes,
      'recipientName': recipientName,
    };
  }
}
