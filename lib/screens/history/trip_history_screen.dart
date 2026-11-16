import 'package:flutter/material.dart';
import '../../core/app_config.dart';
import '../../models/user.dart';
import '../../providers/history_provider.dart';
import 'trip_widgets.dart';

/// Trip history list with totals and status filters.
///
/// Pass the signed-in [user]: drivers only see their own trips, managers see
/// the whole fleet. The caller owns [historyProvider] and disposes it.
class TripHistoryScreen extends StatefulWidget {
  final HistoryProvider historyProvider;
  final AppUser user;

  const TripHistoryScreen(
      {super.key, required this.historyProvider, required this.user});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  HistoryProvider get _provider => widget.historyProvider;

  @override
  void initState() {
    super.initState();
    _provider.loadForUser(widget.user);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.user.isDriver ? 'My Trip History' : 'Trip History';

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
              if (AppConfig.demoMode)
                const MaterialBanner(
                  content: Text(
                      'DEMO DATA — these trips are local samples, not Firestore records.'),
                  leading: Icon(Icons.science_outlined),
                  actions: [SizedBox.shrink()],
                ),
              TripSummaryCard(summary: _provider.summary),
              if (_provider.warningMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _provider.warningMessage!,
                    key: const ValueKey('history-warning'),
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              TripStatusFilterBar(provider: _provider),
              Expanded(child: _buildBody(context)),
            ],
          );
        },
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
              OutlinedButton(
                  onPressed: _provider.load, child: const Text('Retry')),
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
      itemBuilder: (context, index) => TripCard(
        trip: trips[index],
        showDriver: !widget.user.isDriver,
      ),
    );
  }
}
