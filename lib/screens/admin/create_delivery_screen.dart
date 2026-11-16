import 'package:flutter/material.dart';
import '../../models/delivery.dart';
import '../../services/delivery_service.dart';

class EligibleDriver {
  final String id;
  final String name;
  final String status;

  const EligibleDriver({
    required this.id,
    required this.name,
    required this.status,
  });
}

class CreateDeliveryScreen extends StatefulWidget {
  final List<EligibleDriver> drivers;
  final bool isLoadingDrivers;
  final DeliveryService? service;

  const CreateDeliveryScreen({
    super.key,
    required this.drivers,
    this.isLoadingDrivers = false,
    this.service,
  });

  @override
  State<CreateDeliveryScreen> createState() => _CreateDeliveryScreenState();
}

class _CreateDeliveryScreenState extends State<CreateDeliveryScreen> {
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  String? _error;
  final _formKey = GlobalKey<FormState>();
  final _recipientNameController = TextEditingController();
  final _recipientPhoneController = TextEditingController();
  final _pickupController = TextEditingController();
  final _addressController = TextEditingController();
  final _packageController = TextEditingController();
  final _instructionsController = TextEditingController();

  String? _driverId;
  String _priority = 'standard';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    _recipientNameController.dispose();
    _recipientPhoneController.dispose();
    _pickupController.dispose();
    _addressController.dispose();
    _packageController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label is required';
    return null;
  }

  Future<void> _saveDelivery() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });
    try {
      final id = await (widget.service ?? DeliveryService()).createAndAssign(
          Delivery(
              id: '',
              driverId: _driverId!,
              recipientName: _recipientNameController.text.trim(),
              recipientPhone: _recipientPhoneController.text.trim(),
              pickup: _pickupController.text.trim(),
              address: _addressController.text.trim(),
              packageDescription: _packageController.text.trim(),
              specialInstructions: _instructionsController.text.trim(),
              priority: _priority,
              latitude: double.parse(_latController.text),
              longitude: double.parse(_lngController.text)));
      if (!mounted) return;
      Navigator.pop(context, id);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableDrivers = widget.drivers
        .where((driver) => driver.status == 'On Shift')
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Create Delivery')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            Text(
              'Delivery details',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _recipientNameController,
              decoration: const InputDecoration(labelText: 'Recipient name'),
              validator: (value) => _required(value, 'Recipient name'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _recipientPhoneController,
              decoration: const InputDecoration(labelText: 'Recipient phone'),
              keyboardType: TextInputType.phone,
              validator: (value) => _required(value, 'Recipient phone'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pickupController,
              decoration: const InputDecoration(labelText: 'Pickup address'),
              validator: (value) => _required(value, 'Pickup address'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Delivery address'),
              validator: (value) => _required(value, 'Delivery address'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _packageController,
              decoration: const InputDecoration(
                labelText: 'Package description',
              ),
              validator: (value) => _required(value, 'Package description'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _instructionsController,
              decoration: const InputDecoration(
                labelText: 'Special instructions (optional)',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _priority,
              decoration: const InputDecoration(labelText: 'Priority'),
              items: const [
                DropdownMenuItem(value: 'standard', child: Text('Standard')),
                DropdownMenuItem(value: 'high', child: Text('High')),
                DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
              ],
              onChanged: (value) =>
                  setState(() => _priority = value ?? 'standard'),
            ),
            for (final entry in [
              (_latController, 'Destination latitude', 90.0),
              (_lngController, 'Destination longitude', 180.0)
            ])
              TextFormField(
                  controller: entry.$1,
                  decoration: InputDecoration(labelText: entry.$2),
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: true),
                  validator: (v) {
                    final n = double.tryParse(v ?? '');
                    return n == null || !n.isFinite || n.abs() > entry.$3
                        ? 'Enter a valid coordinate'
                        : null;
                  }),
            const SizedBox(height: 20),
            Text(
              'Assignment',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (widget.isLoadingDrivers)
              const Center(
                child: CircularProgressIndicator(key: Key('driver-loading')),
              )
            else if (availableDrivers.isEmpty)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.person_off_outlined),
                  title: Text('No on-shift drivers available'),
                  subtitle: Text(
                    'Ask an administrator to provision an eligible driver.',
                  ),
                ),
              )
            else
              DropdownButtonFormField<String>(
                key: const Key('driver-picker'),
                initialValue: _driverId,
                decoration: const InputDecoration(
                  labelText: 'Assign driver (Firebase UID)',
                ),
                items: availableDrivers
                    .map(
                      (driver) => DropdownMenuItem(
                        value: driver.id,
                        child: Text(driver.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _driverId = value),
                validator: (value) =>
                    value == null ? 'Driver assignment is required' : null,
              ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('create-delivery-button'),
              onPressed: widget.isLoadingDrivers ||
                      availableDrivers.isEmpty ||
                      _isSubmitting
                  ? null
                  : _saveDelivery,
              icon: _isSubmitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_isSubmitting ? 'Saving...' : 'Create and assign'),
            ),
          ],
        ),
      ),
    );
  }
}
