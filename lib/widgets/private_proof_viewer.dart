import 'package:flutter/material.dart';
import '../services/delivery_service.dart';

/// Signed URLs live only in widget memory and are refreshed after expiry/error.
class PrivateProofViewer extends StatefulWidget {
  final String deliveryId;
  final DeliveryService service;
  const PrivateProofViewer(
      {super.key, required this.deliveryId, required this.service});
  @override
  State<PrivateProofViewer> createState() => _PrivateProofViewerState();
}

class _PrivateProofViewerState extends State<PrivateProofViewer> {
  late Future<String> future = widget.service.signedProofUrl(widget.deliveryId);
  void refresh() =>
      setState(() => future = widget.service.signedProofUrl(widget.deliveryId));
  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
      future: future,
      builder: (context, s) {
        if (s.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (s.hasError) {
          return Column(children: [
            Text('Private proof unavailable: ${s.error}'),
            TextButton(
                onPressed: refresh, child: const Text('Retry private proof'))
          ]);
        }
        return Image.network(s.data!,
            height: 280,
            fit: BoxFit.contain,
            errorBuilder: (_, error, stack) => Column(children: [
                  const Text(
                      'The private image could not be loaded or its link expired.'),
                  TextButton(
                      onPressed: refresh,
                      child: const Text('Refresh private proof'))
                ]));
      });
}
