import 'package:flutter/material.dart';
import '../models/delivery.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../services/delivery_service.dart';
import 'customer/customer_tracking_screen.dart';
import 'driver/driver_home_screen.dart';
import 'notifications/notifications_screen.dart';
import 'proof/proof_of_delivery_screen.dart';

class HomeScreen extends StatefulWidget {
  final AuthProvider? authProvider;

  const HomeScreen({super.key, this.authProvider});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DeliveryService _deliveryService = DeliveryService();
  final NotificationProvider _notificationProvider = NotificationProvider();
  bool _isOnShift = false;

  void _toggleShift() {
    setState(() {
      _isOnShift = !_isOnShift;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isOnShift ? 'Shift started. GPS logging active.' : 'Shift ended. GPS logging paused.'),
        backgroundColor: _isOnShift ? Colors.green.shade700 : Colors.grey.shade800,
      ),
    );
  }

  void _progressDeliveryStatus(Delivery delivery) async {
    String nextStatus;
    if (delivery.isAssigned) {
      nextStatus = DeliveryStatus.pickedUp;
    } else if (delivery.isPickedUp) {
      nextStatus = DeliveryStatus.inTransit;
    } else if (delivery.isInTransit) {
      nextStatus = DeliveryStatus.arrived;
    } else if (delivery.isArrived) {
      // Trigger Member 5 Proof of Delivery Camera Flow
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ProofOfDeliveryScreen(
            delivery: delivery,
            onCompleted: () => setState(() {}),
          ),
        ),
      );
      return;
    } else {
      return;
    }

    await _deliveryService.updateStatus(
      deliveryId: delivery.id,
      newStatus: nextStatus,
    );

    setState(() {});

    if (nextStatus == DeliveryStatus.arrived && mounted) {
      // Auto-prompt to capture proof of delivery as per spec
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Arrived at destination! Tap "Submit Proof (POD)" to complete delivery.'),
          action: SnackBarAction(
            label: 'Open Camera',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ProofOfDeliveryScreen(
                    delivery: delivery,
                    onCompleted: () => setState(() {}),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final deliveries = _deliveryService.currentDeliveries;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FleetFlow Driver'),
        actions: [
          // Switch to Driver Portal screen
          IconButton(
            icon: const Icon(Icons.dashboard_customize_outlined),
            tooltip: 'Driver Telematics Portal',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => DriverHomeScreen(
                    authProvider: widget.authProvider,
                  ),
                ),
              );
            },
          ),
          // Customer Tracking Simulator shortcut for demo
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Customer View (No Login)',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const CustomerTrackingScreen(),
                ),
              );
            },
          ),
          // Notification Feed Icon with Badge
          ListenableBuilder(
            listenable: _notificationProvider,
            builder: (context, _) {
              final unread = _notificationProvider.unreadCount;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    tooltip: 'Notifications',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => NotificationsScreen(
                            notificationProvider: _notificationProvider,
                          ),
                        ),
                      );
                    },
                  ),
                  if (unread > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$unread',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () async {
              if (widget.authProvider != null) {
                await widget.authProvider!.signOut();
              }
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Shift Control Banner
            Card(
              color: _isOnShift ? Colors.green.shade50 : Colors.amber.shade50,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: _isOnShift ? Colors.green.shade300 : Colors.amber.shade300,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: _isOnShift ? Colors.green : Colors.amber.shade800,
                      foregroundColor: Colors.white,
                      child: Icon(_isOnShift ? Icons.navigation : Icons.timer_outlined),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isOnShift ? 'Active Shift • Vehicle FL-101' : 'Off Shift • Offline',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Text(
                            _isOnShift ? 'GPS tracking running' : 'Start shift to begin route',
                            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _isOnShift ? Colors.red.shade700 : Colors.green.shade700,
                      ),
                      onPressed: _toggleShift,
                      child: Text(_isOnShift ? 'End Shift' : 'Start Shift'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Deliveries Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Assigned Deliveries (${deliveries.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const CustomerTrackingScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Customer View'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Delivery Cards with POD trigger
            ...deliveries.map((delivery) {
              final isDelivered = delivery.isCompleted;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            delivery.id,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Chip(
                            label: Text(
                              DeliveryStatus.getLabel(delivery.status),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDelivered ? Colors.green.shade800 : Colors.deepOrange.shade800,
                              ),
                            ),
                            backgroundColor: isDelivered ? Colors.green.shade50 : Colors.deepOrange.shade50,
                            side: BorderSide(
                              color: isDelivered ? Colors.green.shade200 : Colors.deepOrange.shade200,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Recipient: ${delivery.customerName}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              delivery.destination,
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Action Button based on status
                      if (!isDelivered)
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => _progressDeliveryStatus(delivery),
                                icon: Icon(
                                  delivery.isArrived ? Icons.camera_alt : Icons.arrow_forward,
                                  size: 18,
                                ),
                                label: Text(
                                  delivery.isAssigned
                                      ? 'Mark Picked Up'
                                      : delivery.isPickedUp
                                          ? 'Start Transit'
                                          : delivery.isInTransit
                                              ? 'Mark Arrived'
                                              : 'Capture Proof (POD)',
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: delivery.isArrived ? Colors.green.shade700 : null,
                                ),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green, size: 18),
                            const SizedBox(width: 6),
                            const Text(
                              'Proof verified & delivery completed',
                              style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => CustomerTrackingScreen(deliveryId: delivery.id),
                                  ),
                                );
                              },
                              child: const Text('View Proof'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}