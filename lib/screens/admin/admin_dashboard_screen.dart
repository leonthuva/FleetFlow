import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/delivery.dart';
import '../../providers/auth_provider.dart';
import '../../services/delivery_service.dart';
import 'create_delivery_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  final AuthProvider authProvider;
  final DeliveryService? service;
  const AdminDashboardScreen(
      {super.key, required this.authProvider, this.service});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _index = 0;
  late final DeliveryService _service = widget.service ?? DeliveryService();
  late final Stream<List<Delivery>> _stream = _service.watchDeliveries();
  Future<void> _create() async {
    try {
      final docs = await _service.firestore
          .collection('users')
          .where('role', isEqualTo: 'driver')
          .get();
      final drivers = docs.docs
          .where((d) => d.data()['onShift'] == true)
          .map((d) => EligibleDriver(
              id: d.id,
              name: d.data()['displayName'] as String? ?? d.id,
              status: 'On Shift'))
          .toList();
      if (!mounted) return;
      final id = await Navigator.push<String>(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  CreateDeliveryScreen(drivers: drivers, service: _service)));
      if (id != null && mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$id saved and assigned')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Driver directory unavailable: $e')));
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.authProvider,
      builder: (context, _) {
        if (widget.authProvider.currentUser?.isManager != true)
          return Scaffold(
              appBar: AppBar(title: const Text('Access Denied')),
              body:
                  const Center(child: Text('Manager Authorization Required')));
        return Scaffold(
            appBar: AppBar(title: const Text('FleetFlow Operations'), actions: [
              IconButton(
                  onPressed: () => widget.authProvider.signOut(),
                  icon: const Icon(Icons.logout))
            ]),
            floatingActionButton: FloatingActionButton.extended(
                onPressed: _create,
                label: const Text('Create delivery'),
                icon: const Icon(Icons.add)),
            body: _index == 1 || _index == 2
                ? _directory()
                : StreamBuilder<List<Delivery>>(
                    stream: _stream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError)
                        return Center(
                            child: Text(
                                'Deliveries unavailable: ${snapshot.error}'));
                      if (!snapshot.hasData)
                        return const Center(child: CircularProgressIndicator());
                      final all = snapshot.data!;
                      final shown = _index == 4
                          ? all.where((d) => !d.isActive).toList()
                          : all;
                      return ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            Text(
                                [
                                  'Dashboard',
                                  'Drivers',
                                  'Vehicles',
                                  'Delivery Dispatch',
                                  'Delivery History'
                                ][_index],
                                style:
                                    Theme.of(context).textTheme.headlineSmall),
                            if (_index == 0)
                              Text(
                                  '${all.length} deliveries - ${all.where((d) => d.isActive).length} active - ${all.where((d) => d.isCompleted).length} completed'),
                            if (shown.isEmpty)
                              const ListTile(
                                  title: Text('No deliveries found')),
                            for (final delivery in shown)
                              ListTile(
                                  title: Text(
                                      '${delivery.id} - ${delivery.recipientName}'),
                                  subtitle: Text(
                                      '${delivery.address}\n${delivery.statusDisplayName} - ${delivery.driverId}'),
                                  isThreeLine: true,
                                  onTap: () => showDialog<void>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                              title: Text(delivery.id),
                                              content: Text(
                                                  '${delivery.pickup} to ${delivery.address}\n${delivery.statusDisplayName}\nProof: ${delivery.proofPhotoUrl ?? "Not submitted"}'),
                                              actions: [
                                                TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(ctx),
                                                    child: const Text('Close'))
                                              ])),
                                  trailing: delivery.isActive
                                      ? IconButton(
                                          tooltip: 'Cancel delivery',
                                          icon:
                                              const Icon(Icons.cancel_outlined),
                                          onPressed: () => _cancel(delivery.id))
                                      : null),
                          ]);
                    }),
            bottomNavigationBar: NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                destinations: const [
                  NavigationDestination(
                      icon: Icon(Icons.dashboard), label: 'Dashboard'),
                  NavigationDestination(
                      icon: Icon(Icons.people), label: 'Drivers'),
                  NavigationDestination(
                      icon: Icon(Icons.local_shipping), label: 'Vehicles'),
                  NavigationDestination(
                      icon: Icon(Icons.inventory), label: 'Deliveries'),
                  NavigationDestination(
                      icon: Icon(Icons.history), label: 'History')
                ]));
      });
  Widget _directory() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: (_index == 1
              ? _service.firestore
                  .collection('users')
                  .where('role', isEqualTo: 'driver')
              : _service.firestore.collection('vehicles'))
          .snapshots(),
      builder: (context, s) {
        if (s.hasError)
          return Center(child: Text('Directory unavailable: ${s.error}'));
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        return ListView(children: [
          Text(_index == 1 ? 'Driver Roster' : 'Vehicle Inventory'),
          if (s.data!.docs.isEmpty)
            const ListTile(title: Text('No records found')),
          for (final d in s.data!.docs)
            ListTile(
                title: Text(
                    (d.data()['displayName'] ?? d.data()['model'] ?? d.id)
                        .toString()),
                subtitle: Text(d.id))
        ]);
      });
  Future<void> _cancel(String id) async {
    String text = '';
    final reason = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Cancellation reason'),
                content: TextField(onChanged: (value) => text = value),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Back')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, text),
                      child: const Text('Cancel delivery'))
                ]));
    if (reason == null) return;
    try {
      await _service.cancel(id, reason);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}
