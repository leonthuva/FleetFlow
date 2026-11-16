import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/app_notification.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  NotificationProvider({NotificationService? service})
      : _service = service ?? NotificationService();
  final NotificationService _service;
  StreamSubscription<List<AppNotification>>? _subscription;
  List<AppNotification> _notifications = [];
  String? _uid;
  String? errorMessage;
  int _session = 0;
  bool isLoading = false;
  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((n) => !n.read).length;
  void bindUser(String? uid) {
    if (uid == _uid) return;
    _uid = uid;
    final session = ++_session;
    _subscription?.cancel();
    _notifications = [];
    errorMessage = null;
    isLoading = uid != null;
    if (uid != null) {
      _subscription = _service.watch(uid).listen((items) {
        if (session != _session) return;
        _notifications = items;
        isLoading = false;
        notifyListeners();
      }, onError: (Object e) {
        if (session != _session) return;
        _notifications = [];
        errorMessage = 'Alerts unavailable: $e';
        isLoading = false;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  Future<void> markAsRead(String id) async {
    try {
      await _service.markAsRead(id);
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _service.markAllAsRead();
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> sendNotification(
      {required String recipientId,
      required String message,
      required String type,
      String? title,
      Map<String, dynamic>? metadata}) async {
    await _service.sendNotification(
        recipientId: recipientId,
        message: message,
        type: type,
        title: title,
        metadata: metadata);
  }

  @override
  void dispose() {
    ++_session;
    _subscription?.cancel();
    super.dispose();
  }
}
