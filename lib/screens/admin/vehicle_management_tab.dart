import 'package:flutter/material.dart';
import '../../models/vehicle.dart';
import '../../services/vehicle_service.dart';
import 'vehicle_form_screen.dart';

class VehicleManagementTab extends StatefulWidget {
  const VehicleManagementTab({super.key, required this.service});
  final VehicleService service;
  @override
  State<VehicleManagementTab> createState() => _VehicleManagementTabState();
}

class _VehicleManagementTabState extends State<VehicleManagementTab> {
  late Stream<List<Vehicle>> _vehicles = widget.service.watchVehicles();
  late Stream<List<VehicleDriver>> _drivers = widget.service.watchDrivers();

  Future<void> _edit([Vehicle? vehicle]) async {
    final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) =>
                VehicleFormScreen(service: widget.service, vehicle: vehicle)));
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Vehicle saved.')));
    }
  }

  Future<void> _assign(VehicleDriver driver, List<Vehicle> vehicles) async {
    final exists = vehicles.any((v) => v.id == driver.activeVehicleId);
    var selected = exists ? driver.activeVehicleId : '';
    var saving = false;
    String? error;
    final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
            builder: (context, update) => PopScope(
                canPop: !saving,
                child: AlertDialog(
                    title: Text('Assign vehicle to ${driver.name}'),
                    content: SizedBox(
                        width: 420,
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          if (!exists && driver.activeVehicleId.isNotEmpty)
                            const Text(
                                'The current vehicle record is unavailable. Select a replacement or Unassigned.'),
                          DropdownButtonFormField<String>(
                              initialValue: selected,
                              isExpanded: true,
                              decoration:
                                  const InputDecoration(labelText: 'Vehicle'),
                              items: [
                                const DropdownMenuItem(
                                    value: '', child: Text('Unassigned')),
                                for (final vehicle in vehicles)
                                  DropdownMenuItem(
                                      value: vehicle.id,
                                      child: Text(
                                          '${vehicle.licensePlate} · ${vehicle.model} · ${VehicleStatus.displayName(vehicle.status)}',
                                          overflow: TextOverflow.ellipsis))
                              ],
                              onChanged: saving
                                  ? null
                                  : (value) => update(() => selected = value!)),
                          if (error != null)
                            Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(error!,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error))),
                        ])),
                    actions: [
                      TextButton(
                          onPressed: saving
                              ? null
                              : () => Navigator.pop(dialogContext, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: saving
                              ? null
                              : () async {
                                  if (saving) return;
                                  update(() {
                                    saving = true;
                                    error = null;
                                  });
                                  try {
                                    await widget.service.assignVehicle(
                                        driverId: driver.id,
                                        vehicleId: selected);
                                    if (dialogContext.mounted) {
                                      Navigator.pop(dialogContext, true);
                                    }
                                  } catch (e) {
                                    if (dialogContext.mounted) {
                                      update(() {
                                        error =
                                            'Assignment could not be saved: $e';
                                        saving = false;
                                      });
                                    }
                                  }
                                },
                          child: Text(saving ? 'Saving…' : 'Save assignment'))
                    ]))));
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle assignment saved.')));
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Vehicle>>(
      stream: _vehicles,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Vehicles unavailable: ${snapshot.error}'),
            TextButton(
                onPressed: () =>
                    setState(() => _vehicles = widget.service.watchVehicles()),
                child: const Text('Retry vehicles'))
          ]));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final vehicles = snapshot.data!;
        return ListView(padding: const EdgeInsets.all(16), children: [
          Text('Vehicle Inventory',
              style: Theme.of(context).textTheme.headlineSmall),
          Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                  onPressed: () => _edit(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add vehicle'))),
          if (vehicles.isEmpty)
            const ListTile(
                title: Text('No vehicles yet. Add a vehicle to begin.')),
          for (final vehicle in vehicles)
            ListTile(
                title: Text(vehicle.licensePlate),
                subtitle: Text(
                    '${vehicle.model} · ${VehicleStatus.displayName(vehicle.status)}'),
                trailing: IconButton(
                    tooltip: 'Edit ${vehicle.licensePlate}',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _edit(vehicle))),
          const Divider(),
          Text('Driver vehicle assignments',
              style: Theme.of(context).textTheme.titleLarge),
          StreamBuilder<List<VehicleDriver>>(
              stream: _drivers,
              builder: (context, drivers) {
                if (drivers.hasError) {
                  return Column(children: [
                    Text('Drivers unavailable: ${drivers.error}'),
                    TextButton(
                        onPressed: () => setState(
                            () => _drivers = widget.service.watchDrivers()),
                        child: const Text('Retry drivers'))
                  ]);
                }
                if (!drivers.hasData) return const LinearProgressIndicator();
                if (drivers.data!.isEmpty) {
                  return const Text('No drivers found.');
                }
                return Column(children: [
                  for (final driver in drivers.data!)
                    ListTile(
                        title: Text(driver.name),
                        subtitle: Text(driver.activeVehicleId.isEmpty
                            ? 'Unassigned'
                            : vehicles
                                    .where(
                                        (v) => v.id == driver.activeVehicleId)
                                    .map((v) => v.licensePlate)
                                    .firstOrNull ??
                                'Assigned vehicle unavailable'),
                        trailing: TextButton(
                            onPressed: () => _assign(driver, vehicles),
                            child: const Text('Assign vehicle')))
                ]);
              })
        ]);
      });
}
