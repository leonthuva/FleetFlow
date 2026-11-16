import 'package:flutter/material.dart';
import '../../core/tracking_code.dart';
import '../../models/delivery.dart';
import '../../models/tracking_info.dart';
import '../../services/delivery_service.dart';

/// Public tracking by code. No sign-in; shows only status, first names and the
/// last update time.
class TrackDeliveryScreen extends StatefulWidget {
  final DeliveryService? service;
  final String? initialCode;
  const TrackDeliveryScreen({super.key, this.service, this.initialCode});

  @override
  State<TrackDeliveryScreen> createState() => _TrackDeliveryScreenState();
}

class _TrackDeliveryScreenState extends State<TrackDeliveryScreen> {
  late final DeliveryService _service = widget.service ?? DeliveryService();
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialCode);
  Stream<TrackingInfo?>? _stream;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null) _lookup();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _lookup() {
    final code = TrackingCode.normalize(_controller.text);
    if (!TrackingCode.isValid(code)) {
      setState(() {
        _stream = null;
        _error = 'Enter the 12-character tracking code you were given.';
      });
      return;
    }
    setState(() {
      _error = null;
      _stream = _service.watchTracking(code);
    });
  }

  String _message(String status) {
    switch (status) {
      case DeliveryStatus.assigned:
        return 'Your delivery has been assigned to a driver.';
      case DeliveryStatus.pickedUp:
        return 'The driver has picked up your package.';
      case DeliveryStatus.inTransit:
        return 'Your package is on its way.';
      case DeliveryStatus.arrived:
        return 'The driver has arrived at your location.';
      case DeliveryStatus.completed:
        return 'Your package has been delivered.';
      case DeliveryStatus.cancelled:
        return 'This delivery was cancelled. Please contact the sender.';
      default:
        return status;
    }
  }

  Widget _result(TrackingInfo info) {
    final cancelled = info.status == DeliveryStatus.cancelled;
    final step = DeliveryStatus.stepIndex(info.status);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (info.recipientFirstName.isNotEmpty)
              Text('Hello ${info.recipientFirstName}',
                  style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(DeliveryStatus.getLabel(info.status),
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(_message(info.status)),
            if (!cancelled) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                  value: (step + 1) / DeliveryStatus.standardSequence.length),
              const SizedBox(height: 8),
              Text(
                  'Step ${step + 1} of ${DeliveryStatus.standardSequence.length}',
                  style: theme.textTheme.bodySmall),
            ],
            if (info.driverFirstName != null) ...[
              const SizedBox(height: 12),
              Text('Driver: ${info.driverFirstName}'),
            ],
            if (info.updatedAt != null) ...[
              const SizedBox(height: 4),
              Text('Last update: ${info.updatedAt!.toLocal()}'.split('.').first,
                  style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Track a Delivery')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Enter the tracking code the sender gave you.'),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Tracking code',
              hintText: 'XXXX-XXXX-XXXX',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _lookup(),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _lookup, child: const Text('Track')),
          const SizedBox(height: 16),
          if (_stream != null)
            StreamBuilder<TrackingInfo?>(
              stream: _stream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Text(
                      'Tracking is unavailable right now. Please try again.');
                }
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final info = snap.data;
                if (info == null) {
                  return const Text(
                      'No delivery found for that code. Check it and try again.');
                }
                return _result(info);
              },
            ),
        ]),
      );
}
