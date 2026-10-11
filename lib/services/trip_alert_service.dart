import '../models/app_notification.dart';
import '../models/trip.dart';
import '../screens/history/history_formatters.dart';
import 'notification_service.dart';

/// Sends a notification through the agreed `sendNotification` contract.
typedef AlertSender = Future<void> Function({
  required String recipientId,
  required String message,
  required String type,
  String? title,
  Map<String, dynamic>? metadata,
});

/// Trip-related push alerts for managers: trip completed, and trips that
/// have been running longer than [longTripThreshold].
///
/// Each alert is sent at most once per trip.
class TripAlertService {
  TripAlertService({
    AlertSender? sender,
    this.longTripThreshold = const Duration(hours: 4),
  }) : _send = sender ?? _sendViaNotificationService;

  static const String managerRecipient = 'all_managers';

  final Duration longTripThreshold;
  final AlertSender _send;
  final Set<String> _sent = {};

  static Future<void> _sendViaNotificationService({
    required String recipientId,
    required String message,
    required String type,
    String? title,
    Map<String, dynamic>? metadata,
  }) async {
    await NotificationService().sendNotification(
      recipientId: recipientId,
      message: message,
      type: type,
      title: title,
      metadata: metadata,
    );
  }

  /// Alerts managers that [trip] finished. Returns false if it was already
  /// announced or the trip is not completed.
  Future<bool> notifyTripCompleted(Trip trip) async {
    final key = 'completed:${trip.id}';
    if (!trip.isCompleted || !_sent.add(key)) return false;

    await _sendOnce(
      key,
      recipientId: managerRecipient,
      title: 'Trip Completed',
      message: '${trip.driverId} completed trip ${trip.id} with ${trip.vehicleId}: '
          '${formatTripDistance(trip.distanceKm)} in ${formatTripDuration(trip.duration())}.',
      type: NotificationType.statusChange,
      metadata: {'tripId': trip.id, 'driverId': trip.driverId, 'vehicleId': trip.vehicleId},
    );
    return true;
  }

  /// Alerts managers that an active [trip] has run longer than the threshold.
  /// Returns false if it was already flagged or is within the threshold.
  Future<bool> notifyLongTrip(Trip trip, {DateTime? now}) async {
    final elapsed = trip.duration(now: now);
    final key = 'long:${trip.id}';
    if (!trip.isActive || elapsed < longTripThreshold || !_sent.add(key)) {
      return false;
    }

    await _sendOnce(
      key,
      recipientId: managerRecipient,
      title: 'Long-Running Trip',
      message: '${trip.driverId} has been on trip ${trip.id} for ${formatTripDuration(elapsed)} '
          '(limit ${formatTripDuration(longTripThreshold)}). Check in with the driver.',
      type: NotificationType.safetyAlert,
      metadata: {'tripId': trip.id, 'driverId': trip.driverId, 'vehicleId': trip.vehicleId},
    );
    return true;
  }

  /// Sends the alert; if sending fails the trip is un-marked so a later call can retry.
  Future<void> _sendOnce(
    String key, {
    required String recipientId,
    required String message,
    required String type,
    String? title,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _send(
        recipientId: recipientId,
        message: message,
        type: type,
        title: title,
        metadata: metadata,
      );
    } catch (_) {
      _sent.remove(key);
      rethrow;
    }
  }

  /// Flags every long-running active trip in [trips]. Returns how many alerts were sent.
  Future<int> checkLongTrips(Iterable<Trip> trips, {DateTime? now}) async {
    var sent = 0;
    for (final trip in trips) {
      if (await notifyLongTrip(trip, now: now)) sent++;
    }
    return sent;
  }
}
