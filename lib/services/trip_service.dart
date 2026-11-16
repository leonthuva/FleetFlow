import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/trip.dart';

/// Read-only history. No fabricated trips and no unapproved location collection.
class TripService {
  TripService({FirebaseFirestore? firestore, String? Function()? currentUid})
      : _db = firestore,
        _currentUid = currentUid;
  final FirebaseFirestore? _db;
  final String? Function()? _currentUid;
  FirebaseFirestore get db => _db ?? FirebaseFirestore.instance;
  String get uid =>
      (_currentUid == null
          ? FirebaseAuth.instance.currentUser?.uid
          : _currentUid()) ??
      (throw StateError('Sign in to view history.'));
  Future<List<Trip>> fetchTrips(
      {String? driverId,
      String? vehicleId,
      String? status,
      DateTime? from,
      DateTime? to,
      int? limit}) async {
    final actor = uid;
    final role = (await db.doc('users/$actor').get()).data()?['role'];
    if (!['driver', 'admin', 'dispatcher'].contains(role))
      throw StateError('Verified role required.');
    if (role == 'driver') {
      if (driverId != null && driverId != actor)
        throw StateError('Drivers may only view their own history.');
      driverId = actor;
    }
    Query<Map<String, dynamic>> query = db.collection('trips');
    if (driverId != null) query = query.where('driverId', isEqualTo: driverId);
    final snapshot = await query.get();
    final trips = snapshot.docs
        .map((d) => Trip.fromMap(d.data(), documentId: d.id))
        .where((t) =>
            (vehicleId == null || t.vehicleId == vehicleId) &&
            (status == null || t.status == status) &&
            (from == null || !t.startTime.isBefore(from)) &&
            (to == null || t.startTime.isBefore(to)))
        .toList();
    trips.sort((a, b) => b.startTime.compareTo(a.startTime));
    return limit == null ? trips : trips.take(limit).toList();
  }
}
