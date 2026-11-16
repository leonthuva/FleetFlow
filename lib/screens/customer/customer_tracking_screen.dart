import 'package:flutter/material.dart';
import '../../models/delivery.dart';
import '../../models/delivery_proof.dart';
import '../../services/delivery_service.dart';
import '../../widgets/private_proof_viewer.dart';

class CustomerTrackingScreen extends StatefulWidget {
  final String? deliveryId;
  final DeliveryService? service;
  const CustomerTrackingScreen({super.key, this.deliveryId, this.service});
  @override
  State<CustomerTrackingScreen> createState() => _CustomerTrackingScreenState();
}

class _CustomerTrackingScreenState extends State<CustomerTrackingScreen> {
  late final DeliveryService service = widget.service ?? DeliveryService();
  late final controller = TextEditingController(text: widget.deliveryId);
  Stream<Delivery?>? stream;
  @override
  void initState() {
    super.initState();
    if (widget.deliveryId != null) {
      stream = service.watchDelivery(widget.deliveryId!);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Delivery Tracking')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text(
            'Only authorized managers and the assigned driver may view a delivery.'),
        TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Delivery ID')),
        FilledButton(
            onPressed: () => setState(
                () => stream = service.watchDelivery(controller.text.trim())),
            child: const Text('View delivery')),
        if (stream != null)
          StreamBuilder<Delivery?>(
              stream: stream,
              builder: (context, s) {
                if (s.hasError) return Text('Delivery unavailable: ${s.error}');
                if (s.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final d = s.data;
                if (d == null) return const Text('Delivery not found');
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.id),
                      Text(d.statusDisplayName),
                      if (d.cancelReason != null)
                        Text('Cancellation reason: ${d.cancelReason}'),
                      Text(d.address),
                      if (d.isCompleted)
                        StreamBuilder<DeliveryProof?>(
                            stream: service.watchProof(d.id),
                            builder: (context, p) {
                              if (p.hasError) {
                                return Text('Proof unavailable: ${p.error}');
                              }
                              final proof = p.data;
                              return proof == null
                                  ? const Text('No proof record available')
                                  : Column(children: [
                                      Text(proof.recipientName ?? ''),
                                      if (proof.isVerifiedPrivateProof)
                                        PrivateProofViewer(
                                            deliveryId: d.id, service: service)
                                      else
                                        const Text(
                                            'Legacy proof requires an approved storage migration.'),
                                    ]);
                            })
                    ]);
              })
      ]));
}
