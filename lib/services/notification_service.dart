import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_notification.dart';

/// Firestore in-app alerts only. No trusted FCM sender is configured.
class NotificationService {
  NotificationService(
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
      (throw StateError('Sign in to access alerts.'));
  List<AppNotification> get currentNotifications => const [];
  Future<void> initialize() async {}
  Stream<List<AppNotification>> watch(String userId) => firestore
          .collection('notifications')
          .where('recipientIds', arrayContains: userId)
          .snapshots()
          .map((s) {
        final items = s.docs
            .map((d) => AppNotification.fromMap(d.data(),
                documentId: d.id, currentUid: userId))
            .toList();
        items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return items;
      });
  Stream<List<AppNotification>> get notificationsStream => watch(uid);
  Future<AppNotification> sendNotification(
      {required String recipientId,
      required String message,
      required String type,
      String? title,
      Map<String, dynamic>? metadata}) async {
    final actor = uid;
    final user = await firestore.doc('users/$actor').get();
    final manager = ['admin', 'dispatcher'].contains(user.data()?['role']);
    List<String> targets;
    final toManagers = recipientId == 'all_managers';
    if (toManagers) {
      final directory =
          await firestore.doc('notificationTargets/managers').get();
      targets = List<String>.from(directory.data()?['uids'] ?? []);
    } else {
      if (!manager)
        throw StateError('Drivers may only alert approved manager recipients.');
      targets = [recipientId];
    }
    if (targets.isEmpty)
      throw StateError('No approved notification recipients configured.');
    var text = message;
    if (!manager) {
      if (metadata?['deliveryId'] is! String)
        throw ArgumentError('Assigned delivery required.');
      text = type == NotificationType.emergency
          ? 'Driver requests assistance for delivery ${metadata!['deliveryId']}.'
          : 'Delivery ${metadata!['deliveryId']} status changed to ${metadata['status'] ?? type}.';
    }
    final ref = firestore.collection('notifications').doc();
    final data = <String, dynamic>{
      'createdBy': actor,
      'audience': toManagers ? 'managers' : 'driver',
      'recipientIds': targets,
      'recipientRoles': toManagers ? ['admin', 'dispatcher'] : ['driver'],
      'title': title ?? NotificationType.getLabel(type),
      'message': text,
      'type': type,
      'timestamp': FieldValue.serverTimestamp(),
      'readBy': <String>[],
      'metadata': metadata ?? {}
    };
    await ref.set(data);
    return AppNotification.fromMap({...data, 'timestamp': DateTime.now()},
        documentId: ref.id, currentUid: actor);
  }

  Future<void> markAsRead(String id) async {
    await firestore.collection('notifications').doc(id).update({
      'readBy': FieldValue.arrayUnion([uid])
    });
  }

  Future<void> markAllAsRead() async {
    final notifications = await watch(uid).first;
    for (final item in notifications.where((n) => !n.read)) {
      await markAsRead(item.notificationId);
    }
  }
}
