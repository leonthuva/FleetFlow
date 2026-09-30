import 'package:flutter/material.dart';
import '../../models/delivery.dart';
import '../../providers/auth_provider.dart';
import '../../providers/driver_provider.dart';
import '../../widgets/driver/safety_telematics_insertion_point.dart';
import 'assigned_jobs_screen.dart';
import 'delivery_detail_screen.dart';
import 'shift_summary_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  final AuthProvider? authProvider;
  final DriverProvider? driverProvider;

  const DriverHomeScreen({
    super.key,
    this.authProvider,
    this.driverProvider,
  });

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  late final DriverProvider _driverProvider;

  @override
  void initState() {
    super.initState();
    _driverProvider = widget.driverProvider ?? DriverProvider();
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = widget.authProvider?.currentUser;

    return ListenableBuilder(
      listenable: _driverProvider,
      builder: (context, _) {
        final isShiftActive = _driverProvider.isShiftActive;
        final activeDelivery = _driverProvider.activeDelivery;
        final vehicle = _driverProvider.activeVehicle;

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.displayName ?? 'Driver Portal',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${vehicle.model} (${vehicle.licensePlate})',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isShiftActive ? Colors.green.shade50 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isShiftActive ? Colors.green.shade600 : Colors.grey.shade500,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isShiftActive ? Colors.green : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isShiftActive ? 'ON DUTY' : 'OFF DUTY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isShiftActive ? Colors.green.shade800 : Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Sign Out',
                onPressed: () async {
                  if (widget.authProvider != null) {
                    await widget.authProvider!.signOut();
                  }
                  if (context.mounted) {
                    Navigator.of(context).pushReplacementNamed('/login');
                  }
                },
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              await Future.delayed(const Duration(milliseconds: 300));
              setState(() {});
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Shift Status Card
                  _buildShiftControlCard(context, isShiftActive),
                  const SizedBox(height: 12),

                  // Telematics Safety Banner (Member 3 & 5 insertion point)
                  const SafetyBannerWidget(safetyScore: 98, isSafe: true),
                  const SizedBox(height: 16),

                  // Active Delivery Hero Section
                  if (activeDelivery != null) ...[
                    _buildActiveDeliveryHero(context, activeDelivery),
                    const SizedBox(height: 16),
                  ],

                  // Shift Metrics Overview
                  _buildMetricsRow(context),
                  const SizedBox(height: 20),

                  // Quick Action Navigation Cards
                  _buildQuickActionCards(context),
                  const SizedBox(height: 20),

                  // Recent Assigned Deliveries Preview Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Assigned Jobs Today',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AssignedJobsScreen(
                                driverProvider: _driverProvider,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.arrow_forward, size: 16),
                        label: const Text('View All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Mini preview of assigned jobs
                  ..._driverProvider.deliveries.take(3).map((delivery) {
                    return _buildJobMiniCard(context, delivery);
                  }),
                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AssignedJobsScreen(
                    driverProvider: _driverProvider,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.local_shipping),
            label: Text('Jobs (${_driverProvider.totalAssigned})'),
          ),
        );
      },
    );
  }

  Widget _buildShiftControlCard(BuildContext context, bool isShiftActive) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isShiftActive ? Colors.green.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isShiftActive ? Icons.schedule : Icons.timer_off_outlined,
                color: isShiftActive ? Colors.green.shade700 : Colors.grey.shade600,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isShiftActive ? 'Active Shift in Progress' : 'Currently Off Duty',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isShiftActive
                        ? 'Elapsed: ${_formatDuration(_driverProvider.shiftDuration)}'
                        : 'Tap below to start your route.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
            FilledButton.tonal(
              onPressed: () {
                if (isShiftActive) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ShiftSummaryScreen(
                        driverProvider: _driverProvider,
                      ),
                    ),
                  );
                } else {
                  _driverProvider.startShift();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Shift started. Telematics & GPS ready.')),
                  );
                }
              },
              child: Text(isShiftActive ? 'Shift Summary' : 'Start Shift'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveDeliveryHero(BuildContext context, Delivery delivery) {
    final theme = Theme.of(context);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.3), width: 1.5),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary.withOpacity(0.08),
              Colors.white,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.shade700,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'ACTIVE JOB',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  delivery.id,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const Spacer(),
                _buildStatusChip(delivery.status),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              delivery.recipientName,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    delivery.address,
                    style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.inventory_2_outlined, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    delivery.packageDescription,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DeliveryDetailScreen(
                      deliveryId: delivery.id,
                      driverProvider: _driverProvider,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.navigation_outlined),
              label: Text('Continue Delivery (${delivery.statusDisplayName})'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            context,
            title: 'Assigned',
            value: '${_driverProvider.totalAssigned}',
            icon: Icons.assignment_outlined,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricTile(
            context,
            title: 'In Progress',
            value: '${_driverProvider.inProgressCount}',
            icon: Icons.local_shipping_outlined,
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricTile(
            context,
            title: 'Completed',
            value: '${_driverProvider.completedCount}',
            icon: Icons.check_circle_outline,
            color: Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCards(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AssignedJobsScreen(
                    driverProvider: _driverProvider,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.list_alt),
            label: const Text('All Jobs'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ShiftSummaryScreen(
                    driverProvider: _driverProvider,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.analytics_outlined),
            label: const Text('Summary'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildJobMiniCard(BuildContext context, Delivery delivery) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DeliveryDetailScreen(
                deliveryId: delivery.id,
                driverProvider: _driverProvider,
              ),
            ),
          );
        },
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(delivery.status).withOpacity(0.15),
          child: Icon(_getStatusIcon(delivery.status), color: _getStatusColor(delivery.status), size: 20),
        ),
        title: Text(
          delivery.recipientName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          delivery.address,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildStatusChip(delivery.status),
            const SizedBox(height: 2),
            Text(
              delivery.id,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        DeliveryStatus.displayName(status),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case DeliveryStatus.assigned:
        return Colors.blue.shade700;
      case DeliveryStatus.pickedUp:
        return Colors.amber.shade800;
      case DeliveryStatus.inTransit:
        return Colors.deepOrange;
      case DeliveryStatus.arrived:
        return Colors.purple;
      case DeliveryStatus.completed:
        return Colors.green.shade700;
      case DeliveryStatus.cancelled:
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case DeliveryStatus.assigned:
        return Icons.assignment;
      case DeliveryStatus.pickedUp:
        return Icons.inventory;
      case DeliveryStatus.inTransit:
        return Icons.directions_car;
      case DeliveryStatus.arrived:
        return Icons.place;
      case DeliveryStatus.completed:
        return Icons.check_circle;
      default:
        return Icons.local_shipping;
    }
  }
}
