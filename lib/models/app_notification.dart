import 'package:flutter/material.dart';

class NotificationType {
  static const String assignment = 'assignment';
  static const String statusChange = 'status_change';
  static const String routeDeviation = 'route_deviation';
  static const String safetyAlert = 'safety_alert';
  static const String deliveryCompleted = 'delivery_completed';
  static const String emergency = 'emergency';

  static IconData getIcon(String type) {
    switch (type) {
      case assignment:
        return Icons.assignment_ind_outlined;
      case statusChange:
        return Icons.published_with_changes_outlined;
      case routeDeviation:
        return Icons.alt_route_outlined;
      case safetyAlert:
        return Icons.warning_amber_rounded;
      case deliveryCompleted:
        return Icons.check_circle_outline;
      case emergency:
        return Icons.emergency_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  static Color getColor(String type) {
    switch (type) {
      case assignment:
        return Colors.blue;
      case statusChange:
        return Colors.orange;
      case routeDeviation:
        return Colors.deepPurple;
      case safetyAlert:
        return Colors.amber.shade800;
      case deliveryCompleted:
        return Colors.green;
      case emergency:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  static String getLabel(String type) {
    switch (type) {
      case assignment:
        return 'Assignment';
      case statusChange:
        return 'Status Update';
      case routeDeviation:
        return 'Route Deviation';
      case safetyAlert:
        return 'Safety Notice';
      case deliveryCompleted:
        return 'Delivered';
      case emergency:
        return 'Emergency Alert';
      default:
        return 'Notification';
    }
  }
}

class AppNotification {
  final String notificationId;
  final String recipientId;
  final String title;
  final String message;
  final String type;
  final DateTime timestamp;
  final bool read;
  final Map<String, dynamic>? metadata;

  const AppNotification({
    required this.notificationId,
    required this.recipientId,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    this.read = false,
    this.metadata,
  });

  String? get deliveryId => metadata?['deliveryId'] as String?;

  factory AppNotification.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return AppNotification(
      notificationId: documentId ?? map['notificationId'] as String? ?? map['id'] as String? ?? '',
      recipientId: map['recipientId'] as String? ?? '',
      title: map['title'] as String? ?? 'Fleet Notification',
      message: map['message'] as String? ?? '',
      type: map['type'] as String? ?? NotificationType.statusChange,
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] is DateTime
              ? map['timestamp'] as DateTime
              : DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now())
          : DateTime.now(),
      read: map['read'] as bool? ?? false,
      metadata: map['metadata'] is Map ? Map<String, dynamic>.from(map['metadata'] as Map) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'notificationId': notificationId,
      'recipientId': recipientId,
      'title': title,
      'message': message,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'read': read,
      if (metadata != null) 'metadata': metadata,
    };
  }

  AppNotification copyWith({
    String? notificationId,
    String? recipientId,
    String? title,
    String? message,
    String? type,
    DateTime? timestamp,
    bool? read,
    Map<String, dynamic>? metadata,
  }) {
    return AppNotification(
      notificationId: notificationId ?? this.notificationId,
      recipientId: recipientId ?? this.recipientId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      read: read ?? this.read,
      metadata: metadata ?? this.metadata,
    );
  }
}
