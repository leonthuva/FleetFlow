import 'package:flutter/material.dart';
import '../../services/notification_service.dart';

class SafetyTelematicsInsertionPoint extends StatefulWidget {
  final double currentSpeedKmh, speedLimitKmh;
  final int safetyScore, harshBrakingCount;
  final VoidCallback? onEmergencySosPressed;
  final String? deliveryId;
  const SafetyTelematicsInsertionPoint(
      {super.key,
      this.currentSpeedKmh = 0,
      this.speedLimitKmh = 0,
      this.safetyScore = 0,
      this.harshBrakingCount = 0,
      this.onEmergencySosPressed,
      this.deliveryId});
  @override
  State<SafetyTelematicsInsertionPoint> createState() => _SafetyState();
}

class _SafetyState extends State<SafetyTelematicsInsertionPoint> {
  bool pending = false;
  Future<void> send() async {
    setState(() => pending = true);
    try {
      await NotificationService().sendNotification(
          recipientId: 'all_managers',
          message: 'Assistance requested',
          type: 'emergency',
          metadata: {'deliveryId': widget.deliveryId});
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Assistance request saved to manager alerts.')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Request failed: $e')));
    } finally {
      if (mounted) setState(() => pending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            const Text(
                'Safety sensors and background telematics are not enabled.'),
            FilledButton.icon(
                onPressed: pending || widget.deliveryId == null ? null : send,
                icon: const Icon(Icons.support_agent),
                label:
                    Text(pending ? 'Sending...' : 'Request manager assistance'))
          ])));
}

class SafetyBannerWidget extends StatelessWidget {
  final int safetyScore;
  final bool isSafe;
  const SafetyBannerWidget(
      {super.key, this.safetyScore = 0, this.isSafe = false});
  @override
  Widget build(BuildContext context) => const Card(
      child: Padding(
          padding: EdgeInsets.all(12),
          child: Text(
              'Foreground GPS is available on assignments. Safety sensor scoring is not enabled.')));
}
