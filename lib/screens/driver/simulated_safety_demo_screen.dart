import 'package:flutter/material.dart';

/// Standalone UI for demonstrating safety states with fabricated values.
/// It has no sensor, location, persistence, or notification integration.
class SimulatedSafetyDemoScreen extends StatefulWidget {
  const SimulatedSafetyDemoScreen({super.key});

  @override
  State<SimulatedSafetyDemoScreen> createState() =>
      _SimulatedSafetyDemoScreenState();
}

class _SimulatedSafetyDemoScreenState extends State<SimulatedSafetyDemoScreen> {
  String? _simulatedEvent;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Safety Demo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            color: Color(0xFFFFF3E0),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.science_outlined, color: Colors.deepOrange),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'SIMULATED DATA ONLY — no GPS, vehicle sensors, or alerts are connected.',
                      key: ValueKey('simulated-data-notice'),
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Example speed',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text('68 km/h in a simulated 50 km/h zone'),
                  const SizedBox(height: 8),
                  const Text('Example safety score: 82/100 (simulated)'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Try a simulated event',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const ValueKey('simulate-speeding'),
            onPressed: () => setState(() => _simulatedEvent = 'Speeding'),
            icon: const Icon(Icons.speed),
            label: const Text('Simulate speeding event'),
          ),
          OutlinedButton.icon(
            key: const ValueKey('simulate-harsh-braking'),
            onPressed: () => setState(() => _simulatedEvent = 'Harsh braking'),
            icon: const Icon(Icons.warning_amber_outlined),
            label: const Text('Simulate harsh braking event'),
          ),
          if (_simulatedEvent != null) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Card(
                color: Colors.amber.shade50,
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title:
                      Text('Simulated ${_simulatedEvent!.toLowerCase()} event'),
                  subtitle: const Text('Demo state only. No alert was sent.'),
                ),
              ),
            ),
          ],
          TextButton(
            key: const ValueKey('reset-simulation'),
            onPressed: () => setState(() => _simulatedEvent = null),
            child: const Text('Reset simulation'),
          ),
        ],
      ),
    );
  }
}
