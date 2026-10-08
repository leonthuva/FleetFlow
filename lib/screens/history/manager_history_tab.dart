import 'package:flutter/material.dart';
import '../../models/trip_summary.dart';
import '../../models/user.dart';
import '../../providers/history_provider.dart';
import 'history_formatters.dart';
import 'trip_widgets.dart';

/// Fleet-wide trip history and reports for managers, embedded as a dashboard tab.
///
/// The caller owns [historyProvider] and disposes it.
class ManagerHistoryTab extends StatefulWidget {
  final HistoryProvider historyProvider;
  final AppUser? user;

  const ManagerHistoryTab({super.key, required this.historyProvider, this.user});

  @override
  State<ManagerHistoryTab> createState() => _ManagerHistoryTabState();
}

class _ManagerHistoryTabState extends State<ManagerHistoryTab> {
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

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final current = _provider.from != null && _provider.to != null
        ? DateTimeRange(
            start: _provider.from!,
            end: _provider.to!.subtract(const Duration(days: 1)),
          )
        : null;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: current,
    );
    if (picked == null) return;

    final start = DateTime(picked.start.year, picked.start.month, picked.start.day);
    // The provider's end bound is exclusive, so include the whole last day.
    final end = DateTime(picked.end.year, picked.end.month, picked.end.day)
        .add(const Duration(days: 1));
    await _provider.setDateRange(start, end);
  }

  String get _dateRangeLabel {
    final from = _provider.from;
    final to = _provider.to;
    if (from == null || to == null) return 'Any date';
    return '${formatTripDate(from)} – ${formatTripDate(to.subtract(const Duration(days: 1)))}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _provider,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            TripSummaryCard(summary: _provider.summary),
            _buildFilters(),
            TripStatusFilterBar(provider: _provider),
            ..._buildContent(context),
          ],
        );
      },
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _FilterDropdown(
                  fieldKey: const ValueKey('driver-filter'),
                  label: 'Driver',
                  allLabel: 'All drivers',
                  value: _provider.driverFilter,
                  options: _provider.driverOptions,
                  onChanged: _provider.setDriverFilter,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FilterDropdown(
                  fieldKey: const ValueKey('vehicle-filter'),
                  label: 'Vehicle',
                  allLabel: 'All vehicles',
                  value: _provider.vehicleFilter,
                  options: _provider.vehicleOptions,
                  onChanged: _provider.setVehicleFilter,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                key: const ValueKey('date-range-button'),
                onPressed: _pickDateRange,
                icon: const Icon(Icons.date_range),
                label: Text(_dateRangeLabel),
              ),
              const Spacer(),
              if (_provider.hasActiveFilters)
                TextButton.icon(
                  key: const ValueKey('clear-filters-button'),
                  onPressed: _provider.clearFilters,
                  icon: const Icon(Icons.filter_alt_off),
                  label: const Text('Clear'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildContent(BuildContext context) {
    if (_provider.isLoading && _provider.trips.isEmpty) {
      return const [
        Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
      ];
    }

    final error = _provider.errorMessage;
    if (error != null) {
      return [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(error, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _provider.load, child: const Text('Retry')),
            ],
          ),
        ),
      ];
    }

    final trips = _provider.trips;
    if (trips.isEmpty) {
      return const [
        Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No trips found'))),
      ];
    }

    return [
      _ReportSection(
        title: 'By driver',
        keyPrefix: 'report-driver-',
        summaries: _provider.summaryByDriver,
        onSelect: _provider.setDriverFilter,
      ),
      _ReportSection(
        title: 'By vehicle',
        keyPrefix: 'report-vehicle-',
        summaries: _provider.summaryByVehicle,
        onSelect: _provider.setVehicleFilter,
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text('Trips', style: Theme.of(context).textTheme.titleMedium),
      ),
      for (final trip in trips)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TripCard(trip: trip),
        ),
    ];
  }
}

class _FilterDropdown extends StatelessWidget {
  final Key fieldKey;
  final String label;
  final String allLabel;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  const _FilterDropdown({
    required this.fieldKey,
    required this.label,
    required this.allLabel,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          key: fieldKey,
          isExpanded: true,
          value: options.contains(value) ? value : null,
          items: [
            DropdownMenuItem<String?>(value: null, child: Text(allLabel)),
            for (final option in options)
              DropdownMenuItem<String?>(value: option, child: Text(option)),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _ReportSection extends StatelessWidget {
  final String title;
  final String keyPrefix;
  final Map<String, TripSummary> summaries;
  final ValueChanged<String?> onSelect;

  const _ReportSection({
    required this.title,
    required this.keyPrefix,
    required this.summaries,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final entries = summaries.entries.toList()
      ..sort((a, b) => b.value.totalDistanceKm.compareTo(a.value.totalDistanceKm));

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          for (final entry in entries)
            ListTile(
              key: ValueKey('$keyPrefix${entry.key}'),
              dense: true,
              onTap: () => onSelect(entry.key),
              title: Text(entry.key),
              subtitle: Text(
                '${entry.value.tripCount} trips • ${entry.value.completedCount} completed • '
                '${formatTripDuration(entry.value.totalDuration)}',
              ),
              trailing: Text(
                formatTripDistance(entry.value.totalDistanceKm),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
