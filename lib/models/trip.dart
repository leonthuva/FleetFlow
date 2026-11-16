import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/firestore_dates.dart';

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
  const Trip({
    required this.id,
    required this.driverId,
    required this.vehicleId,
    required this.startTime,
    required this.status,
    this.endTime,
    this.startLat,
    this.startLng,
    this.endLat,
    this.endLng,
    this.distanceKm = 0,
    this.createdAt,
    this.updatedAt,
  });

  static const Object _unset = Object();

  /// Firestore document ID. It is deliberately omitted from [toMap].
  final String id;
  final String driverId;
  final String vehicleId;
  final DateTime startTime;
  final DateTime? endTime;
  final String status;
  final double? startLat;
  final double? startLng;
  final double? endLat;
  final double? endLng;
  final double distanceKm;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isActive => status == TripStatus.active;
  bool get isCompleted => status == TripStatus.completed;

  Duration duration({DateTime? now}) {
    final end = endTime ?? now ?? DateTime.now();
    final elapsed = end.difference(startTime);
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  double averageSpeedKmh({DateTime? now}) {
    final hours = duration(now: now).inSeconds / 3600;
    return hours <= 0 ? 0 : distanceKm / hours;
  }

  factory Trip.fromMap(Map<String, dynamic> map, {required String documentId}) {
    final driverId = map['driverId'];
    final vehicleId = map['vehicleId'];
    final status = map['status'];
    final startTime = parseFirestoreDate(map['startTime']);

    if (driverId is! String || driverId.isEmpty) {
      throw const FormatException(
          'Trip driverId must be a non-empty Firebase UID.');
    }
    if (vehicleId is! String || vehicleId.isEmpty) {
      throw const FormatException('Trip vehicleId must be a non-empty string.');
    }
    if (status is! String || !TripStatus.all.contains(status)) {
      throw const FormatException('Trip status is missing or unsupported.');
    }
    if (startTime == null) {
      throw const FormatException(
          'Trip startTime must be a valid Firestore date.');
    }
    final endTime = parseFirestoreDate(map['endTime']);
    if (status == TripStatus.active && endTime != null) {
      throw const FormatException('An active trip cannot have an endTime.');
    }
    if (status == TripStatus.completed && endTime == null) {
      throw const FormatException('A completed trip must have an endTime.');
    }

    return Trip(
      id: documentId,
      driverId: driverId,
      vehicleId: vehicleId,
      startTime: startTime,
      endTime: endTime,
      status: status,
      startLat: _asDouble(map['startLat']),
      startLng: _asDouble(map['startLng']),
      endLat: _asDouble(map['endLat']),
      endLng: _asDouble(map['endLng']),
      distanceKm: _asDouble(map['distanceKm']) ?? 0,
      createdAt: parseFirestoreDate(map['createdAt']),
      updatedAt: parseFirestoreDate(map['updatedAt']),
    );
  }

  /// Canonical Firestore fields. The service sets server-owned audit times.
  Map<String, dynamic> toMap() => {
        'driverId': driverId,
        'vehicleId': vehicleId,
        'startTime': Timestamp.fromDate(startTime),
        'endTime': endTime == null ? null : Timestamp.fromDate(endTime!),
        'status': status,
        'startLat': startLat,
        'startLng': startLng,
        'endLat': endLat,
        'endLng': endLng,
        'distanceKm': distanceKm,
        if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
        if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      };

  Trip copyWith({
    String? id,
    String? driverId,
    String? vehicleId,
    DateTime? startTime,
    Object? endTime = _unset,
    String? status,
    Object? startLat = _unset,
    Object? startLng = _unset,
    Object? endLat = _unset,
    Object? endLng = _unset,
    double? distanceKm,
    Object? createdAt = _unset,
    Object? updatedAt = _unset,
  }) {
    return Trip(
      id: id ?? this.id,
      driverId: driverId ?? this.driverId,
      vehicleId: vehicleId ?? this.vehicleId,
      startTime: startTime ?? this.startTime,
      endTime: identical(endTime, _unset) ? this.endTime : endTime as DateTime?,
      status: status ?? this.status,
      startLat:
          identical(startLat, _unset) ? this.startLat : startLat as double?,
      startLng:
          identical(startLng, _unset) ? this.startLng : startLng as double?,
      endLat: identical(endLat, _unset) ? this.endLat : endLat as double?,
      endLng: identical(endLng, _unset) ? this.endLng : endLng as double?,
      distanceKm: distanceKm ?? this.distanceKm,
      createdAt: identical(createdAt, _unset)
          ? this.createdAt
          : createdAt as DateTime?,
      updatedAt: identical(updatedAt, _unset)
          ? this.updatedAt
          : updatedAt as DateTime?,
    );
  }

  static double? _asDouble(dynamic value) =>
      value is num ? value.toDouble() : null;
}
