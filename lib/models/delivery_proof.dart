class DeliveryProof {
  final String id;
  final String deliveryId;
  final String photoURL;
  final DateTime timestamp;
  final Map<String, dynamic> capturedLocation;
  final String? notes;
  final String? recipientName;

  const DeliveryProof({
    required this.id,
    required this.deliveryId,
    required this.photoURL,
    required this.timestamp,
    required this.capturedLocation,
    this.notes,
    this.recipientName,
  });

  factory DeliveryProof.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return DeliveryProof(
      id: documentId ?? map['id'] as String? ?? '',
      deliveryId: map['deliveryId'] as String? ?? '',
      photoURL: map['photoURL'] as String? ?? map['photoUrl'] as String? ?? '',
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] is DateTime
              ? map['timestamp'] as DateTime
              : DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now())
          : DateTime.now(),
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
      'photoURL': photoURL,
      'timestamp': timestamp.toIso8601String(),
      'capturedLocation': capturedLocation,
      'notes': notes,
      'recipientName': recipientName,
    };
  }
}
