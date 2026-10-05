import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/app_notification.dart';
import '../models/delivery.dart';
import '../models/delivery_proof.dart';
import 'notification_service.dart';
import 'storage_service.dart';

class DeliveryService {
  static final DeliveryService _instance = DeliveryService._internal();
  factory DeliveryService() => _instance;
  DeliveryService._internal() {
    _initSampleDeliveries();
  }

  FirebaseFirestore? _firestore;
  final StorageService _storageService = StorageService();
  final NotificationService _notificationService = NotificationService();

  final List<Delivery> _localDeliveries = [];
  final Map<String, DeliveryProof> _localProofs = {};
  final StreamController<List<Delivery>> _deliveriesStreamController =
      StreamController<List<Delivery>>.broadcast();

  Stream<List<Delivery>> get deliveriesStream => _deliveriesStreamController.stream;
  List<Delivery> get currentDeliveries => List.unmodifiable(_localDeliveries);

  FirebaseFirestore get firestore {
    _firestore ??= FirebaseFirestore.instance;
    return _firestore!;
  }

  void _initSampleDeliveries() {
    _localDeliveries.addAll([
      Delivery(
        id: 'DEL-8801',
        customerName: 'Alice Springs',
        customerPhone: '+1 (555) 234-5678',
        pickup: 'Central Depot Bay 4, Logistics Park',
        destination: '742 Evergreen Terrace, Springfield',
        assignedDriverId: 'Marcus Vance',
        vehicleId: 'FL-101',
        status: DeliveryStatus.inTransit,
        eta: '18 mins (approx. 4.2 km)',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      Delivery(
        id: 'DEL-8802',
        customerName: 'Wayne Enterprises (Attn: Lucius)',
        customerPhone: '+1 (555) 876-5432',
        pickup: 'Central Depot Bay 2, Logistics Park',
        destination: '100 Main St, Suite 400, Metro City',
        assignedDriverId: 'Sara Connor',
        vehicleId: 'FL-204',
        status: DeliveryStatus.arrived,
        eta: 'Driver Arrived at Destination',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      Delivery(
        id: 'DEL-8803',
        customerName: 'Robert Vance Refrigeration',
        customerPhone: '+1 (555) 345-6789',
        pickup: 'North Hub Dock 12',
        destination: '45 West Elm Avenue, Riverdale',
        assignedDriverId: 'Assigned Driver',
        vehicleId: 'FL-309',
        status: DeliveryStatus.assigned,
        eta: 'Scheduled for 2:30 PM',
        createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
      Delivery(
        id: 'DEL-8804',
        customerName: 'Harbor Fish Co.',
        customerPhone: '+1 (555) 987-6543',
        pickup: 'Warehouse District B',
        destination: '12 Harbor Bay Road, Dock 4',
        assignedDriverId: 'Liam Chen',
        vehicleId: 'FL-412',
        status: DeliveryStatus.completed,
        eta: 'Completed',
        proofPhotoUrl:
            'https://images.unsplash.com/photo-1549465220-1a8b9238cd48?auto=format&fit=crop&w=800&q=80',
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
        completedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
    ]);

    _localProofs['DEL-8804'] = DeliveryProof(
      id: 'proof_DEL-8804',
      deliveryId: 'DEL-8804',
      photoURL:
          'https://images.unsplash.com/photo-1549465220-1a8b9238cd48?auto=format&fit=crop&w=800&q=80',
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      capturedLocation: {
        'lat': 37.7749,
        'lng': -122.4194,
        'address': '12 Harbor Bay Road, Dock 4',
      },
      notes: 'Package placed safely with front-desk attendant.',
      recipientName: 'G. Fisherman',
    );

    _emitDeliveries();
  }

  void _emitDeliveries() {
    if (!_deliveriesStreamController.isClosed) {
      _deliveriesStreamController.add(List.unmodifiable(_localDeliveries));
    }
  }

  /// Get a single delivery by ID (for Customer Tracking View and Driver View)
  Delivery? getDeliveryById(String id) {
    try {
      return _localDeliveries.firstWhere((d) => d.id.toLowerCase() == id.trim().toLowerCase());
    } catch (_) {
      return null;
    }
  }

  /// Get proof of delivery record for a delivery
  DeliveryProof? getProofForDelivery(String deliveryId) {
    return _localProofs[deliveryId];
  }

  /// Update delivery status according to the state machine:
  /// `assigned` -> `picked_up` -> `in_transit` -> `arrived` -> `completed`
  Future<Delivery> updateStatus({
    required String deliveryId,
    required String newStatus,
  }) async {
    final index = _localDeliveries.indexWhere((d) => d.id == deliveryId);
    if (index == -1) {
      throw ArgumentError('Delivery $deliveryId not found');
    }

    final current = _localDeliveries[index];
    final updated = current.copyWith(
      status: newStatus,
      completedAt: newStatus == DeliveryStatus.completed ? DateTime.now() : null,
    );

    _localDeliveries[index] = updated;
    _emitDeliveries();

    // Trigger notification to manager/driver
    await _notificationService.sendNotification(
      recipientId: 'all_managers',
      message: 'Delivery ${current.id} status changed to ${DeliveryStatus.getLabel(newStatus)}.',
      type: NotificationType.statusChange,
      metadata: {'deliveryId': deliveryId, 'status': newStatus},
    );

    // Sync to Firestore
    try {
      await firestore.collection('deliveries').doc(deliveryId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        if (newStatus == DeliveryStatus.completed) 'completedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    return updated;
  }

  /// Submit Proof of Delivery:
  /// 1. Uploads photo to Firebase Storage (`deliveries/{deliveryId}/proof.jpg`)
  /// 2. Creates record in Firestore `deliveryProof` collection
  /// 3. Updates delivery doc with `status: 'completed'` & `proofPhotoUrl`
  /// 4. Sends completion push notification to manager
  Future<DeliveryProof> submitProofOfDelivery({
    required String deliveryId,
    File? photoFile,
    Uint8List? photoBytes,
    required Map<String, dynamic> location,
    String? notes,
    String? recipientName,
  }) async {
    // 1. Upload photo to Firebase Storage
    final photoUrl = await _storageService.uploadDeliveryProof(
      deliveryId: deliveryId,
      file: photoFile,
      bytes: photoBytes,
    );

    // 2. Build DeliveryProof record
    final proofId = 'proof_${DateTime.now().millisecondsSinceEpoch}';
    final proof = DeliveryProof(
      id: proofId,
      deliveryId: deliveryId,
      photoURL: photoUrl,
      timestamp: DateTime.now(),
      capturedLocation: location,
      notes: notes,
      recipientName: recipientName,
    );

    _localProofs[deliveryId] = proof;

    // 3. Update delivery to 'completed' with proof URL
    final index = _localDeliveries.indexWhere((d) => d.id == deliveryId);
    if (index != -1) {
      final updatedDelivery = _localDeliveries[index].copyWith(
        status: DeliveryStatus.completed,
        proofPhotoUrl: photoUrl,
        completedAt: DateTime.now(),
      );
      _localDeliveries[index] = updatedDelivery;
      _emitDeliveries();
    }

    // 4. Save to Firestore `deliveryProof` and update `deliveries`
    try {
      await firestore.collection('deliveryProof').doc(proofId).set(proof.toMap());
      await firestore.collection('deliveries').doc(deliveryId).update({
        'status': DeliveryStatus.completed,
        'proofPhotoUrl': photoUrl,
        'completedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('DeliveryService: Firestore write fallback: $e');
    }

    // 5. Send notification to operations manager
    await _notificationService.sendNotification(
      recipientId: 'all_managers',
      title: 'Proof Submitted & Order Delivered',
      message: 'Proof of delivery submitted for order $deliveryId. Delivery is now completed.',
      type: NotificationType.deliveryCompleted,
      metadata: {
        'deliveryId': deliveryId,
        'proofPhotoUrl': photoUrl,
        'proofId': proofId,
      },
    );

    return proof;
  }
}
