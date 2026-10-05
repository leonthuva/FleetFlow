import 'package:flutter/material.dart';
import '../../models/app_notification.dart';
import '../../providers/notification_provider.dart';
import '../customer/customer_tracking_screen.dart';

class NotificationsScreen extends StatefulWidget {
  final NotificationProvider notificationProvider;

  const NotificationsScreen({
    super.key,
    required this.notificationProvider,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _selectedFilter = 'all';

  void _showTestNotificationSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Simulate Incoming Notification (Demo Tool)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.assignment_ind, color: Colors.white, size: 20),
                ),
                title: const Text('Member 1: New Delivery Assignment'),
                subtitle: const Text('Assigns order DEL-8803 to driver'),
                onTap: () {
                  Navigator.pop(context);
                  widget.notificationProvider.sendNotification(
                    recipientId: 'driver_user',
                    title: 'New Delivery Assigned',
                    message: 'New order DEL-8803 has been assigned to you. Destination: 45 West Elm Avenue.',
                    type: NotificationType.assignment,
                    metadata: {'deliveryId': 'DEL-8803'},
                  );
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.purple,
                  child: Icon(Icons.alt_route, color: Colors.white, size: 20),
                ),
                title: const Text('Member 3: Route Deviation Alert'),
                subtitle: const Text('Driver exceeded 500m threshold from route'),
                onTap: () {
                  Navigator.pop(context);
                  widget.notificationProvider.sendNotification(
                    recipientId: 'all_managers',
                    title: 'Route Deviation Detected',
                    message: 'Vehicle FL-101 has deviated 650m from designated route corridor.',
                    type: NotificationType.routeDeviation,
                    metadata: {'deliveryId': 'DEL-8801', 'vehicleId': 'FL-101'},
                  );
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.red,
                  child: Icon(Icons.warning, color: Colors.white, size: 20),
                ),
                title: const Text('Member 4: Safety / Emergency Alert'),
                subtitle: const Text('Potential impact detected by accelerometer'),
                onTap: () {
                  Navigator.pop(context);
                  widget.notificationProvider.sendNotification(
                    recipientId: 'all_managers',
                    title: 'Driver Emergency Alert',
                    message: 'Driver Marcus Vance triggered potential impact confirmation at Lat: 37.77, Lng: -122.41.',
                    type: NotificationType.emergency,
                    metadata: {'driverId': 'Marcus Vance', 'severity': 'high'},
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.notificationProvider,
      builder: (context, _) {
        final all = widget.notificationProvider.notifications;
        final filtered = _selectedFilter == 'unread'
            ? all.where((n) => !n.read).toList()
            : all;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Fleet Notifications'),
            actions: [
              IconButton(
                icon: const Icon(Icons.playlist_add_check),
                tooltip: 'Mark all as read',
                onPressed: all.any((n) => !n.read)
                    ? () => widget.notificationProvider.markAllAsRead()
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.add_alert_outlined),
                tooltip: 'Trigger Demo Alert',
                onPressed: _showTestNotificationSheet,
              ),
            ],
          ),
          body: Column(
            children: [
              // Filter Chips
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    FilterChip(
                      label: Text('All (${all.length})'),
                      selected: _selectedFilter == 'all',
                      onSelected: (_) => setState(() => _selectedFilter = 'all'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text('Unread (${widget.notificationProvider.unreadCount})'),
                      selected: _selectedFilter == 'unread',
                      onSelected: (_) => setState(() => _selectedFilter = 'unread'),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _showTestNotificationSheet,
                      icon: const Icon(Icons.bolt, size: 16),
                      label: const Text('Simulate'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Notification List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notifications_off_outlined, size: 56, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              _selectedFilter == 'unread'
                                  ? 'No unread notifications'
                                  : 'No notifications in history',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final notif = filtered[index];
                          final color = NotificationType.getColor(notif.type);
                          final icon = NotificationType.getIcon(notif.type);

                          return InkWell(
                            onTap: () {
                              widget.notificationProvider.markAsRead(notif.notificationId);
                              if (notif.deliveryId != null) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => CustomerTrackingScreen(
                                      deliveryId: notif.deliveryId!,
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Container(
                              color: notif.read ? null : color.withAlpha(15),
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: color.withAlpha(30),
                                    foregroundColor: color,
                                    child: Icon(icon, size: 22),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                notif.title,
                                                style: TextStyle(
                                                  fontWeight: notif.read ? FontWeight.w600 : FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                            if (!notif.read)
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  color: color,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          notif.message,
                                          style: TextStyle(
                                            color: Colors.grey.shade800,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              NotificationType.getLabel(notif.type),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: color,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              _formatTimeAgo(notif.timestamp),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
