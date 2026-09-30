import 'package:flutter/material.dart';
import '../../models/delivery.dart';
import '../../providers/driver_provider.dart';
import 'delivery_detail_screen.dart';

class AssignedJobsScreen extends StatefulWidget {
  final DriverProvider driverProvider;

  const AssignedJobsScreen({
    super.key,
    required this.driverProvider,
  });

  @override
  State<AssignedJobsScreen> createState() => _AssignedJobsScreenState();
}

class _AssignedJobsScreenState extends State<AssignedJobsScreen> {
  String _selectedFilter = 'all'; // 'all', 'active', 'pending', 'completed'
  String _searchQuery = '';

  List<Delivery> _filterDeliveries(List<Delivery> all) {
    return all.where((d) {
      // Filter tab check
      if (_selectedFilter == 'active' && !d.isActive) return false;
      if (_selectedFilter == 'pending' && !d.isAssigned) return false;
      if (_selectedFilter == 'completed' && !d.isCompleted) return false;

      // Search query check
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesRecipient = d.recipientName.toLowerCase().contains(query);
        final matchesAddress = d.address.toLowerCase().contains(query);
        final matchesId = d.id.toLowerCase().contains(query);
        return matchesRecipient || matchesAddress || matchesId;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.driverProvider,
      builder: (context, _) {
        final filteredList = _filterDeliveries(widget.driverProvider.deliveries);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Assigned Jobs'),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by ID, recipient, or address...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim();
                    });
                  },
                ),
              ),
            ),
          ),
          body: Column(
            children: [
              // Status Filter Tabs
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _buildFilterChip('all', 'All (${widget.driverProvider.totalAssigned})'),
                    const SizedBox(width: 8),
                    _buildFilterChip('active', 'Active (${widget.driverProvider.inProgressCount})'),
                    const SizedBox(width: 8),
                    _buildFilterChip('pending', 'Pending (${widget.driverProvider.pendingCount})'),
                    const SizedBox(width: 8),
                    _buildFilterChip('completed', 'Completed (${widget.driverProvider.completedCount})'),
                  ],
                ),
              ),

              // Deliveries List
              Expanded(
                child: filteredList.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: filteredList.length,
                        itemBuilder: (context, index) {
                          final delivery = filteredList[index];
                          return _buildDeliveryCard(context, delivery);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _selectedFilter = key;
        });
      },
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      labelStyle: TextStyle(
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Theme.of(context).colorScheme.onPrimaryContainer : null,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No Deliveries Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No jobs match the current filter or search criteria.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryCard(BuildContext context, Delivery delivery) {
    final statusColor = _getStatusColor(delivery.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: delivery.isInTransit || delivery.isArrived
              ? Colors.deepOrange.shade300
              : Colors.grey.shade200,
          width: delivery.isInTransit || delivery.isArrived ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DeliveryDetailScreen(
                deliveryId: delivery.id,
                driverProvider: widget.driverProvider,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: ID + Priority badge + Status chip
              Row(
                children: [
                  Text(
                    delivery.id,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(width: 8),
                  if (delivery.priority == 'urgent')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'URGENT',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade800,
                        ),
                      ),
                    ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withOpacity(0.4)),
                    ),
                    child: Text(
                      delivery.statusDisplayName,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Recipient Name
              Text(
                delivery.recipientName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),

              // Destination Address
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.place_outlined, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      delivery.address,
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Package description
              Row(
                children: [
                  Icon(Icons.inventory_2_outlined, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      delivery.packageDescription,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),

              // Action button row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Step ${delivery.statusStepIndex + 1} of 5',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DeliveryDetailScreen(
                            deliveryId: delivery.id,
                            driverProvider: widget.driverProvider,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('View Details & Flow'),
                  ),
                ],
              ),
            ],
          ),
        ),
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
      default:
        return Colors.grey.shade700;
    }
  }
}
