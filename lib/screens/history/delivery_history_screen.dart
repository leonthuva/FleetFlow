import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../models/delivery.dart';
import '../../services/delivery_service.dart';
import '../customer/customer_tracking_screen.dart';

class DeliveryHistoryScreen extends StatefulWidget {
  final AppUser user;
  final DeliveryService? service;
  const DeliveryHistoryScreen({super.key, required this.user, this.service});
  @override
  State<DeliveryHistoryScreen> createState() => _DeliveryHistoryScreenState();
}

class _DeliveryHistoryScreenState extends State<DeliveryHistoryScreen> {
  late final stream = (widget.service ?? DeliveryService())
      .watchDeliveries(driverId: widget.user.isDriver ? widget.user.id : null);
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Delivery History')),
      body: StreamBuilder<List<Delivery>>(
          stream: stream,
          builder: (context, s) {
            if (s.hasError)
              return Center(child: Text('History unavailable: ${s.error}'));
            if (!s.hasData)
              return const Center(child: CircularProgressIndicator());
            final history =
                s.data!.where((d) => d.isCompleted || d.isCancelled).toList();
            return ListView(children: [
              if (history.isEmpty)
                const ListTile(
                    title: Text('No completed or cancelled deliveries')),
              for (final d in history)
                ListTile(
                    title: Text(d.id),
                    subtitle:
                        Text('${d.recipientName} - ${d.statusDisplayName}'),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => CustomerTrackingScreen(
                                deliveryId: d.id, service: widget.service))))
            ]);
          }));
}
