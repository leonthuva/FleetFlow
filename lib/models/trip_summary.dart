import 'trip.dart';

/// Aggregate figures for a set of trips (history headers and reports).
class TripSummary {
  final int tripCount;
  final int completedCount;
  final double totalDistanceKm;
  final Duration totalDuration;

  const TripSummary({
    required this.tripCount,
    required this.completedCount,
    required this.totalDistanceKm,
    required this.totalDuration,
  });

  static const TripSummary empty = TripSummary(
    tripCount: 0,
    completedCount: 0,
    totalDistanceKm: 0,
    totalDuration: Duration.zero,
  );

  double get averageDistanceKm => tripCount == 0 ? 0 : totalDistanceKm / tripCount;

  factory TripSummary.fromTrips(Iterable<Trip> trips, {DateTime? now}) {
    var count = 0;
    var completed = 0;
    var distance = 0.0;
    var duration = Duration.zero;
    for (final trip in trips) {
      count++;
      if (trip.isCompleted) completed++;
      distance += trip.distanceKm;
      duration += trip.duration(now: now);
    }
    return TripSummary(
      tripCount: count,
      completedCount: completed,
      totalDistanceKm: distance,
      totalDuration: duration,
    );
  }
}
