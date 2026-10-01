import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../models/app_notification.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal() {
    _initLocalDemoSeed();
  }

  FirebaseFirestore? _firestore;
  FirebaseMessaging? _messaging;

  final List<AppNotification> _inMemoryNotifications = [];
  final StreamController<List<AppNotification>> _notificationsStreamController =
      StreamController<List<AppNotification>>.broadcast();

  Stream<List<AppNotification>> get notificationsStream =>
      _notificationsStreamController.stream;
  List<AppNotification> get currentNotifications =>
      List.unmodifiable(_inMemoryNotifications);

  FirebaseFirestore get firestore {
    _firestore ??= FirebaseFirestore.instance;
    return _firestore!;
  }

  FirebaseMessaging get messaging {
    _messaging ??= FirebaseMessaging.instance;
    return _messaging!;
  }

  void _initLocalDemoSeed() {
    _inMemoryNotifications.addAll([
      AppNotification(
        notificationId: 'notif_demo_1',
        recipientId: 'all_managers',
        title: 'New Delivery Assigned',
        message: 'Delivery DEL-8801 has been assigned to driver Marcus Vance.',
        type: NotificationType.assignment,
        timestamp: DateTime.now().subtract(const Duration(minutes: 45)),
        read: true,
        metadata: {'deliveryId': 'DEL-8801'},
      ),
      AppNotification(
        notificationId: 'notif_demo_2',
        recipientId: 'all_managers',
        title: 'Delivery Status: In Transit',
        message: 'Sara Connor started transit for delivery DEL-8802.',
        type: NotificationType.statusChange,
        timestamp: DateTime.now().subtract(const Duration(minutes: 20)),
        read: false,
        metadata: {'deliveryId': 'DEL-8802'},
      ),
      AppNotification(
        notificationId: 'notif_demo_3',
        recipientId: 'all_managers',
        title: 'Proof Submitted & Completed',
        message: 'Liam Chen completed delivery DEL-8804 and submitted photo proof.',
        type: NotificationType.deliveryCompleted,
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        read: false,
        metadata: {'deliveryId': 'DEL-8804'},
      ),
    ]);
    _notifyLocalSubscribers();
  }

  void _notifyLocalSubscribers() {
    _inMemoryNotifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (!_notificationsStreamController.isClosed) {
      _notificationsStreamController.add(List.unmodifiable(_inMemoryNotifications));
    }
  }

  /// Initialize FCM, register device token, and set up foreground message listeners.
  Future<void> initialize() async {
    try {
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('NotificationService: FCM authorization status: ${settings.authorizationStatus}');

      final token = await messaging.getToken();
      debugPrint('NotificationService: FCM registration token: $token');

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('NotificationService: Foreground FCM message received: ${message.messageId}');
        final notification = AppNotification(
          notificationId: message.messageId ?? 'fcm_${DateTime.now().millisecondsSinceEpoch}',
          recipientId: 'current_user',
          title: message.notification?.title ?? 'Fleet Update',
          message: message.notification?.body ?? '',
          type: message.data['type'] ?? NotificationType.statusChange,
          timestamp: DateTime.now(),
          read: false,
          metadata: message.data,
        );
        _inMemoryNotifications.insert(0, notification);
        _notifyLocalSubscribers();
      });
    } catch (e) {
      debugPrint('NotificationService: FCM init graceful fallback for test/offline: $e');
    }
  }

  /// Agreed contract for Members 1, 2, 3, 4:
  /// `sendNotification(recipientId, message, type)`
  /// Writes to Firestore `notifications` collection and notifies subscribers.
  Future<AppNotification> sendNotification({
    required String recipientId,
    required String message,
    required String type,
    String? title,
    Map<String, dynamic>? metadata,
  }) async {
    final notificationId = 'notif_${DateTime.now().millisecondsSinceEpoch}';
    final computedTitle = title ?? _getDefaultTitleForType(type);

    final notification = AppNotification(
      notificationId: notificationId,
      recipientId: recipientId,
      title: computedTitle,
      message: message,
      type: type,
      timestamp: DateTime.now(),
      read: false,
      metadata: metadata,
    );

    // Update in-memory feed immediately for instant UI feedback
    _inMemoryNotifications.insert(0, notification);
    _notifyLocalSubscribers();

    // Persist to Cloud Firestore `notifications` collection
    try {
      await firestore.collection('notifications').doc(notificationId).set(notification.toMap());
    } catch (e) {
      debugPrint('NotificationService: Firestore write fallback (offline or dev): $e');
    }

    return notification;
  }

  /// Helper to mark a notification as read
  Future<void> markAsRead(String notificationId) async {
    final index = _inMemoryNotifications.indexWhere((n) => n.notificationId == notificationId);
    if (index != -1) {
      _inMemoryNotifications[index] = _inMemoryNotifications[index].copyWith(read: true);
      _notifyLocalSubscribers();
    }

    try {
      await firestore.collection('notifications').doc(notificationId).update({'read': true});
    } catch (_) {}
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    for (int i = 0; i < _inMemoryNotifications.length; i++) {
      _inMemoryNotifications[i] = _inMemoryNotifications[i].copyWith(read: true);
    }
    _notifyLocalSubscribers();
  }

  int get unreadCount => _inMemoryNotifications.where((n) => !n.read).length;

  String _getDefaultTitleForType(String type) {
    switch (type) {
      case NotificationType.assignment:
        return 'New Delivery Assignment';
      case NotificationType.statusChange:
        return 'Delivery Status Updated';
      case NotificationType.routeDeviation:
        return 'Route Deviation Alert';
      case NotificationType.safetyAlert:
        return 'Driver Safety Notice';
      case NotificationType.deliveryCompleted:
        return 'Proof of Delivery Confirmed';
      case NotificationType.emergency:
        return 'Emergency Dispatch Triggered';
      default:
        return 'Fleet Notification';
    }
  }
}
