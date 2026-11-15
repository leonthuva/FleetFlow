import 'package:flutter/material.dart';

class DemoDriver {
  final String id;
  final String name;
  final String status;

  const DemoDriver({
    required this.id,
    required this.name,
    required this.status,
  });
}

class CreateDeliveryScreen extends StatefulWidget {
  final List<DemoDriver> drivers;
  final bool isLoadingDrivers;

  const CreateDeliveryScreen({
    super.key,
    required this.drivers,
    this.isLoadingDrivers = false,
  });

  @override
  State<CreateDeliveryScreen> createState() => _CreateDeliveryScreenState();
}

class _CreateDeliveryScreenState extends State<CreateDeliveryScreen> {
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
  bool _showNotSavedMessage = false;

  @override
  void dispose() {
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

  Future<void> _previewDelivery() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _showNotSavedMessage = false;
    });
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _showNotSavedMessage = true;
    });
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
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.science_outlined),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Demo preview only. Driver options are fixtures and this form does not save or assign a delivery.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_showNotSavedMessage) ...[
              const SizedBox(height: 12),
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Delivery was not saved'),
                  subtitle: Text(
                    'Backend creation and assignment are unavailable until the shared contract is approved.',
                  ),
                ),
              ),
            ],
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
            const SizedBox(height: 20),
            Text(
              'Assignment (demo fixtures)',
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
                  title: Text('No on-shift demo drivers available'),
                  subtitle: Text(
                    'A delivery cannot be preview-assigned right now.',
                  ),
                ),
              )
            else
              DropdownButtonFormField<String>(
                key: const Key('driver-picker'),
                initialValue: _driverId,
                decoration: const InputDecoration(
                  labelText: 'Assign demo driver',
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
              key: const Key('preview-delivery-button'),
              onPressed:
                  widget.isLoadingDrivers ||
                      availableDrivers.isEmpty ||
                      _isSubmitting
                  ? null
                  : _previewDelivery,
              icon: _isSubmitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.visibility_outlined),
              label: Text(
                _isSubmitting ? 'Checking preview…' : 'Preview assignment',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
