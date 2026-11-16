import 'package:flutter/material.dart';
import '../../providers/notification_provider.dart';
import '../../models/app_notification.dart';
import '../customer/customer_tracking_screen.dart';

class NotificationsScreen extends StatelessWidget {
  final NotificationProvider notificationProvider;
  const NotificationsScreen({super.key, required this.notificationProvider});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: notificationProvider,
      builder: (context, _) => Scaffold(
          appBar: AppBar(title: const Text('Fleet Notifications'), actions: [
            TextButton(
                onPressed: notificationProvider.markAllAsRead,
                child: const Text('Mark all read'))
          ]),
          body: notificationProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : notificationProvider.errorMessage != null
                  ? Center(child: Text(notificationProvider.errorMessage!))
                  : ListView(children: [
                      const ListTile(
                          title: Text('In-app alerts'),
                          subtitle: Text(
                              'Push notifications require a trusted server and are not enabled.')),
                      if (notificationProvider.notifications.isEmpty)
                        const ListTile(title: Text('No notifications')),
                      for (final n in notificationProvider.notifications)
                        ListTile(
                            leading: Icon(NotificationType.getIcon(n.type)),
                            title: Text(n.title),
                            subtitle: Text(n.message),
                            trailing: n.read
                                ? null
                                : const Icon(Icons.circle, size: 10),
                            onTap: () async {
                              await notificationProvider
                                  .markAsRead(n.notificationId);
                              if (context.mounted && n.deliveryId != null)
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => CustomerTrackingScreen(
                                            deliveryId: n.deliveryId)));
                            }),
                    ])));
}
