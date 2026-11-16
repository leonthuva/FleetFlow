import 'package:flutter/material.dart';
import '../../providers/driver_provider.dart';

class ShiftSummaryScreen extends StatelessWidget {
  final DriverProvider driverProvider;
  const ShiftSummaryScreen({super.key, required this.driverProvider});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: driverProvider,
      builder: (context, _) => Scaffold(
          appBar: AppBar(title: const Text('Shift Summary')),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            Text(driverProvider.isShiftActive ? 'Shift active' : 'Shift ended'),
            Text(
                'Session duration: ${driverProvider.shiftDuration.inMinutes} minutes'),
            Text('Vehicle: ${driverProvider.activeVehicle.licensePlate}'),
            Text('Assigned records: ${driverProvider.totalAssigned}'),
            Text('Completed: ${driverProvider.completedCount}'),
            Text('In progress: ${driverProvider.inProgressCount}'),
            const Text(
                'Your on-shift status is saved so managers can assign you deliveries. Shift timing is local to this app session. No background telemetry is recorded.'),
            FilledButton(
                onPressed: driverProvider.isShiftBusy
                    ? null
                    : driverProvider.isShiftActive
                        ? () => driverProvider.endShift()
                        : () => driverProvider.startShift(),
                child: Text(driverProvider.isShiftActive
                    ? 'End shift'
                    : 'Start shift')),
            TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, '/delivery-history'),
                child: const Text('Delivery history')),
          ])));
}
