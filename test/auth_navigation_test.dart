import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleet_flow/main.dart';
import 'package:fleet_flow/models/user.dart';
import 'package:fleet_flow/providers/auth_provider.dart';
import 'package:fleet_flow/screens/admin/admin_dashboard_screen.dart';
import 'package:fleet_flow/screens/auth/login_screen.dart';

void main() {
  group('Member 1 Task 2: AppUser Role Model Tests', () {
    test('role getters return correct boolean values', () {
      const admin = AppUser(id: '1', email: 'admin@fleetflow.com', displayName: 'Admin', role: UserRole.admin);
      const dispatcher = AppUser(id: '2', email: 'dispatch@fleetflow.com', displayName: 'Dispatcher', role: UserRole.dispatcher);
      const driver = AppUser(id: '3', email: 'driver@fleetflow.com', displayName: 'Driver', role: UserRole.driver);

      expect(admin.isAdmin, isTrue);
      expect(admin.isManager, isTrue);
      expect(admin.isDriver, isFalse);

      expect(dispatcher.isAdmin, isFalse);
      expect(dispatcher.isDispatcher, isTrue);
      expect(dispatcher.isManager, isTrue);
      expect(dispatcher.isDriver, isFalse);

      expect(driver.isManager, isFalse);
      expect(driver.isDriver, isTrue);
    });

    test('fromMap and toMap preserve agreed schema fields', () {
      final map = {
        'id': 'u100',
        'email': 'ops@fleetflow.com',
        'displayName': 'Ops Lead',
        'role': 'admin',
      };

      final user = AppUser.fromMap(map);
      expect(user.id, 'u100');
      expect(user.email, 'ops@fleetflow.com');
      expect(user.displayName, 'Ops Lead');
      expect(user.role, 'admin');

      final serialized = user.toMap();
      expect(serialized['id'], 'u100');
      expect(serialized['uid'], 'u100');
      expect(serialized['email'], 'ops@fleetflow.com');
      expect(serialized['role'], 'admin');
    });
  });

  group('Member 1 Task 2: Login Validation & Screen Tests', () {
    testWidgets('LoginScreen shows validation errors for empty and invalid inputs', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final authProvider = AuthProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(authProvider: authProvider),
        ),
      );

      // Verify basic elements
      expect(find.text('FleetFlow'), findsNWidgets(2));
      expect(find.text('Sign In to Your Account'), findsOneWidget);

      // Attempt to submit empty form
      final submitButton = find.widgetWithText(FilledButton, 'Sign In as Manager');
      expect(submitButton, findsOneWidget);

      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Expect validation errors
      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);

      // Enter invalid email format
      await tester.enterText(find.byType(TextFormField).first, 'invalid-email');
      await tester.enterText(find.byType(TextFormField).last, '123'); // < 6 chars
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email address'), findsOneWidget);
      expect(find.text('Password must be at least 6 characters'), findsOneWidget);
    });
  });

  group('Member 1 Task 2: Navigation & Role Boundary Tests', () {
    testWidgets('Manager login lands on AdminDashboardScreen with 4 navigation tabs', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final authProvider = AuthProvider();
      authProvider.setUser(
        const AppUser(
          id: 'adm_1',
          email: 'admin@fleetflow.com',
          displayName: 'Test Manager',
          role: UserRole.admin,
        ),
      );

      await tester.pumpWidget(
        FleetFlowApp(authProvider: authProvider),
      );
      await tester.pumpAndSettle();

      // Expect Admin Dashboard with navigation tabs
      expect(find.text('FleetFlow Operations'), findsOneWidget);
      expect(find.widgetWithText(NavigationDestination, 'Dashboard'), findsOneWidget);
      expect(find.widgetWithText(NavigationDestination, 'Drivers'), findsOneWidget);
      expect(find.widgetWithText(NavigationDestination, 'Vehicles'), findsOneWidget);
      expect(find.widgetWithText(NavigationDestination, 'Deliveries'), findsOneWidget);

      // Navigate to Drivers tab
      await tester.tap(find.widgetWithText(NavigationDestination, 'Drivers'));
      await tester.pumpAndSettle();
      expect(find.text('Driver Roster'), findsOneWidget);

      // Navigate to Vehicles tab
      await tester.tap(find.widgetWithText(NavigationDestination, 'Vehicles'));
      await tester.pumpAndSettle();
      expect(find.text('Vehicle Inventory'), findsOneWidget);

      // Navigate to Deliveries tab
      await tester.tap(find.widgetWithText(NavigationDestination, 'Deliveries'));
      await tester.pumpAndSettle();
      expect(find.text('Delivery Dispatch'), findsOneWidget);
    });

    testWidgets('Driver account is prevented from accessing manager portal', (WidgetTester tester) async {
      final authProvider = AuthProvider();
      authProvider.setUser(
        const AppUser(
          id: 'drv_1',
          email: 'driver@fleetflow.com',
          displayName: 'Test Driver',
          role: UserRole.driver,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AdminDashboardScreen(authProvider: authProvider),
        ),
      );
      await tester.pumpAndSettle();

      // Expect Access Denied guard
      expect(find.text('Access Denied'), findsOneWidget);
      expect(find.text('Manager Authorization Required'), findsOneWidget);
      expect(find.text('Go to Driver Home'), findsOneWidget);
    });
  });
}
