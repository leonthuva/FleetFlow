import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../customer/customer_tracking_screen.dart';
import '../notifications/notifications_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  final AuthProvider authProvider;

  const AdminDashboardScreen({
    super.key,
    required this.authProvider,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentIndex = 0;
  final NotificationProvider _notificationProvider = NotificationProvider();

  final List<Map<String, String>> _sampleDrivers = [
    {'name': 'Marcus Vance', 'email': 'marcus@fleetflow.com', 'status': 'On Shift', 'vehicle': 'Ford Transit (FL-101)'},
    {'name': 'Sara Connor', 'email': 'sara@fleetflow.com', 'status': 'On Shift', 'vehicle': 'Mercedes Sprinter (FL-204)'},
    {'name': 'Liam Chen', 'email': 'liam@fleetflow.com', 'status': 'Off Duty', 'vehicle': 'Unassigned'},
    {'name': 'Elena Rostova', 'email': 'elena@fleetflow.com', 'status': 'Off Duty', 'vehicle': 'Unassigned'},
  ];

  final List<Map<String, String>> _sampleVehicles = [
    {'model': 'Ford Transit High Roof', 'plate': 'FL-101', 'status': 'in-use'},
    {'model': 'Mercedes-Benz Sprinter', 'plate': 'FL-204', 'status': 'in-use'},
    {'model': 'Ram ProMaster 2500', 'plate': 'FL-309', 'status': 'available'},
    {'model': 'Chevrolet Express 3500', 'plate': 'FL-412', 'status': 'available'},
    {'model': 'Isuzu NPR Box Truck', 'plate': 'FL-520', 'status': 'maintenance'},
  ];

  void _showAddDriverDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String selectedVehicle = 'Ford Transit (FL-101)';
    String selectedStatus = 'On Shift';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Driver'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Driver Full Name',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedVehicle,
                decoration: const InputDecoration(
                  labelText: 'Assigned Vehicle',
                  prefixIcon: Icon(Icons.directions_car),
                ),
                items: [
                  ..._sampleVehicles.map((v) => DropdownMenuItem(
                        value: '${v['model']} (${v['plate']})',
                        child: Text('${v['model']} (${v['plate']})'),
                      )),
                  const DropdownMenuItem(
                    value: 'Unassigned',
                    child: Text('Unassigned'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) selectedVehicle = val;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Duty Status',
                  prefixIcon: Icon(Icons.schedule),
                ),
                items: const [
                  DropdownMenuItem(value: 'On Shift', child: Text('On Shift')),
                  DropdownMenuItem(value: 'Off Duty', child: Text('Off Duty')),
                ],
                onChanged: (val) {
                  if (val != null) selectedStatus = val;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty || emailCtrl.text.trim().isEmpty) {
                return;
              }
              setState(() {
                _sampleDrivers.add({
                  'name': nameCtrl.text.trim(),
                  'email': emailCtrl.text.trim(),
                  'vehicle': selectedVehicle,
                  'status': selectedStatus,
                });
              });
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Driver "${nameCtrl.text.trim()}" added successfully.'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Add Driver'),
          ),
        ],
      ),
    );
  }

  void _showAddVehicleDialog() {
    final modelCtrl = TextEditingController();
    final plateCtrl = TextEditingController();
    String selectedStatus = 'available';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Fleet Vehicle'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: modelCtrl,
                decoration: const InputDecoration(
                  labelText: 'Vehicle Model (e.g. Ford Transit)',
                  prefixIcon: Icon(Icons.directions_car),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: plateCtrl,
                decoration: const InputDecoration(
                  labelText: 'License Plate (e.g. FL-801)',
                  prefixIcon: Icon(Icons.badge),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  prefixIcon: Icon(Icons.flag),
                ),
                items: const [
                  DropdownMenuItem(value: 'available', child: Text('Available')),
                  DropdownMenuItem(value: 'in-use', child: Text('In Use')),
                  DropdownMenuItem(value: 'maintenance', child: Text('Maintenance')),
                ],
                onChanged: (val) {
                  if (val != null) selectedStatus = val;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (modelCtrl.text.trim().isEmpty || plateCtrl.text.trim().isEmpty) {
                return;
              }
              setState(() {
                _sampleVehicles.add({
                  'model': modelCtrl.text.trim(),
                  'plate': plateCtrl.text.trim().toUpperCase(),
                  'status': selectedStatus,
                });
              });
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Vehicle "${plateCtrl.text.trim()}" added to inventory.'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Add Vehicle'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.authProvider,
      builder: (context, _) {
        final user = widget.authProvider.currentUser;

        // Role boundary guard: Verify manager permissions
        if (user == null || !user.isManager) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Access Denied'),
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_person_outlined, size: 72, color: Colors.red.shade700),
                    const SizedBox(height: 16),
                    Text(
                      'Manager Authorization Required',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Current account role "${user?.role ?? 'unauthenticated'}" cannot access the Manager portal.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () {
                        if (user != null) {
                          Navigator.of(context).pushReplacementNamed('/driver-home');
                        } else {
                          Navigator.of(context).pushReplacementNamed('/login');
                        }
                      },
                      icon: const Icon(Icons.arrow_back),
                      label: Text(user != null ? 'Go to Driver Home' : 'Go to Login'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(_getTitleForIndex(_currentIndex)),
            actions: [
              Chip(
                avatar: const Icon(Icons.shield_outlined, size: 16),
                label: Text(
                  user.role.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
                backgroundColor: Colors.deepOrange.shade50,
                side: BorderSide(color: Colors.deepOrange.shade200),
              ),
              ListenableBuilder(
                listenable: _notificationProvider,
                builder: (context, _) {
                  final unread = _notificationProvider.unreadCount;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined),
                        tooltip: 'Notifications',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => NotificationsScreen(
                                notificationProvider: _notificationProvider,
                              ),
                            ),
                          );
                        },
                      ),
                      if (unread > 0)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$unread',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Sign Out',
                onPressed: () async {
                  await widget.authProvider.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacementNamed('/login');
                  }
                },
              ),
            ],
          ),
          body: IndexedStack(
            index: _currentIndex,
            children: [
              _buildOverviewTab(context, user),
              _buildDriversTab(context),
              _buildVehiclesTab(context),
              _buildDeliveriesTab(context),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.people_alt_outlined),
                selectedIcon: Icon(Icons.people_alt),
                label: 'Drivers',
              ),
              NavigationDestination(
                icon: Icon(Icons.directions_car_outlined),
                selectedIcon: Icon(Icons.directions_car),
                label: 'Vehicles',
              ),
              NavigationDestination(
                icon: Icon(Icons.local_shipping_outlined),
                selectedIcon: Icon(Icons.local_shipping),
                label: 'Deliveries',
              ),
            ],
          ),
        );
      },
    );
  }

  String _getTitleForIndex(int index) {
    switch (index) {
      case 0:
        return 'FleetFlow Operations';
      case 1:
        return 'Driver Roster';
      case 2:
        return 'Vehicle Inventory';
      case 3:
        return 'Delivery Dispatch';
      default:
        return 'Operations';
    }
  }

  Widget _buildOverviewTab(BuildContext context, AppUser user) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Welcome Header
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: const Icon(Icons.person, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        'Role: ${user.role} • ${user.email}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        Text(
          'Operational Highlights',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),

        // Stat Grid
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: [
            _buildStatCard(
              context,
              title: 'Active Drivers',
              value: '6',
              subtitle: '2 on active shift',
              icon: Icons.person_pin_circle_outlined,
              color: Colors.blue,
              onTap: () => setState(() => _currentIndex = 1),
            ),
            _buildStatCard(
              context,
              title: 'Fleet Vehicles',
              value: '10',
              subtitle: '8 available',
              icon: Icons.local_shipping_outlined,
              color: Colors.green,
              onTap: () => setState(() => _currentIndex = 2),
            ),
            _buildStatCard(
              context,
              title: 'Deliveries',
              value: '18',
              subtitle: '5 pending dispatch',
              icon: Icons.inventory_2_outlined,
              color: Colors.deepOrange,
              onTap: () => setState(() => _currentIndex = 3),
            ),
            _buildStatCard(
              context,
              title: 'Fleet Health',
              value: '98%',
              subtitle: 'All systems operational',
              icon: Icons.verified_user_outlined,
              color: Colors.purple,
              onTap: null,
            ),
          ],
        ),
        const SizedBox(height: 20),

        Text(
          'Quick Operations',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),

        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('New Delivery'),
              onPressed: () => setState(() => _currentIndex = 3),
            ),
            ActionChip(
              avatar: const Icon(Icons.person_add_outlined, size: 18),
              label: const Text('Add Driver'),
              onPressed: () => setState(() => _currentIndex = 1),
            ),
            ActionChip(
              avatar: const Icon(Icons.directions_car_filled_outlined, size: 18),
              label: const Text('Register Vehicle'),
              onPressed: () => setState(() => _currentIndex = 2),
            ),
            ActionChip(
              avatar: const Icon(Icons.qr_code_scanner, size: 18),
              label: const Text('Customer Tracking View'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const CustomerTrackingScreen(),
                  ),
                );
              },
            ),
            ActionChip(
              avatar: const Icon(Icons.notifications_active_outlined, size: 18),
              label: const Text('Notification Feed'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => NotificationsScreen(
                      notificationProvider: _notificationProvider,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  Icon(icon, color: color, size: 20),
                ],
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDriversTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Registered Drivers (${_sampleDrivers.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            FilledButton.tonalIcon(
              onPressed: _showAddDriverDialog,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Driver'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._sampleDrivers.map((driver) {
          final isOnShift = driver['status'] == 'On Shift';
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isOnShift ? Colors.green.shade100 : Colors.grey.shade200,
                child: Icon(
                  Icons.person,
                  color: isOnShift ? Colors.green.shade800 : Colors.grey.shade600,
                ),
              ),
              title: Text(driver['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${driver['email']} • Vehicle: ${driver['vehicle']}'),
              trailing: Chip(
                label: Text(
                  driver['status']!,
                  style: TextStyle(
                    fontSize: 11,
                    color: isOnShift ? Colors.green.shade900 : Colors.grey.shade800,
                  ),
                ),
                backgroundColor: isOnShift ? Colors.green.shade50 : Colors.grey.shade100,
                side: BorderSide(
                  color: isOnShift ? Colors.green.shade300 : Colors.grey.shade300,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildVehiclesTab(BuildContext context) {
    Color getStatusColor(String status) {
      switch (status) {
        case 'available':
          return Colors.green;
        case 'in-use':
          return Colors.blue;
        case 'maintenance':
          return Colors.orange;
        default:
          return Colors.grey;
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Fleet Inventory (${_sampleVehicles.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            FilledButton.tonalIcon(
              onPressed: _showAddVehicleDialog,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Vehicle'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._sampleVehicles.map((vehicle) {
          final color = getStatusColor(vehicle['status']!);
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.directions_car, color: color),
              ),
              title: Text(vehicle['model']!, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('License: ${vehicle['plate']}'),
              trailing: Chip(
                label: Text(
                  vehicle['status']!,
                  style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
                ),
                backgroundColor: color.withAlpha(25),
                side: BorderSide(color: color.withAlpha(100)),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDeliveriesTab(BuildContext context) {
    // Agreed schema status values: 'assigned'|'en-route'|'delivered'
    final sampleDeliveries = [
      {'id': 'DEL-8801', 'address': '742 Evergreen Terrace, Springfield', 'driver': 'Marcus Vance', 'status': 'en-route'},
      {'id': 'DEL-8802', 'address': '100 Main St, Suite 400, Metro City', 'driver': 'Sara Connor', 'status': 'en-route'},
      {'id': 'DEL-8803', 'address': '45 West Elm Avenue, Riverdale', 'driver': 'Unassigned', 'status': 'assigned'},
      {'id': 'DEL-8804', 'address': '12 Harbor Bay Road, Dock 4', 'driver': 'Liam Chen', 'status': 'delivered'},
    ];

    Color getStatusColor(String status) {
      switch (status) {
        case 'delivered':
          return Colors.teal;
        case 'en-route':
          return Colors.deepOrange;
        case 'assigned':
          return Colors.indigo;
        default:
          return Colors.grey;
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Deliveries Overview (${sampleDeliveries.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            FilledButton.tonalIcon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Create Delivery form — to be wired with Task 15')),
                );
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('New Delivery'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...sampleDeliveries.map((delivery) {
          final color = getStatusColor(delivery['status']!);
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        delivery['id']!,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Chip(
                        label: Text(
                          delivery['status']!,
                          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: color.withAlpha(25),
                        side: BorderSide(color: color.withAlpha(100)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          delivery['address']!,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        'Assigned: ${delivery['driver']}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => CustomerTrackingScreen(
                                deliveryId: delivery['id'],
                              ),
                            ),
                          );
                        },
                        icon: Icon(
                          delivery['status'] == 'delivered' ? Icons.verified_outlined : Icons.track_changes,
                          size: 16,
                        ),
                        label: Text(
                          delivery['status'] == 'delivered' ? 'View Proof (POD)' : 'Track',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
