import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/vehicle.dart';

class VehicleDriver {
  const VehicleDriver(
      {required this.id, required this.name, required this.activeVehicleId});
  final String id, name, activeVehicleId;
}

/// Firestore rules enforce the same manager and driver ownership boundaries.
class VehicleService {
  VehicleService({FirebaseFirestore? firestore, String? Function()? currentUid})
      : _db = firestore,
        _currentUid = currentUid;
  final FirebaseFirestore? _db;
  final String? Function()? _currentUid;
  FirebaseFirestore get firestore => _db ?? FirebaseFirestore.instance;
  String get _uid {
    final id = _currentUid == null
        ? FirebaseAuth.instance.currentUser?.uid
        : _currentUid();
    if (id == null || id.isEmpty) {
      throw StateError('Sign in before managing vehicles.');
    }
    return id;
  }

  static void _documentId(String id) {
    if (id.trim().isEmpty || id.contains('/') || id.length > 1500) {
      throw ArgumentError('A valid document ID is required.');
    }
  }

  static Map<String, dynamic> _fields(Vehicle vehicle) {
    final plate = vehicle.licensePlate.trim(), model = vehicle.model.trim();
    if (plate.isEmpty || plate.length > 32) {
      throw ArgumentError('License plate must contain 1–32 characters.');
    }
    if (model.isEmpty || model.length > 100) {
      throw ArgumentError('Model must contain 1–100 characters.');
    }
    if (!VehicleStatus.all.contains(vehicle.status)) {
      throw ArgumentError('Choose a valid vehicle status.');
    }
    return {'licensePlate': plate, 'model': model, 'status': vehicle.status};
  }

  static void _manager(Map<String, dynamic>? profile) {
    if (!['admin', 'dispatcher'].contains(profile?['role'])) {
      throw StateError('Only an admin or dispatcher may manage vehicles.');
    }
  }

  Future<void> _requireManager() async {
    final profile = await firestore.doc('users/$_uid').get(
          const GetOptions(source: Source.server),
        );
    _manager(profile.data());
  }

  Stream<List<Vehicle>> watchVehicles() =>
      firestore.collection('vehicles').snapshots().map((snapshot) {
        final vehicles = snapshot.docs
            .map((doc) => Vehicle.fromMap(doc.data(), documentId: doc.id))
            .toList();
        vehicles.sort((a, b) => a.licensePlate.compareTo(b.licensePlate));
        return vehicles;
      });

  Stream<List<VehicleDriver>> watchDrivers() => firestore
          .collection('users')
          .where('role', isEqualTo: 'driver')
          .snapshots()
          .map((snapshot) {
        final drivers = snapshot.docs.map((doc) {
          final data = doc.data();
          return VehicleDriver(
              id: doc.id,
              name: data['displayName'] as String? ?? doc.id,
              activeVehicleId: data['activeVehicleId'] as String? ?? '');
        }).toList();
        drivers.sort((a, b) => a.name.compareTo(b.name));
        return drivers;
      });

  Future<String> createVehicle(Vehicle vehicle) async {
    final fields = _fields(vehicle);
    await _requireManager();
    final ref = firestore.collection('vehicles').doc();
    await ref.set({
      ...fields,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> updateVehicle(Vehicle vehicle) async {
    _documentId(vehicle.id);
    final fields = _fields(vehicle);
    await _requireManager();
    await firestore.doc('vehicles/${vehicle.id}').update({
      ...fields,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Assignment only changes the driver's vehicle reference and audit time.
  /// Availability is managed independently; this does not create shift records.
  Future<void> assignVehicle(
      {required String driverId, required String vehicleId}) async {
    _documentId(driverId);
    if (vehicleId.isNotEmpty) _documentId(vehicleId);
    final actor = _uid;
    await firestore.runTransaction((tx) async {
      final manager = await tx.get(firestore.doc('users/$actor'));
      final driver = await tx.get(firestore.doc('users/$driverId'));
      _manager(manager.data());
      if (driver.data()?['role'] != 'driver') {
        throw StateError('Select an existing driver account.');
      }
      if (vehicleId.isNotEmpty) {
        final vehicle = await tx.get(firestore.doc('vehicles/$vehicleId'));
        if (!vehicle.exists) {
          throw StateError('The selected vehicle no longer exists.');
        }
      }
      tx.update(driver.reference, {
        'activeVehicleId': vehicleId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
