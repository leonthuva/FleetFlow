import 'package:flutter/material.dart';
import '../../models/trip.dart';
import '../../models/trip_summary.dart';
import '../../providers/history_provider.dart';
import 'history_formatters.dart';
import 'trip_detail_screen.dart';

/// Totals header: trips, distance, drive time.
class TripSummaryCard extends StatelessWidget {
  final TripSummary summary;
  final EdgeInsetsGeometry margin;

  const TripSummaryCard({
    super.key,
    required this.summary,
    this.margin = const EdgeInsets.fromLTRB(16, 16, 16, 8),
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: margin,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            _SummaryStat(label: 'Trips', value: '${summary.tripCount}'),
            _SummaryStat(label: 'Distance', value: formatTripDistance(summary.totalDistanceKm)),
            _SummaryStat(label: 'Drive time', value: formatTripDuration(summary.totalDuration)),
          ],
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryStat({required this.label, required this.value});

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

/// Horizontal All / Completed / In Progress / Cancelled filter chips.
class TripStatusFilterBar extends StatelessWidget {
  final HistoryProvider provider;

  const TripStatusFilterBar({super.key, required this.provider});

  static const List<(String label, String? status)> _filters = [
    ('All', null),
    ('Completed', TripStatus.completed),
    ('In Progress', TripStatus.active),
    ('Cancelled', TripStatus.cancelled),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final (label, status) in _filters)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                key: ValueKey('status-filter-${status ?? 'all'}'),
                label: Text(label),
                selected: provider.statusFilter == status,
                onSelected: (_) => provider.setStatusFilter(status),
              ),
            ),
        ],
      ),
    );
  }
}

class TripCard extends StatelessWidget {
  final Trip trip;
  final bool showDriver;

  const TripCard({super.key, required this.trip, this.showDriver = true});

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (showDriver) trip.driverId,
      trip.vehicleId,
    ].join(' • ');

    return Card(
      key: ValueKey('trip-card-${trip.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TripDetailScreen(trip: trip)),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(trip.id, style: const TextStyle(fontWeight: FontWeight.w600)),
            TripStatusChip(status: trip.status),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(subtitle),
              const SizedBox(height: 2),
              Text(
                '${formatTripDateTime(trip.startTime)} • '
                '${formatTripDistance(trip.distanceKm)} • '
                '${formatTripDuration(trip.duration())}',
              ),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
