import '../models/trip.dart';

typedef ManagerTargetsLoader = Future<List<String>> Function();

typedef TripAlertSender = Future<void> Function({
  required List<String> recipientIds,
  required List<String> recipientRoles,
  required String audience,
  required String title,
  required String message,
  required String type,
  Map<String, dynamic>? metadata,
});

/// Formats trip alerts for the approved M5 notification service adapter.
/// A sender and target loader must be supplied; this class does not fabricate
/// manager recipients or silently claim that an alert was sent.
class TripAlertService {
  TripAlertService({
    required TripAlertSender sender,
    required ManagerTargetsLoader managerTargets,
    this.longTripThreshold = const Duration(hours: 4),
  })  : _send = sender,
        _managerTargets = managerTargets;

  final TripAlertSender _send;
  final ManagerTargetsLoader _managerTargets;
  final Duration longTripThreshold;
  final Set<String> _sent = {};

  Future<bool> notifyTripCompleted(Trip trip) async {
    if (!trip.isCompleted) return false;
    final key = 'completed:${trip.id}';
    if (!_sent.add(key)) return false;

    await _sendOnce(
      key,
      title: 'Trip Completed',
      message:
          '${trip.driverId} completed trip ${trip.id} with ${trip.vehicleId}: '
          '${_formatDistance(trip.distanceKm)} in ${_formatDuration(trip.duration())}.',
      type: 'status_change',
      trip: trip,
    );
    return true;
  }

  Future<bool> notifyLongTrip(Trip trip, {DateTime? now}) async {
    final elapsed = trip.duration(now: now);
    if (!trip.isActive || elapsed < longTripThreshold) return false;
    final key = 'long:${trip.id}';
    if (!_sent.add(key)) return false;

    await _sendOnce(
      key,
      title: 'Long-Running Trip',
      message: '${trip.driverId} has been on trip ${trip.id} for '
          '${_formatDuration(elapsed)} (limit '
          '${_formatDuration(longTripThreshold)}). Check in with the driver.',
      type: 'safety_alert',
      trip: trip,
    );
    return true;
  }

  Future<int> checkLongTrips(Iterable<Trip> trips, {DateTime? now}) async {
    var count = 0;
    for (final trip in trips) {
      if (await notifyLongTrip(trip, now: now)) count++;
    }
    return count;
  }

  Future<void> _sendOnce(
    String key, {
    required String title,
    required String message,
    required String type,
    required Trip trip,
  }) async {
    try {
      final recipients = await _managerTargets();
      if (recipients.isEmpty) {
        throw StateError('No manager notification targets are configured.');
      }
      await _send(
        recipientIds: recipients,
        recipientRoles: const ['admin', 'dispatcher'],
        audience: 'managers',
        title: title,
        message: message,
        type: type,
        metadata: {
          'tripId': trip.id,
          'driverId': trip.driverId,
          'vehicleId': trip.vehicleId,
        },
      );
    } catch (_) {
      _sent.remove(key);
      rethrow;
    }
  }

  static String _formatDistance(double km) => '${km.toStringAsFixed(1)} km';

  static String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return hours == 0 ? '${minutes}m' : '${hours}h ${minutes}m';
  }
}
