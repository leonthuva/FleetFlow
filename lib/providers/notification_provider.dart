import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/app_notification.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _service = NotificationService();
  StreamSubscription<List<AppNotification>>? _subscription;
  List<AppNotification> _notifications = [];

  NotificationProvider() {
    _notifications = _service.currentNotifications;
    _subscription = _service.notificationsStream.listen((list) {
      _notifications = list;
      notifyListeners();
    });
  }

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _notifications.where((n) => !n.read).length;

  Future<void> markAsRead(String id) async {
    await _service.markAsRead(id);
  }

  Future<void> markAllAsRead() async {
    await _service.markAllAsRead();
  }

  Future<void> sendNotification({
    required String recipientId,
    required String message,
    required String type,
    String? title,
    Map<String, dynamic>? metadata,
  }) async {
    await _service.sendNotification(
      recipientId: recipientId,
      message: message,
      type: type,
      title: title,
      metadata: metadata,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
