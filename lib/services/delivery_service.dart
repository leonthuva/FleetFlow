import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/delivery.dart';
import '../models/delivery_proof.dart';
import 'notification_service.dart';

/// One Firestore repository. Rules remain the authoritative security boundary.
class DeliveryService {
  DeliveryService(
      {FirebaseFirestore? firestore, String? Function()? currentUid})
      : _db = firestore,
        _currentUid = currentUid;
  final FirebaseFirestore? _db;
  final String? Function()? _currentUid;
  FirebaseFirestore get firestore => _db ?? FirebaseFirestore.instance;
  String get uid =>
      (_currentUid == null
          ? FirebaseAuth.instance.currentUser?.uid
          : _currentUid()) ??
      (throw StateError('Sign in before accessing deliveries.'));
  String? notificationWarning;
  final Map<String, Delivery> _cache = {};
  List<Delivery> get currentDeliveries => List.unmodifiable(_cache.values);
  Delivery? getDeliveryById(String id) => _cache[id];
  CollectionReference<Map<String, dynamic>> get _deliveries =>
      firestore.collection('deliveries');
  Stream<List<Delivery>> get deliveriesStream => watchDeliveries();
  Stream<List<Delivery>> watchDeliveries({String? driverId}) {
    Query<Map<String, dynamic>> query = _deliveries;
    if (driverId != null) query = query.where('driverId', isEqualTo: driverId);
    return query.snapshots().map((snapshot) {
      final values = snapshot.docs
          .map((d) => Delivery.fromMap(d.data(), documentId: d.id))
          .toList();
      values.sort((a, b) => (b.createdAt ?? DateTime(1970))
          .compareTo(a.createdAt ?? DateTime(1970)));
      _cache
        ..clear()
        ..addEntries(values.map((d) => MapEntry(d.id, d)));
      return values;
    });
  }

  Stream<Delivery?> watchDelivery(String id) =>
      _deliveries.doc(id).snapshots().map((d) =>
          d.exists ? Delivery.fromMap(d.data()!, documentId: d.id) : null);
  Stream<DeliveryProof?> watchProof(String id) =>
      firestore.collection('deliveryProofs').doc(id).snapshots().map((d) =>
          d.exists ? DeliveryProof.fromMap(d.data()!, documentId: d.id) : null);
  Future<void> _requireManager(Transaction tx) async {
    final user = await tx.get(firestore.collection('users').doc(uid));
    if (!['admin', 'dispatcher'].contains(user.data()?['role'])) {
      throw StateError('Only a manager can perform this operation.');
    }
  }

  Future<String> createAndAssign(Delivery draft) async {
    if ([
          draft.driverId,
          draft.recipientName,
          draft.recipientPhone,
          draft.pickup,
          draft.address,
          draft.packageDescription
        ].any((v) => v.trim().isEmpty) ||
        !draft.latitude.isFinite ||
        !draft.longitude.isFinite ||
        draft.latitude.abs() > 90 ||
        draft.longitude.abs() > 180 ||
        !['standard', 'high', 'urgent'].contains(draft.priority)) {
      throw ArgumentError(
          'Valid recipient, pickup, destination, coordinates, package and driver are required.');
    }
    notificationWarning = null;
    final id = await firestore.runTransaction((tx) async {
      await _requireManager(tx);
      final driver =
          await tx.get(firestore.collection('users').doc(draft.driverId));
      if (driver.data()?['role'] != 'driver' ||
          driver.data()?['onShift'] != true) {
        throw StateError('Selected driver is not an eligible on-shift driver.');
      }
      final counter = firestore.collection('counters').doc('deliveries');
      final count = await tx.get(counter);
      final value = (count.data()?['value'] as int? ?? 0) + 1;
      final id = 'DEL-${value.toString().padLeft(4, '0')}';
      final target = _deliveries.doc(id);
      if ((await tx.get(target)).exists) {
        throw StateError(
            'Delivery counter conflicts with an existing ID. Administrator repair required.');
      }
      tx.set(counter, {'value': value});
      tx.set(target, {
        ...draft.copyWith(id: id, status: DeliveryStatus.assigned).toMap(),
        'createdBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'assignedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp()
      });
      return id;
    });
    await _notify(
        recipientId: draft.driverId, deliveryId: id, status: 'assigned');
    return id;
  }

  Future<Delivery> updateStatus(
      {required String deliveryId, required String newStatus}) async {
    if ([DeliveryStatus.completed, DeliveryStatus.cancelled]
        .contains(newStatus)) {
      throw StateError(newStatus == DeliveryStatus.completed
          ? 'Completion requires secure proof persistence. Proof storage is currently unavailable.'
          : 'Use manager cancellation with a reason.');
    }
    final result = await firestore.runTransaction((tx) async {
      final user = await tx.get(firestore.collection('users').doc(uid));
      final ref = _deliveries.doc(deliveryId);
      final snap = await tx.get(ref);
      if (!snap.exists) throw StateError('Delivery not found.');
      final current = Delivery.fromMap(snap.data()!, documentId: snap.id);
      if (user.data()?['role'] != 'driver' || current.driverId != uid) {
        throw StateError('This delivery is not assigned to you.');
      }
      if (!current.canTransitionTo(newStatus)) {
        throw StateError('Invalid delivery stage transition.');
      }
      final field = {
        DeliveryStatus.pickedUp: 'pickedUpAt',
        DeliveryStatus.inTransit: 'inTransitAt',
        DeliveryStatus.arrived: 'arrivedAt'
      }[newStatus];
      if (field == null) throw StateError('Unsupported stage.');
      tx.update(ref, {
        'status': newStatus,
        field: FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp()
      });
      return current.copyWith(status: newStatus);
    });
    await _notify(
        recipientId: 'all_managers', deliveryId: deliveryId, status: newStatus);
    _cache[deliveryId] = result;
    return result;
  }

  Future<void> _notify(
      {required String recipientId,
      required String deliveryId,
      required String status}) async {
    notificationWarning = null;
    try {
      await NotificationService(firestore: _db, currentUid: _currentUid)
          .sendNotification(
              recipientId: recipientId,
              message: 'Delivery $deliveryId status: $status',
              type: status == 'assigned' ? 'assignment' : 'status_change',
              metadata: {'deliveryId': deliveryId, 'status': status});
    } catch (e) {
      notificationWarning = 'Delivery saved, but the in-app alert failed: $e';
    }
  }

  Future<void> cancel(String id, String reason) async {
    if (reason.trim().isEmpty) {
      throw ArgumentError('Cancellation reason required.');
    }
    await firestore.runTransaction((tx) async {
      await _requireManager(tx);
      final ref = _deliveries.doc(id);
      final snap = await tx.get(ref);
      if (!snap.exists || !Delivery.fromMap(snap.data()!).isActive) {
        throw StateError('Only active deliveries may be cancelled.');
      }
      tx.update(ref, {
        'status': DeliveryStatus.cancelled,
        'cancelReason': reason.trim(),
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp()
      });
    });
  }

  Future<DeliveryProof> submitProofOfDelivery(
      {required String deliveryId,
      File? photoFile,
      Uint8List? photoBytes,
      required Map<String, dynamic> location,
      String? notes,
      String? recipientName}) async {
    throw StateError(
        'Secure proof storage is unavailable on the current Firebase plan. No proof was uploaded and the delivery was not completed.');
  }
}
