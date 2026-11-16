import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/delivery.dart';
import '../core/tracking_code.dart';
import '../models/delivery_proof.dart';
import '../models/tracking_info.dart';
import 'notification_service.dart';
import 'storage_service.dart';

/// One Firestore repository. Rules remain the authoritative security boundary.
class DeliveryService {
  DeliveryService(
      {FirebaseFirestore? firestore,
      String? Function()? currentUid,
      StorageService? storage})
      : _db = firestore,
        _currentUid = currentUid,
        _storage = storage ?? StorageService();
  final StorageService _storage;
  bool get proofStorageAvailable => _storage.isConfigured;
  Future<String> signedProofUrl(String deliveryId) =>
      _storage.signedProofUrl(deliveryId);
  Future<void> discardPendingProof(String deliveryId) =>
      _storage.discardPending(deliveryId);
  final FirebaseFirestore? _db;
  final String? Function()? _currentUid;
  FirebaseFirestore get firestore => _db ?? FirebaseFirestore.instance;
  String get uid =>
      (_currentUid == null
          ? FirebaseAuth.instance.currentUser?.uid
          : _currentUid()) ??
      (throw StateError('Sign in before accessing deliveries.'));
  String? notificationWarning;
  String? lastTrackingCode;
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
  CollectionReference<Map<String, dynamic>> get _links =>
      firestore.collection('trackingLinks');

  /// Public tracking view. Works without sign-in; the code is the credential.
  Stream<TrackingInfo?> watchTracking(String rawCode) {
    final code = TrackingCode.normalize(rawCode);
    if (!TrackingCode.isValid(code)) return Stream.value(null);
    return _links.doc(code).snapshots().map(
        (d) => d.exists ? TrackingInfo.fromMap(d.data()!, code: d.id) : null);
  }

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
      final code = TrackingCode.generate();
      if ((await tx.get(_links.doc(code))).exists) {
        throw StateError('Tracking code collision. Please try again.');
      }
      tx.set(counter, {'value': value});
      tx.set(target, {
        ...draft.copyWith(id: id, status: DeliveryStatus.assigned).toMap(),
        'createdBy': uid,
        'trackingCode': code,
        'createdAt': FieldValue.serverTimestamp(),
        'assignedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp()
      });
      final driverName =
          (driver.data()?['displayName'] as String? ?? '').trim();
      tx.set(_links.doc(code), {
        'deliveryId': id,
        'status': DeliveryStatus.assigned,
        'recipientFirstName': _firstName(draft.recipientName),
        if (driverName.isNotEmpty) 'driverFirstName': _firstName(driverName),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp()
      });
      lastTrackingCode = code;
      return id;
    });
    await _notify(
        recipientId: draft.driverId, deliveryId: id, status: 'assigned');
    return id;
  }

  static String _firstName(String full) {
    final parts = full.trim().split(RegExp(r'\s+'));
    final first = parts.isEmpty ? '' : parts.first;
    return first.length > 40 ? first.substring(0, 40) : first;
  }

  void _syncLink(
      Transaction tx, Map<String, dynamic>? delivery, String status) {
    final code = delivery?['trackingCode'] as String?;
    if (code == null || code.isEmpty) return;
    tx.update(_links.doc(code),
        {'status': status, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<Delivery> updateStatus(
      {required String deliveryId, required String newStatus}) async {
    if ([DeliveryStatus.completed, DeliveryStatus.cancelled]
        .contains(newStatus)) {
      throw StateError(newStatus == DeliveryStatus.completed
          ? 'Completion requires the trusted proof submission workflow.'
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
      _syncLink(tx, snap.data(), newStatus);
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
      _syncLink(tx, snap.data(), DeliveryStatus.cancelled);
    });
  }

  Future<DeliveryProof> submitProofOfDelivery(
      {required String deliveryId,
      File? photoFile,
      Uint8List? photoBytes,
      required Map<String, dynamic> location,
      String? notes,
      String? recipientName,
      DateTime? capturedAt}) async {
    if (!_storage.isConfigured) {
      throw StateError(
          'Secure Supabase proof storage is not configured. No proof was uploaded and the delivery was not completed.');
    }
    final actor = uid;
    final user = await firestore.collection('users').doc(actor).get();
    final snap = await _deliveries.doc(deliveryId).get();
    if (!snap.exists ||
        user.data()?['role'] != 'driver' ||
        snap.data()?['driverId'] != actor) {
      throw StateError('Only the assigned driver may submit proof.');
    }
    final bytes = photoBytes ?? await photoFile?.readAsBytes();
    if (bytes == null) throw ArgumentError('Capture a proof photograph first.');
    if (snap.data()?['status'] == DeliveryStatus.completed) {
      final existing =
          await firestore.collection('deliveryProofs').doc(deliveryId).get();
      if (existing.exists) {
        final proof =
            DeliveryProof.fromMap(existing.data()!, documentId: deliveryId);
        if (proof.isVerifiedPrivateProof &&
            proof.sha256 == crypto.sha256.convert(bytes).toString()) {
          return proof;
        }
        throw StateError(
            'This delivery already has immutable proof. It cannot be replaced.');
      }
    }
    if (snap.data()?['status'] != DeliveryStatus.arrived) {
      throw StateError('Proof requires the arrived stage.');
    }
    final proof = await _storage.submitProof(
        deliveryId: deliveryId,
        bytes: bytes,
        location: location,
        notes: notes,
        recipientName: recipientName,
        capturedAt: capturedAt);
    final persisted = await _deliveries
        .doc(deliveryId)
        .get(const GetOptions(source: Source.server));
    if (!persisted.exists ||
        persisted.data()?['status'] != DeliveryStatus.completed ||
        persisted.data()?['proofStoragePath'] != proof.storagePath) {
      throw StateError(
          'Proof verification returned, but completion could not be confirmed. Retry the same photograph.');
    }
    _cache[deliveryId] =
        Delivery.fromMap(persisted.data()!, documentId: deliveryId);
    notificationWarning = _storage.notificationWarning;
    // The trusted proof broker completes the delivery, so mirror the final
    // status onto the public tracking record. Rules require it to match.
    final code = persisted.data()?['trackingCode'] as String?;
    if (code != null && code.isNotEmpty) {
      try {
        await _links.doc(code).update({
          'status': DeliveryStatus.completed,
          'updatedAt': FieldValue.serverTimestamp()
        });
      } catch (e) {
        notificationWarning =
            'Delivery completed, but the customer tracking view was not updated: $e';
      }
    }
    return proof;
  }
}
