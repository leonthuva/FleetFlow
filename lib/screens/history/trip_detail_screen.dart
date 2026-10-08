import 'package:flutter/material.dart';
import '../../models/trip.dart';
import 'history_formatters.dart';

class TripDetailScreen extends StatelessWidget {
  final Trip trip;

  const TripDetailScreen({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final end = trip.endTime;

    return Scaffold(
      appBar: AppBar(title: Text(trip.id)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Trip overview', style: theme.textTheme.titleMedium),
                      TripStatusChip(status: trip.status),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _Metric(label: 'Distance', value: formatTripDistance(trip.distanceKm)),
                      _Metric(label: 'Duration', value: formatTripDuration(trip.duration())),
                      _Metric(
                        label: 'Avg speed',
                        value: '${trip.averageSpeedKmh().toStringAsFixed(0)} km/h',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                _DetailRow(icon: Icons.person_outline, label: 'Driver', value: trip.driverId),
                _DetailRow(icon: Icons.local_shipping_outlined, label: 'Vehicle', value: trip.vehicleId),
                _DetailRow(
                  icon: Icons.play_circle_outline,
                  label: 'Started',
                  value: formatTripDateTime(trip.startTime),
                ),
                _DetailRow(
                  icon: Icons.stop_circle_outlined,
                  label: 'Ended',
                  value: end == null ? 'In progress' : formatTripDateTime(end),
                ),
                _DetailRow(
                  icon: Icons.trip_origin,
                  label: 'Start point',
                  value: formatCoordinates(trip.startLat, trip.startLng),
                ),
                _DetailRow(
                  icon: Icons.flag_outlined,
                  label: 'End point',
                  value: formatCoordinates(trip.endLat, trip.endLng),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
      subtitle: Text(value, style: const TextStyle(fontSize: 15)),
    );
  }
}
