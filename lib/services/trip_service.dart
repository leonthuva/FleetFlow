import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/trip.dart';
import 'trip_alert_service.dart';

/// Trip repository. Firestore is explicit; local samples require the explicitly
/// named [TripService.localDemo] factory and are never a Firestore fallback.
class TripService {
  TripService.firestore({
    FirebaseFirestore? instance,
    TripAlertService? alerts,
  })  : _db = instance ?? FirebaseFirestore.instance,
        _localTrips = null,
        _alerts = alerts;

  TripService.localDemo({
    List<Trip>? seed,
    DateTime? now,
    TripAlertService? alerts,
  })  : _db = null,
        _localTrips = List.of(seed ?? demoTrips(now ?? DateTime.now())),
        _alerts = alerts;

  static const String collectionName = 'trips';

  final FirebaseFirestore? _db;
  final List<Trip>? _localTrips;
  final TripAlertService? _alerts;

  Future<List<Trip>> fetchTrips({
    String? driverId,
    String? vehicleId,
    String? status,
    DateTime? from,
    DateTime? to,
    int? limit,
  }) async {
    if (limit != null && limit < 1) {
      throw ArgumentError.value(limit, 'limit', 'Must be positive.');
    }

    final db = _db;
    if (db == null) {
      return _queryLocal(
        driverId: driverId,
        vehicleId: vehicleId,
        status: status,
        from: from,
        to: to,
        limit: limit,
      );
    }

    Query<Map<String, dynamic>> query = db.collection(collectionName);
    if (driverId != null) query = query.where('driverId', isEqualTo: driverId);
    if (vehicleId != null) {
      query = query.where('vehicleId', isEqualTo: vehicleId);
    }
    if (status != null) query = query.where('status', isEqualTo: status);
    if (from != null) {
      query = query.where(
        'startTime',
        isGreaterThanOrEqualTo: Timestamp.fromDate(from),
      );
    }
    if (to != null) {
      query = query.where('startTime', isLessThan: Timestamp.fromDate(to));
    }
    query = query.orderBy('startTime', descending: true);
    if (limit != null) query = query.limit(limit);

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => Trip.fromMap(doc.data(), documentId: doc.id))
        .toList(growable: false);
  }

  Future<Trip?> getTripById(String documentId) async {
    final db = _db;
    if (db == null) {
      for (final trip in _localTrips!) {
        if (trip.id == documentId) return trip;
      }
      return null;
    }

    final doc = await db.collection(collectionName).doc(documentId).get();
    final data = doc.data();
    return !doc.exists || data == null
        ? null
        : Trip.fromMap(data, documentId: doc.id);
  }

  /// Saves an active/completed/cancelled trip. A Firestore error is propagated;
  /// it is never converted into a successful local-only write.
  Future<void> saveTrip(Trip trip) async {
    if (trip.id.isEmpty) {
      throw ArgumentError.value(trip.id, 'trip.id');
    }
    if (trip.driverId.isEmpty) {
      throw ArgumentError.value(trip.driverId, 'trip.driverId');
    }
    if (trip.vehicleId.isEmpty) {
      throw ArgumentError.value(trip.vehicleId, 'trip.vehicleId');
    }
    if (!TripStatus.all.contains(trip.status)) {
      throw ArgumentError.value(trip.status, 'trip.status');
    }
    if (trip.isActive && trip.endTime != null) {
      throw ArgumentError('An active trip cannot have an endTime.');
    }
    if (trip.isCompleted && trip.endTime == null) {
      throw ArgumentError('A completed trip must have an endTime.');
    }

    final db = _db;
    if (db == null) {
      final trips = _localTrips!;
      final index = trips.indexWhere((existing) => existing.id == trip.id);
      if (index < 0) {
        trips.add(trip);
      } else {
        trips[index] = trip;
      }
      if (trip.isCompleted) {
        await _alerts?.notifyTripCompleted(trip);
      }
      return;
    }

    final ref = db.collection(collectionName).doc(trip.id);
    await db.runTransaction((transaction) async {
      final previous = await transaction.get(ref);
      final previousData = previous.data();

      final data = trip.toMap()..['updatedAt'] = FieldValue.serverTimestamp();
      if (!previous.exists) {
        data['createdAt'] = FieldValue.serverTimestamp();
      } else {
        final createdAt = previousData?['createdAt'];
        data['createdAt'] =
            createdAt is Timestamp ? createdAt : FieldValue.serverTimestamp();
      }
      transaction.set(ref, data);
    });

    // Alert deduplication is in-memory until M5/M6 agree on a durable outbox.
    // Re-saving a completed trip in this process retries a failed send.
    if (trip.isCompleted) {
      final alerts = _alerts;
      if (alerts == null) {
        throw StateError(
          'Trip was saved, but the Member 5 trip alert adapter is not configured.',
        );
      }
      await alerts.notifyTripCompleted(trip);
    }
  }

  List<Trip> _queryLocal({
    String? driverId,
    String? vehicleId,
    String? status,
    DateTime? from,
    DateTime? to,
    int? limit,
  }) {
    final result = _localTrips!.where((trip) {
      if (driverId != null && trip.driverId != driverId) return false;
      if (vehicleId != null && trip.vehicleId != vehicleId) return false;
      if (status != null && trip.status != status) return false;
      if (from != null && trip.startTime.isBefore(from)) return false;
      if (to != null && !trip.startTime.isBefore(to)) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
    return limit == null || limit >= result.length
        ? result
        : result.sublist(0, limit);
  }

  static List<Trip> demoTrips(DateTime now) {
    Trip sample(
      String id,
      String driverUid,
      String vehicleId,
      Duration startedAgo,
      Duration duration,
      double distanceKm, {
      String status = TripStatus.completed,
    }) {
      final start = now.subtract(startedAgo);
      return Trip(
        id: id,
        driverId: driverUid,
        vehicleId: vehicleId,
        startTime: start,
        endTime: status == TripStatus.active ? null : start.add(duration),
        status: status,
        startLat: 37.7749,
        startLng: -122.4194,
        endLat: status == TripStatus.active ? null : 37.7833,
        endLng: status == TripStatus.active ? null : -122.4167,
        distanceKm: distanceKm,
      );
    }

    // These identities are explicitly fictional demo IDs, not Firebase users.
    return [
      sample(
          'TRP-1001',
          'demo-driver-1',
          'FL-101',
          const Duration(days: 6, hours: 5),
          const Duration(hours: 2, minutes: 10),
          48.6),
      sample(
          'TRP-1002',
          'demo-driver-2',
          'FL-204',
          const Duration(days: 5, hours: 4),
          const Duration(hours: 1, minutes: 25),
          31.2),
      sample('TRP-1003', 'demo-driver-1', 'FL-101',
          const Duration(days: 3, hours: 6), const Duration(hours: 3), 72.4),
      sample('TRP-1004', 'demo-driver-3', 'FL-412',
          const Duration(days: 2, hours: 3), const Duration(minutes: 55), 18.9),
      sample(
          'TRP-1005',
          'demo-driver-2',
          'FL-204',
          const Duration(days: 1, hours: 7),
          const Duration(hours: 2, minutes: 40),
          55,
          status: TripStatus.cancelled),
      sample('TRP-1006', 'demo-driver-1', 'FL-101',
          const Duration(hours: 1, minutes: 30), Duration.zero, 6.3,
          status: TripStatus.active),
    ];
  }
}
