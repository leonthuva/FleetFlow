import 'package:flutter/material.dart';
import '../../models/vehicle.dart';
import '../../services/vehicle_service.dart';

class VehicleFormScreen extends StatefulWidget {
  const VehicleFormScreen({super.key, required this.service, this.vehicle});
  final VehicleService service;
  final Vehicle? vehicle;
  @override
  State<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends State<VehicleFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _plate =
      TextEditingController(text: widget.vehicle?.licensePlate ?? '');
  late final _model = TextEditingController(text: widget.vehicle?.model ?? '');
  late String _status = VehicleStatus.all.contains(widget.vehicle?.status)
      ? widget.vehicle!.status
      : VehicleStatus.available;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _plate.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final vehicle = Vehicle(
        id: widget.vehicle?.id ?? '',
        licensePlate: _plate.text,
        model: _model.text,
        status: _status);
    try {
      if (widget.vehicle == null) {
        await widget.service.createVehicle(vehicle);
      } else {
        await widget.service.updateVehicle(vehicle);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = 'Vehicle could not be saved: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_saving,
      child: Scaffold(
          appBar: AppBar(
              title: Text(
                  widget.vehicle == null ? 'Add vehicle' : 'Edit vehicle')),
          body: Form(
              key: _form,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                TextFormField(
                    controller: _plate,
                    enabled: !_saving,
                    decoration:
                        const InputDecoration(labelText: 'License plate'),
                    maxLength: 32,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'License plate is required'
                        : null),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _model,
                    enabled: !_saving,
                    decoration: const InputDecoration(labelText: 'Model'),
                    maxLength: 100,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Model is required'
                        : null),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: [
                      for (final status in VehicleStatus.all)
                        DropdownMenuItem(
                            value: status,
                            child: Text(VehicleStatus.displayName(status)))
                    ],
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _status = value!)),
                if (_error != null)
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error))),
                const SizedBox(height: 24),
                FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Saving vehicle…' : 'Save vehicle')),
              ]))));
}
