import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleet_flow/main.dart';
import 'package:fleet_flow/models/user.dart';
import 'package:fleet_flow/providers/auth_provider.dart';
import 'package:fleet_flow/providers/history_provider.dart';
import 'package:fleet_flow/screens/history/manager_history_tab.dart';
import 'package:fleet_flow/services/trip_service.dart';

void main() {
  final now = DateTime.now();

  const manager = AppUser(id: 'm1', email: 'm@x.com', displayName: 'Mia Manager', role: UserRole.admin);

  HistoryProvider buildProvider() => HistoryProvider(service: TripService(now: now));

  void tallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<HistoryProvider> pumpTab(WidgetTester tester) async {
    tallViewport(tester);
    final provider = buildProvider();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ManagerHistoryTab(historyProvider: provider, user: manager)),
    ));
    await tester.pumpAndSettle();
    return provider;
  }

  Finder tripCard(String id) => find.byKey(ValueKey('trip-card-$id'));

  group('ManagerHistoryTab', () {
    testWidgets('shows fleet totals, per-driver and per-vehicle reports and all trips', (tester) async {
      await pumpTab(tester);

      expect(find.text('232.4 km'), findsOneWidget);
      expect(find.text('By driver'), findsOneWidget);
      expect(find.text('By vehicle'), findsOneWidget);
      expect(find.byKey(const ValueKey('report-driver-Marcus Vance')), findsOneWidget);
      expect(find.byKey(const ValueKey('report-vehicle-FL-204')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('report-driver-Marcus Vance')),
          matching: find.text('127.3 km'),
        ),
        findsOneWidget,
      );
      for (final id in ['TRP-1001', 'TRP-1002', 'TRP-1003', 'TRP-1004', 'TRP-1005', 'TRP-1006']) {
        expect(tripCard(id), findsOneWidget);
      }
    });

    testWidgets('driver dropdown narrows trips and Clear resets', (tester) async {
      await pumpTab(tester);
      expect(find.byKey(const ValueKey('clear-filters-button')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('driver-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DropdownMenuItem<String?>, 'Sara Connor').last);
      await tester.pumpAndSettle();

      expect(tripCard('TRP-1002'), findsOneWidget);
      expect(tripCard('TRP-1005'), findsOneWidget);
      expect(tripCard('TRP-1001'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('clear-filters-button')));
      await tester.pumpAndSettle();
      expect(tripCard('TRP-1001'), findsOneWidget);
      expect(find.byKey(const ValueKey('clear-filters-button')), findsNothing);
    });

    testWidgets('vehicle dropdown narrows trips', (tester) async {
      await pumpTab(tester);

      await tester.tap(find.byKey(const ValueKey('vehicle-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DropdownMenuItem<String?>, 'FL-412').last);
      await tester.pumpAndSettle();

      expect(tripCard('TRP-1004'), findsOneWidget);
      expect(tripCard('TRP-1001'), findsNothing);
    });

    testWidgets('tapping a report row filters to that driver', (tester) async {
      final provider = await pumpTab(tester);

      await tester.tap(find.byKey(const ValueKey('report-driver-Liam Chen')));
      await tester.pumpAndSettle();

      expect(provider.driverFilter, 'Liam Chen');
      expect(tripCard('TRP-1004'), findsOneWidget);
      expect(tripCard('TRP-1001'), findsNothing);
    });

    testWidgets('status chips and the date range button are present and the chips filter', (tester) async {
      await pumpTab(tester);

      expect(find.byKey(const ValueKey('date-range-button')), findsOneWidget);
      expect(find.text('Any date'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('status-filter-cancelled')));
      await tester.pumpAndSettle();
      expect(tripCard('TRP-1005'), findsOneWidget);
      expect(tripCard('TRP-1001'), findsNothing);
    });

    testWidgets('date range label reflects the provider range with an inclusive last day', (tester) async {
      final provider = await pumpTab(tester);

      await provider.setDateRange(DateTime(2020, 1, 1), DateTime(2020, 1, 9));
      await tester.pumpAndSettle();

      expect(find.text('Jan 1 – Jan 8'), findsOneWidget);
      expect(find.text('No trips found'), findsOneWidget);
    });
  });

  group('AdminDashboardScreen History tab', () {
    testWidgets('manager reaches fleet history from the History tab', (tester) async {
      tallViewport(tester);
      final auth = AuthProvider()..setUser(manager);

      await tester.pumpWidget(FleetFlowApp(
        authProvider: auth,
        historyProvider: buildProvider(),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(NavigationDestination, 'History'));
      await tester.pumpAndSettle();

      expect(find.text('Trip History & Reports'), findsOneWidget);
      expect(tripCard('TRP-1001'), findsOneWidget);
      expect(find.text('By driver'), findsOneWidget);
    });
  });
}
