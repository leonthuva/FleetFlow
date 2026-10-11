import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../providers/history_provider.dart';
import 'trip_widgets.dart';

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
              TripSummaryCard(summary: _provider.summary),
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
      itemBuilder: (context, index) => TripCard(
        trip: trips[index],
        showDriver: widget.user?.isDriver != true,
      ),
    );
  }
}
