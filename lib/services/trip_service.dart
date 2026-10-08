import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/trip.dart';

/// Reads trip history from Firestore `trips/`, falling back to in-memory
/// sample data when Firestore is unavailable (tests, offline dev), the same
/// approach `DeliveryService` uses.
///
/// `TripService()` is local-only. Use `TripService.firestore()` in the app.
class TripService {
  TripService({List<Trip>? seed, DateTime? now})
      : _db = null,
        _localTrips = List.of(seed ?? sampleTrips(now ?? DateTime.now()));

  TripService.firestore({FirebaseFirestore? instance, List<Trip>? seed, DateTime? now})
      : _db = instance ?? FirebaseFirestore.instance,
        _localTrips = List.of(seed ?? sampleTrips(now ?? DateTime.now()));

  static const String collectionName = 'trips';

  final FirebaseFirestore? _db;
  final List<Trip> _localTrips;

  /// Trips matching the filters, newest first.
  ///
  /// `driverId` + `startTime` queries need a Firestore composite index
  /// (`driverId` asc, `startTime` desc); if the query fails the local data is used.
  Future<List<Trip>> fetchTrips({
    String? driverId,
    String? vehicleId,
    String? status,
    DateTime? from,
    DateTime? to,
    int? limit,
  }) async {
    final db = _db;
    if (db != null) {
      try {
        Query<Map<String, dynamic>> query = db.collection(collectionName);
        if (driverId != null) query = query.where('driverId', isEqualTo: driverId);
        if (vehicleId != null) query = query.where('vehicleId', isEqualTo: vehicleId);
        if (status != null) query = query.where('status', isEqualTo: status);
        if (from != null) {
          query = query.where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(from));
        }
        if (to != null) {
          query = query.where('startTime', isLessThan: Timestamp.fromDate(to));
        }
        query = query.orderBy('startTime', descending: true);
        if (limit != null) query = query.limit(limit);

        final snapshot = await query.get();
        return snapshot.docs.map((d) => Trip.fromMap(d.data(), documentId: d.id)).toList();
      } catch (e) {
        debugPrint('TripService: Firestore query fallback to local data: $e');
      }
    }
    return _queryLocal(
      driverId: driverId,
      vehicleId: vehicleId,
      status: status,
      from: from,
      to: to,
      limit: limit,
    );
  }

  Future<Trip?> getTripById(String id) async {
    final db = _db;
    if (db != null) {
      try {
        final doc = await db.collection(collectionName).doc(id).get();
        if (doc.exists && doc.data() != null) {
          return Trip.fromMap(doc.data()!, documentId: doc.id);
        }
      } catch (e) {
        debugPrint('TripService: Firestore read fallback to local data: $e');
      }
    }
    for (final trip in _localTrips) {
      if (trip.id == id) return trip;
    }
    return null;
  }

  /// Saves a trip locally and, if connected, to Firestore.
  /// Intended for sample data and tests; real trips are written by Member 3's tracking.
  Future<void> saveTrip(Trip trip) async {
    final index = _localTrips.indexWhere((t) => t.id == trip.id);
    if (index == -1) {
      _localTrips.add(trip);
    } else {
      _localTrips[index] = trip;
    }

    final db = _db;
    if (db == null) return;
    try {
      final data = trip.toMap()
        ..['startTime'] = Timestamp.fromDate(trip.startTime)
        ..['endTime'] = trip.endTime == null ? null : Timestamp.fromDate(trip.endTime!);
      await db.collection(collectionName).doc(trip.id).set(data);
    } catch (e) {
      debugPrint('TripService: Firestore write failed: $e');
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
    final result = _localTrips.where((t) {
      if (driverId != null && t.driverId != driverId) return false;
      if (vehicleId != null && t.vehicleId != vehicleId) return false;
      if (status != null && t.status != status) return false;
      if (from != null && t.startTime.isBefore(from)) return false;
      if (to != null && !t.startTime.isBefore(to)) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
    return limit == null || limit >= result.length ? result : result.sublist(0, limit);
  }

  /// Sample history relative to [now]; driver and vehicle IDs match `DeliveryService` samples.
  static List<Trip> sampleTrips(DateTime now) {
    Trip trip(
      String id,
      String driver,
      String vehicle,
      Duration startedAgo,
      Duration length,
      double km, {
      String status = TripStatus.completed,
    }) {
      final start = now.subtract(startedAgo);
      return Trip(
        id: id,
        driverId: driver,
        vehicleId: vehicle,
        startTime: start,
        endTime: status == TripStatus.active ? null : start.add(length),
        status: status,
        startLat: 37.7749,
        startLng: -122.4194,
        endLat: status == TripStatus.active ? null : 37.7833,
        endLng: status == TripStatus.active ? null : -122.4167,
        distanceKm: km,
      );
    }

    return [
      trip('TRP-1001', 'Marcus Vance', 'FL-101', const Duration(days: 6, hours: 5),
          const Duration(hours: 2, minutes: 10), 48.6),
      trip('TRP-1002', 'Sara Connor', 'FL-204', const Duration(days: 5, hours: 4),
          const Duration(hours: 1, minutes: 25), 31.2),
      trip('TRP-1003', 'Marcus Vance', 'FL-101', const Duration(days: 3, hours: 6),
          const Duration(hours: 3), 72.4),
      trip('TRP-1004', 'Liam Chen', 'FL-412', const Duration(days: 2, hours: 3),
          const Duration(minutes: 55), 18.9),
      trip('TRP-1005', 'Sara Connor', 'FL-204', const Duration(days: 1, hours: 7),
          const Duration(hours: 2, minutes: 40), 55.0, status: TripStatus.cancelled),
      trip('TRP-1006', 'Marcus Vance', 'FL-101', const Duration(hours: 1, minutes: 30),
          Duration.zero, 6.3, status: TripStatus.active),
    ];
  }
}
