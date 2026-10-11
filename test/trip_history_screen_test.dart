import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleet_flow/models/trip.dart';
import 'package:fleet_flow/models/user.dart';
import 'package:fleet_flow/providers/auth_provider.dart';
import 'package:fleet_flow/providers/history_provider.dart';
import 'package:fleet_flow/screens/driver/driver_home_screen.dart';
import 'package:fleet_flow/screens/history/trip_detail_screen.dart';
import 'package:fleet_flow/screens/history/trip_history_screen.dart';
import 'package:fleet_flow/services/trip_service.dart';

void main() {
  final now = DateTime.now();

  const manager = AppUser(id: 'm1', email: 'm@x.com', displayName: 'Mia Manager', role: UserRole.admin);
  const driver = AppUser(id: 'd1', email: 'd@x.com', displayName: 'Marcus Vance', role: UserRole.driver);

  HistoryProvider buildProvider() => HistoryProvider(service: TripService(now: now));

  Future<void> pump(WidgetTester tester, HistoryProvider provider, AppUser? user) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: TripHistoryScreen(historyProvider: provider, user: user)),
    );
    await tester.pumpAndSettle();
  }

  group('TripHistoryScreen', () {
    testWidgets('driver sees only their own trips and a personal title', (tester) async {
      await pump(tester, buildProvider(), driver);

      expect(find.text('My Trip History'), findsOneWidget);
      expect(find.byKey(const ValueKey('trip-card-TRP-1001')), findsOneWidget);
      expect(find.byKey(const ValueKey('trip-card-TRP-1003')), findsOneWidget);
      expect(find.byKey(const ValueKey('trip-card-TRP-1006')), findsOneWidget);
      expect(find.byKey(const ValueKey('trip-card-TRP-1002')), findsNothing);
      expect(find.byKey(const ValueKey('trip-card-TRP-1004')), findsNothing);
    });

    testWidgets('manager sees the whole fleet with driver names', (tester) async {
      await pump(tester, buildProvider(), manager);

      expect(find.text('Trip History'), findsOneWidget);
      for (final id in ['TRP-1001', 'TRP-1002', 'TRP-1003', 'TRP-1004', 'TRP-1005', 'TRP-1006']) {
        expect(find.byKey(ValueKey('trip-card-$id')), findsOneWidget);
      }
      expect(find.textContaining('Sara Connor'), findsWidgets);
    });

    testWidgets('summary header shows totals for the visible trips', (tester) async {
      await pump(tester, buildProvider(), manager);

      expect(find.text('6'), findsOneWidget); // trip count
      expect(find.text('232.4 km'), findsOneWidget);
    });

    testWidgets('status filter chips narrow the list', (tester) async {
      await pump(tester, buildProvider(), manager);

      await tester.tap(find.byKey(const ValueKey('status-filter-completed')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('trip-card-TRP-1001')), findsOneWidget);
      expect(find.byKey(const ValueKey('trip-card-TRP-1005')), findsNothing);
      expect(find.byKey(const ValueKey('trip-card-TRP-1006')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('status-filter-active')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('trip-card-TRP-1006')), findsOneWidget);
      expect(find.byKey(const ValueKey('trip-card-TRP-1001')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('status-filter-all')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('trip-card-TRP-1001')), findsOneWidget);
    });

    testWidgets('shows an empty state when nothing matches', (tester) async {
      final provider = HistoryProvider(service: TripService(seed: const []));
      await pump(tester, provider, manager);

      expect(find.text('No trips found'), findsOneWidget);
    });

    testWidgets('tapping a trip opens its detail screen', (tester) async {
      await pump(tester, buildProvider(), manager);

      await tester.tap(find.byKey(const ValueKey('trip-card-TRP-1003')));
      await tester.pumpAndSettle();

      expect(find.byType(TripDetailScreen), findsOneWidget);
      expect(find.text('72.4 km'), findsOneWidget);
      expect(find.text('Marcus Vance'), findsOneWidget);
      expect(find.text('FL-101'), findsOneWidget);
    });
  });

  group('TripDetailScreen', () {
    testWidgets('shows in-progress end time and missing coordinates gracefully', (tester) async {
      final trip = Trip(
        id: 'TRP-X',
        driverId: 'Liam Chen',
        vehicleId: 'FL-412',
        startTime: now.subtract(const Duration(hours: 1)),
        status: TripStatus.active,
        distanceKm: 5,
      );
      await tester.pumpWidget(MaterialApp(home: TripDetailScreen(trip: trip)));

      expect(find.text('In progress'), findsOneWidget);
      expect(find.text('Not recorded'), findsNWidgets(2));
      expect(find.text('In Progress'), findsOneWidget); // status chip
    });
  });

  testWidgets('driver home History button opens only that drivers own trips', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final auth = AuthProvider()..setUser(driver);
    await tester.pumpWidget(MaterialApp(
      home: DriverHomeScreen(authProvider: auth, historyProvider: buildProvider()),
    ));
    await tester.pumpAndSettle();

    final button = find.byKey(const ValueKey('driver-history-button'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.text('My Trip History'), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-card-TRP-1001')), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-card-TRP-1002')), findsNothing);
  });
}
