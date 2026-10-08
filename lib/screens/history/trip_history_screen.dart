import 'package:flutter/material.dart';
import '../../models/trip.dart';
import '../../models/user.dart';
import '../../providers/history_provider.dart';
import 'history_formatters.dart';
import 'trip_detail_screen.dart';

/// Trip history list with totals and status filters.
///
/// Pass the signed-in [user]: drivers only see their own trips, managers see
/// the whole fleet. The caller owns [historyProvider] and disposes it.
class TripHistoryScreen extends StatefulWidget {
  final HistoryProvider historyProvider;
  final AppUser? user;

  const TripHistoryScreen({super.key, required this.historyProvider, this.user});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  static const List<(String label, String? status)> _statusFilters = [
    ('All', null),
    ('Completed', TripStatus.completed),
    ('In Progress', TripStatus.active),
    ('Cancelled', TripStatus.cancelled),
  ];

  HistoryProvider get _provider => widget.historyProvider;

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    if (user != null) {
      _provider.loadForUser(user);
    } else {
      _provider.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.user?.isDriver == true ? 'My Trip History' : 'Trip History';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _provider.load,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _provider,
        builder: (context, _) {
          return Column(
            children: [
              _buildSummary(context),
              _buildStatusFilters(),
              Expanded(child: _buildBody(context)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummary(BuildContext context) {
    final summary = _provider.summary;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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

  Widget _buildStatusFilters() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final (label, status) in _statusFilters)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                key: ValueKey('status-filter-${status ?? 'all'}'),
                label: Text(label),
                selected: _provider.statusFilter == status,
                onSelected: (_) => _provider.setStatusFilter(status),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_provider.isLoading && _provider.trips.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final error = _provider.errorMessage;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _provider.load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final trips = _provider.trips;
    if (trips.isEmpty) {
      return const Center(child: Text('No trips found'));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: trips.length,
      itemBuilder: (context, index) => _TripCard(
        trip: trips[index],
        showDriver: widget.user?.isDriver != true,
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

class _TripCard extends StatelessWidget {
  final Trip trip;
  final bool showDriver;

  const _TripCard({required this.trip, required this.showDriver});

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
