import 'package:flutter/material.dart';
import '../../models/delivery.dart';
import '../../providers/driver_provider.dart';
import '../../widgets/driver/camera_pod_insertion_point.dart';
import '../../widgets/driver/map_insertion_point.dart';
import '../../widgets/driver/safety_telematics_insertion_point.dart';

class DeliveryDetailScreen extends StatefulWidget {
  final String deliveryId;
  final DriverProvider driverProvider;

  const DeliveryDetailScreen({
    super.key,
    required this.deliveryId,
    required this.driverProvider,
  });

  @override
  State<DeliveryDetailScreen> createState() => _DeliveryDetailScreenState();
}

class _DeliveryDetailScreenState extends State<DeliveryDetailScreen> {
  String? _temporaryPodPhotoUrl;
  String? _temporarySignatureNotes;

  void _advanceDelivery(Delivery delivery) {
    // If transitioning from arrived to completed, verify POD if required
    if (delivery.isArrived) {
      if (_temporaryPodPhotoUrl == null && delivery.proofPhotoUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please capture Proof of Delivery (photo) before completing.'),
            backgroundColor: Colors.purple,
          ),
        );
      }
    }

    final success = widget.driverProvider.advanceDeliveryStatus(delivery.id);
    if (success) {
      final updated = widget.driverProvider.getDeliveryById(delivery.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status updated to: ${updated?.statusDisplayName}'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } else {
      final err = widget.driverProvider.errorMessage ?? 'Status update failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: widget.driverProvider,
      builder: (context, _) {
        final delivery = widget.driverProvider.getDeliveryById(widget.deliveryId);

        if (delivery == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Delivery Details')),
            body: const Center(child: Text('Delivery not found.')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(delivery.id),
            actions: [
              IconButton(
                icon: const Icon(Icons.phone_outlined),
                tooltip: 'Call Recipient',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Calling recipient at ${delivery.recipientPhone}...')),
                  );
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Status Flow Lifecycle Stepper:
                // assigned -> picked_up -> in_transit -> arrived -> completed
                _buildStatusFlowProgress(context, delivery),
                const SizedBox(height: 16),

                // 2. Agreed Map Insertion Point (Member 5 Map / Member 3 GPS)
                MapInsertionPoint(
                  destinationLat: delivery.latitude,
                  destinationLng: delivery.longitude,
                  destinationAddress: delivery.address,
                  currentDriverLat: 37.7749,
                  currentDriverLng: -122.4194,
                  isNavigationActive: delivery.isInTransit,
                  onOpenExternalMap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Opening navigation to ${delivery.address}...')),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // 3. Recipient & Package Information Card
                _buildInfoCard(context, delivery),
                const SizedBox(height: 16),

                // 4. Agreed Safety & Telematics Insertion Point (Member 3 & 5)
                if (delivery.isInTransit) ...[
                  const SafetyTelematicsInsertionPoint(
                    currentSpeedKmh: 46.0,
                    speedLimitKmh: 50.0,
                    safetyScore: 97,
                  ),
                  const SizedBox(height: 16),
                ],

                // 5. Agreed Camera & POD Insertion Point (Member 5)
                CameraPodInsertionPoint(
                  deliveryId: delivery.id,
                  initialPhotoUrl: delivery.proofPhotoUrl ?? _temporaryPodPhotoUrl,
                  initialNotes: delivery.signatureNotes ?? _temporarySignatureNotes,
                  onPhotoCaptured: (url) {
                    setState(() {
                      _temporaryPodPhotoUrl = url;
                    });
                    widget.driverProvider.attachProofOfDelivery(
                      delivery.id,
                      url,
                      _temporarySignatureNotes ?? 'Delivered and verified by driver.',
                    );
                  },
                  onDetailsSubmitted: (recipient, notes) {
                    _temporarySignatureNotes = notes;
                    if (_temporaryPodPhotoUrl != null) {
                      widget.driverProvider.attachProofOfDelivery(
                        delivery.id,
                        _temporaryPodPhotoUrl!,
                        notes,
                      );
                    }
                  },
                ),
                const SizedBox(height: 80), // Padding for sticky bottom button
              ],
            ),
          ),
          bottomSheet: _buildBottomActionBar(context, delivery),
        );
      },
    );
  }

  /// Visual representation of the agreed status progression:
  /// assigned -> picked_up -> in_transit -> arrived -> completed
  Widget _buildStatusFlowProgress(BuildContext context, Delivery delivery) {
    const steps = [
      {'key': DeliveryStatus.assigned, 'label': 'Assigned', 'icon': Icons.assignment_turned_in},
      {'key': DeliveryStatus.pickedUp, 'label': 'Picked Up', 'icon': Icons.inventory_2},
      {'key': DeliveryStatus.inTransit, 'label': 'In Transit', 'icon': Icons.directions_car},
      {'key': DeliveryStatus.arrived, 'label': 'Arrived', 'icon': Icons.place},
      {'key': DeliveryStatus.completed, 'label': 'Completed', 'icon': Icons.check_circle},
    ];

    final currentIdx = delivery.statusStepIndex;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Delivery Lifecycle Flow',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.deepOrange.shade200),
                  ),
                  child: Text(
                    'Step ${currentIdx + 1} of 5: ${delivery.statusDisplayName}',
                    style: TextStyle(
                      color: Colors.deepOrange.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: List.generate(steps.length * 2 - 1, (index) {
                if (index.isOdd) {
                  // Connecting line between steps
                  final stepBefore = index ~/ 2;
                  final isPassed = stepBefore < currentIdx;
                  return Expanded(
                    child: Container(
                      height: 3,
                      color: isPassed ? Colors.deepOrange : Colors.grey.shade300,
                    ),
                  );
                } else {
                  // Step node icon
                  final stepNum = index ~/ 2;
                  final isCompleted = stepNum < currentIdx;
                  final isCurrent = stepNum == currentIdx;

                  Color nodeColor = Colors.grey.shade400;
                  if (isCompleted) nodeColor = Colors.green;
                  if (isCurrent) nodeColor = Colors.deepOrange;

                  return Tooltip(
                    message: steps[stepNum]['label'] as String,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? Colors.deepOrange
                                : (isCompleted ? Colors.green : Colors.grey.shade200),
                            shape: BoxShape.circle,
                            border: Border.all(color: nodeColor, width: 2),
                          ),
                          child: Icon(
                            steps[stepNum]['icon'] as IconData,
                            size: 16,
                            color: (isCurrent || isCompleted) ? Colors.white : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          steps[stepNum]['label'] as String,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                            color: isCurrent ? Colors.deepOrange : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  );
                }
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, Delivery delivery) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_pin_circle_outlined, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'Customer & Delivery Address',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              delivery.recipientName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              delivery.address,
              style: TextStyle(color: Colors.grey.shade800, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.phone, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  delivery.recipientPhone,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
              ],
            ),
            const Divider(height: 24),

            // Package Details
            Row(
              children: [
                Icon(Icons.inventory_2_outlined, color: Colors.amber.shade800),
                const SizedBox(width: 8),
                const Text(
                  'Package & Handling Notes',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              delivery.packageDescription,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.black54),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      delivery.specialInstructions,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActionBar(BuildContext context, Delivery delivery) {
    if (delivery.isCompleted) {
      return Container(
        color: Colors.green.shade50,
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade700),
            const SizedBox(width: 8),
            Text(
              'Delivery Completed Successfully',
              style: TextStyle(
                color: Colors.green.shade900,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }

    String actionLabel = 'Advance Status';
    IconData actionIcon = Icons.arrow_forward;
    Color buttonColor = Colors.deepOrange;

    switch (delivery.status) {
      case DeliveryStatus.assigned:
        actionLabel = 'Confirm Pickup (Mark Picked Up)';
        actionIcon = Icons.inventory;
        buttonColor = Colors.amber.shade800;
        break;
      case DeliveryStatus.pickedUp:
        actionLabel = 'Start Transit & GPS Navigation';
        actionIcon = Icons.navigation;
        buttonColor = Colors.deepOrange;
        break;
      case DeliveryStatus.inTransit:
        actionLabel = 'Mark Arrived at Destination';
        actionIcon = Icons.place;
        buttonColor = Colors.purple;
        break;
      case DeliveryStatus.arrived:
        actionLabel = 'Complete Delivery (Capture POD)';
        actionIcon = Icons.verified;
        buttonColor = Colors.green.shade700;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: FilledButton.icon(
          onPressed: () => _advanceDelivery(delivery),
          icon: Icon(actionIcon),
          label: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
          style: FilledButton.styleFrom(
            backgroundColor: buttonColor,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}
