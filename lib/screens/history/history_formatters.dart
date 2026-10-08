import 'package:flutter/material.dart';
import '../../models/trip.dart';

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String formatTripDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  return hours == 0 ? '${minutes}m' : '${hours}h ${minutes}m';
}

String formatTripDistance(double km) => '${km.toStringAsFixed(1)} km';

/// e.g. "Oct 8, 14:05"
String formatTripDateTime(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '${_months[time.month - 1]} ${time.day}, $hour:$minute';
}

/// e.g. "Oct 8"
String formatTripDate(DateTime time) => '${_months[time.month - 1]} ${time.day}';

String formatCoordinates(double? lat, double? lng) {
  if (lat == null || lng == null) return 'Not recorded';
  return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
}

Color tripStatusColor(String status) {
  switch (status) {
    case TripStatus.active:
      return Colors.blue.shade700;
    case TripStatus.completed:
      return Colors.green.shade700;
    case TripStatus.cancelled:
      return Colors.red.shade700;
    default:
      return Colors.blueGrey;
  }
}

class TripStatusChip extends StatelessWidget {
  final String status;

  const TripStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = tripStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        TripStatus.getLabel(status),
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
