import 'package:flutter/material.dart';
import '../../models/delivery.dart';
import '../../models/delivery_proof.dart';
import '../../services/delivery_service.dart';

class CustomerTrackingScreen extends StatefulWidget {
  final String? deliveryId;

  const CustomerTrackingScreen({
    super.key,
    this.deliveryId,
  });

  @override
  State<CustomerTrackingScreen> createState() => _CustomerTrackingScreenState();
}

class _CustomerTrackingScreenState extends State<CustomerTrackingScreen> {
  final DeliveryService _deliveryService = DeliveryService();
  final TextEditingController _searchController = TextEditingController();

  Delivery? _delivery;
  DeliveryProof? _proof;
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    if (widget.deliveryId != null && widget.deliveryId!.isNotEmpty) {
      _searchController.text = widget.deliveryId!;
      _loadDelivery(widget.deliveryId!);
    } else {
      // Default to DEL-8801 for demonstration if none passed
      _searchController.text = 'DEL-8801';
      _loadDelivery('DEL-8801');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadDelivery(String id) {
    setState(() {
      _searched = true;
      _delivery = _deliveryService.getDeliveryById(id);
      if (_delivery != null) {
        _proof = _deliveryService.getProofForDelivery(_delivery!.id);
      } else {
        _proof = null;
      }
    });
  }

  String _getPlainLanguageStatus(String status) {
    switch (status) {
      case DeliveryStatus.assigned:
        return 'Order Received & Dispatched';
      case DeliveryStatus.pickedUp:
        return 'Package Picked Up by Driver';
      case DeliveryStatus.inTransit:
        return 'Driver is On The Way to You';
      case DeliveryStatus.arrived:
        return 'Driver Has Arrived at Destination';
      case DeliveryStatus.completed:
        return 'Delivered & Handed Over';
      default:
        return 'Processing Order';
    }
  }

  int _getStatusStepIndex(String status) {
    switch (status) {
      case DeliveryStatus.assigned:
        return 0;
      case DeliveryStatus.pickedUp:
        return 1;
      case DeliveryStatus.inTransit:
        return 2;
      case DeliveryStatus.arrived:
        return 3;
      case DeliveryStatus.completed:
        return 4;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Track Your Delivery'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Search / Tracking ID Input Bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(10),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Colors.deepOrange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Enter Tracking ID (e.g. DEL-8801)',
                          border: InputBorder.none,
                        ),
                        onSubmitted: (value) => _loadDelivery(value.trim()),
                      ),
                    ),
                    FilledButton.tonal(
                      onPressed: () => _loadDelivery(_searchController.text.trim()),
                      child: const Text('Track'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (_delivery == null && _searched)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          'Delivery Not Found',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Try entering DEL-8801, DEL-8802, or DEL-8804 for demo orders.',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else if (_delivery != null) ...[
                // Main Status Hero Card
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'ORDER ${_delivery!.id}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade600,
                                letterSpacing: 1.1,
                              ),
                            ),
                            Chip(
                              avatar: Icon(
                                _delivery!.isCompleted ? Icons.check_circle : Icons.local_shipping,
                                size: 16,
                                color: _delivery!.isCompleted ? Colors.green : Colors.deepOrange,
                              ),
                              label: Text(
                                DeliveryStatus.getLabel(_delivery!.status),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: _delivery!.isCompleted ? Colors.green.shade800 : Colors.deepOrange.shade800,
                                ),
                              ),
                              backgroundColor: _delivery!.isCompleted ? Colors.green.shade50 : Colors.deepOrange.shade50,
                              side: BorderSide.none,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _getPlainLanguageStatus(_delivery!.status),
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade900,
                              ),
                        ),
                        if (_delivery!.eta != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                'Estimated arrival: ${_delivery!.eta}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 20),

                        // Progress Stepper Bar
                        _buildProgressTracker(_getStatusStepIndex(_delivery!.status)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Driver & Vehicle Card
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: Colors.deepOrange.shade100,
                          child: Icon(Icons.person, color: Colors.deepOrange.shade800, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your Driver: ${_delivery!.assignedDriverId}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _delivery!.vehicleId.isNotEmpty
                                    ? 'Assigned Vehicle: ${_delivery!.vehicleId}'
                                    : 'Fleet Courier',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        IconButton.filledTonal(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Contacting driver ${_delivery!.assignedDriverId}...'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.phone),
                          tooltip: 'Contact Driver',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Destination Address Card
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Delivery Address',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on, color: Colors.deepOrange, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _delivery!.destination,
                                style: const TextStyle(fontSize: 14, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Proof of Delivery Photo Showcase (if delivered)
                if (_delivery!.isCompleted) ...[
                  const SizedBox(height: 16),
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.verified, color: Colors.green, size: 22),
                              SizedBox(width: 8),
                              Text(
                                'Proof of Delivery (Photo Confirmed)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_delivery!.proofPhotoUrl != null && _delivery!.proofPhotoUrl!.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: AspectRatio(
                                aspectRatio: 16 / 10,
                                child: Image.network(
                                  _delivery!.proofPhotoUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    color: Colors.grey.shade200,
                                    child: const Center(
                                      child: Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (_proof?.notes != null && _proof!.notes!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Driver Note: "${_proof!.notes}"',
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.grey.shade700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                          if (_proof?.recipientName != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Handover to: ${_proof!.recipientName}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressTracker(int activeIndex) {
    final steps = ['Assigned', 'Picked Up', 'In Transit', 'Arrived', 'Delivered'];

    return Row(
      children: List.generate(steps.length * 2 - 1, (index) {
        if (index.isOdd) {
          // Connector line
          final stepBefore = index ~/ 2;
          final isCompletedLine = stepBefore < activeIndex;
          return Expanded(
            child: Container(
              height: 3,
              color: isCompletedLine ? Colors.deepOrange : Colors.grey.shade300,
            ),
          );
        } else {
          // Step dot
          final stepIndex = index ~/ 2;
          final isCurrent = stepIndex == activeIndex;
          final isDone = stepIndex <= activeIndex;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone ? Colors.deepOrange : Colors.grey.shade300,
                  border: isCurrent ? Border.all(color: Colors.deepOrange.shade100, width: 4) : null,
                ),
                child: isDone
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : null,
              ),
              const SizedBox(height: 4),
              Text(
                steps[stepIndex],
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  color: isDone ? Colors.grey.shade900 : Colors.grey.shade500,
                ),
              ),
            ],
          );
        }
      }),
    );
  }
}
