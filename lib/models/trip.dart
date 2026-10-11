class TripStatus {
  static const String active = 'active';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';

  static const List<String> all = [active, completed, cancelled];

  static String getLabel(String status) {
    switch (status) {
      case active:
        return 'In Progress';
      case completed:
        return 'Completed';
      case cancelled:
        return 'Cancelled';
      default:
        return status;
    }
  }
}

class Trip {
  final String id;
  final String driverId;
  final String vehicleId;
  final DateTime startTime;
  final DateTime? endTime; // null while the trip is still active
  final String status;
  final double? startLat;
  final double? startLng;
  final double? endLat;
  final double? endLng;
  final double distanceKm;

  const Trip({
    required this.id,
    required this.driverId,
    required this.vehicleId,
    required this.startTime,
    this.endTime,
    required this.status,
    this.startLat,
    this.startLng,
    this.endLat,
    this.endLng,
    this.distanceKm = 0,
  });

  bool get isActive => status == TripStatus.active;
  bool get isCompleted => status == TripStatus.completed;

  /// Elapsed time of the trip. For an active trip, measured up to [now].
  Duration duration({DateTime? now}) {
    final end = endTime ?? now ?? DateTime.now();
    final d = end.difference(startTime);
    return d.isNegative ? Duration.zero : d;
  }

  /// Average speed in km/h, or 0 when the trip has no measurable duration.
  double averageSpeedKmh({DateTime? now}) {
    final hours = duration(now: now).inSeconds / 3600;
    return hours <= 0 ? 0 : distanceKm / hours;
  }

  factory Trip.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return Trip(
      id: documentId ?? map['id'] as String? ?? '',
      driverId: map['driverId'] as String? ?? '',
      vehicleId: map['vehicleId'] as String? ?? '',
      startTime: _parseDate(map['startTime']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      endTime: _parseDate(map['endTime']),
      status: map['status'] as String? ?? TripStatus.completed,
      startLat: (map['startLat'] as num?)?.toDouble(),
      startLng: (map['startLng'] as num?)?.toDouble(),
      endLat: (map['endLat'] as num?)?.toDouble(),
      endLng: (map['endLng'] as num?)?.toDouble(),
      distanceKm: (map['distanceKm'] as num?)?.toDouble() ?? 0,
    );
  }

  /// Dates are stored as ISO-8601 strings here; Firestore `Timestamp` values are
  /// converted by the service layer (see `TripService`) so this model stays
  /// free of Firebase imports.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'driverId': driverId,
      'vehicleId': vehicleId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'status': status,
      'startLat': startLat,
      'startLng': startLng,
      'endLat': endLat,
      'endLng': endLng,
      'distanceKm': distanceKm,
    };
  }

  Trip copyWith({
    String? id,
    String? driverId,
    String? vehicleId,
    DateTime? startTime,
    DateTime? endTime,
    String? status,
    double? startLat,
    double? startLng,
    double? endLat,
    double? endLng,
    double? distanceKm,
  }) {
    return Trip(
      id: id ?? this.id,
      driverId: driverId ?? this.driverId,
      vehicleId: vehicleId ?? this.vehicleId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      startLat: startLat ?? this.startLat,
      startLng: startLng ?? this.startLng,
      endLat: endLat ?? this.endLat,
      endLng: endLng ?? this.endLng,
      distanceKm: distanceKm ?? this.distanceKm,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    try {
      // Firestore Timestamp (duck-typed to avoid importing cloud_firestore).
      return (value as dynamic).toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }
}
