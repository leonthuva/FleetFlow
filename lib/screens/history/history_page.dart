import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../providers/history_provider.dart';
import 'trip_history_screen.dart';

class HistoryPage extends StatefulWidget {
  final AppUser user;
  const HistoryPage({super.key, required this.user});
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final provider = HistoryProvider();
  @override
  void dispose() {
    provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      TripHistoryScreen(historyProvider: provider, user: widget.user);
}
