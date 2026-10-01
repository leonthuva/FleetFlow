import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleet_flow/main.dart';
import 'package:fleet_flow/models/delivery.dart';
import 'package:fleet_flow/models/user.dart';
import 'package:fleet_flow/models/vehicle.dart';
import 'package:fleet_flow/providers/auth_provider.dart';
import 'package:fleet_flow/providers/driver_provider.dart';
import 'package:fleet_flow/screens/driver/assigned_jobs_screen.dart';
import 'package:fleet_flow/screens/driver/delivery_detail_screen.dart';
import 'package:fleet_flow/screens/driver/driver_home_screen.dart';
import 'package:fleet_flow/screens/driver/shift_summary_screen.dart';
import 'package:fleet_flow/widgets/driver/camera_pod_insertion_point.dart';
import 'package:fleet_flow/widgets/driver/map_insertion_point.dart';
import 'package:fleet_flow/widgets/driver/safety_telematics_insertion_point.dart';

void main() {
  group('Member 2: Delivery Lifecycle State Machine Tests', () {
    test('linear status progression sequence is strictly enforced', () {
      // 1. assigned -> picked_up
      expect(
        DeliveryStatus.isValidTransition(DeliveryStatus.assigned, DeliveryStatus.pickedUp),
        isTrue,
      );

      // 2. picked_up -> in_transit
      expect(
        DeliveryStatus.isValidTransition(DeliveryStatus.pickedUp, DeliveryStatus.inTransit),
        isTrue,
      );

      // 3. in_transit -> arrived
      expect(
        DeliveryStatus.isValidTransition(DeliveryStatus.inTransit, DeliveryStatus.arrived),
        isTrue,
      );

      // 4. arrived -> completed
      expect(
        DeliveryStatus.isValidTransition(DeliveryStatus.arrived, DeliveryStatus.completed),
        isTrue,
      );

      // Disallow skipping states
      expect(
        DeliveryStatus.isValidTransition(DeliveryStatus.assigned, DeliveryStatus.inTransit),
        isFalse,
      );
      expect(
        DeliveryStatus.isValidTransition(DeliveryStatus.assigned, DeliveryStatus.completed),
        isFalse,
      );
      expect(
        DeliveryStatus.isValidTransition(DeliveryStatus.pickedUp, DeliveryStatus.completed),
        isFalse,
      );

      // Disallow backwards transitions
      expect(
        DeliveryStatus.isValidTransition(DeliveryStatus.inTransit, DeliveryStatus.pickedUp),
        isFalse,
      );
      expect(
        DeliveryStatus.isValidTransition(DeliveryStatus.completed, DeliveryStatus.assigned),
        isFalse,
      );

      // Cancellation permitted prior to completion, but not after completion
      expect(
        DeliveryStatus.isValidTransition(DeliveryStatus.assigned, DeliveryStatus.cancelled),
        isTrue,
      );
      expect(
        DeliveryStatus.isValidTransition(DeliveryStatus.inTransit, DeliveryStatus.cancelled),
        isTrue,
      );
      expect(
        DeliveryStatus.isValidTransition(DeliveryStatus.completed, DeliveryStatus.cancelled),
        isFalse,
      );
    });

    test('step index and display names correctly reflect sequence', () {
      expect(DeliveryStatus.stepIndex(DeliveryStatus.assigned), 0);
      expect(DeliveryStatus.stepIndex(DeliveryStatus.pickedUp), 1);
      expect(DeliveryStatus.stepIndex(DeliveryStatus.inTransit), 2);
      expect(DeliveryStatus.stepIndex(DeliveryStatus.arrived), 3);
      expect(DeliveryStatus.stepIndex(DeliveryStatus.completed), 4);

      expect(DeliveryStatus.displayName(DeliveryStatus.assigned), 'Assigned');
      expect(DeliveryStatus.displayName(DeliveryStatus.pickedUp), 'Picked Up');
      expect(DeliveryStatus.displayName(DeliveryStatus.inTransit), 'In Transit');
      expect(DeliveryStatus.displayName(DeliveryStatus.arrived), 'Arrived');
      expect(DeliveryStatus.displayName(DeliveryStatus.completed), 'Completed');
    });

    test('Delivery serialization preserves all lifecycle fields and coordinates', () {
      final now = DateTime.now();
      final delivery = Delivery(
        id: 'TEST-101',
        driverId: 'drv_test',
        vehicleId: 'veh_test',
        recipientName: 'Apex Health Corp',
        recipientPhone: '+1-555-0100',
        address: '500 Market St, San Francisco, CA',
        latitude: 37.792,
        longitude: -122.401,
        packageDescription: 'Critical Cold Box',
        specialInstructions: 'Ring bell at Gate 4',
        priority: 'urgent',
        status: DeliveryStatus.inTransit,
        createdAt: now,
      );

      final map = delivery.toMap();
      expect(map['id'], 'TEST-101');
      expect(map['recipientName'], 'Apex Health Corp');
      expect(map['status'], DeliveryStatus.inTransit);
      expect(map['latitude'], 37.792);
      expect(map['longitude'], -122.401);

      final restored = Delivery.fromMap(map);
      expect(restored.id, 'TEST-101');
      expect(restored.recipientName, 'Apex Health Corp');
      expect(restored.status, DeliveryStatus.inTransit);
      expect(restored.latitude, 37.792);
      expect(restored.longitude, -122.401);
      expect(restored.isInTransit, isTrue);
      expect(restored.canTransitionTo(DeliveryStatus.arrived), isTrue);
      expect(restored.canTransitionTo(DeliveryStatus.completed), isFalse);
    });
  });

  group('Member 2: DriverProvider State & Shift Management', () {
    test('DriverProvider handles shift start and end cycles', () {
      final provider = DriverProvider();
      expect(provider.isShiftActive, isTrue);

      provider.endShift();
      expect(provider.isShiftActive, isFalse);
      expect(provider.shiftEndTime, isNotNull);

      provider.startShift(
        vehicle: const Vehicle(
          id: 'v2',
          licensePlate: 'ABC-123',
          model: 'Mercedes Sprinter',
          status: VehicleStatus.inUse,
        ),
      );
      expect(provider.isShiftActive, isTrue);
      expect(provider.activeVehicle.licensePlate, 'ABC-123');
    });

    test('advanceDeliveryStatus follows the formal progression', () {
      final provider = DriverProvider();

      // Find an assigned delivery
      final assigned = provider.deliveries.firstWhere((d) => d.isAssigned);
      final id = assigned.id;

      // assigned -> picked_up
      final s1 = provider.advanceDeliveryStatus(id);
      expect(s1, isTrue);
      expect(provider.getDeliveryById(id)?.status, DeliveryStatus.pickedUp);

      // picked_up -> in_transit
      final s2 = provider.advanceDeliveryStatus(id);
      expect(s2, isTrue);
      expect(provider.getDeliveryById(id)?.status, DeliveryStatus.inTransit);

      // in_transit -> arrived
      final s3 = provider.advanceDeliveryStatus(id);
      expect(s3, isTrue);
      expect(provider.getDeliveryById(id)?.status, DeliveryStatus.arrived);

      // arrived -> completed
      final s4 = provider.advanceDeliveryStatus(id);
      expect(s4, isTrue);
      expect(provider.getDeliveryById(id)?.status, DeliveryStatus.completed);

      // cannot advance beyond completed
      final s5 = provider.advanceDeliveryStatus(id);
      expect(s5, isFalse);
    });

    test('attachProofOfDelivery attaches photo and notes to delivery', () {
      final provider = DriverProvider();
      final id = provider.deliveries.first.id;

      provider.attachProofOfDelivery(id, 'https://example.com/pod.jpg', 'Left with receptionist');
      final updated = provider.getDeliveryById(id);
      expect(updated?.proofPhotoUrl, 'https://example.com/pod.jpg');
      expect(updated?.signatureNotes, 'Left with receptionist');
    });
  });

  group('Member 2: UI Screens & Agreed Component Insertion Points', () {
    testWidgets('DriverHomeScreen renders driver banner, shift status, and quick actions',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final authProvider = AuthProvider();
      authProvider.setUser(
        const AppUser(
          id: 'drv_test',
          email: 'driver@fleetflow.com',
          displayName: 'Alex Driver',
          role: UserRole.driver,
        ),
      );

      final driverProvider = DriverProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: DriverHomeScreen(
            authProvider: authProvider,
            driverProvider: driverProvider,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alex Driver'), findsOneWidget);
      expect(find.text('ON DUTY'), findsOneWidget);
      expect(find.text('Telematics Active: Safe Driving Mode (98/100)'), findsOneWidget);
      expect(find.text('Assigned Jobs Today'), findsOneWidget);
      expect(find.text('ACTIVE JOB'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'All Jobs'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Summary'), findsOneWidget);
    });

    testWidgets('AssignedJobsScreen allows filtering deliveries', (WidgetTester tester) async {
      final driverProvider = DriverProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: AssignedJobsScreen(driverProvider: driverProvider),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Assigned Jobs'), findsOneWidget);
      expect(find.textContaining('All ('), findsOneWidget);
      expect(find.textContaining('Active ('), findsOneWidget);
      expect(find.textContaining('Pending ('), findsOneWidget);
      expect(find.textContaining('Completed ('), findsOneWidget);

      // Tap on 'Completed' filter chip
      await tester.tap(find.textContaining('Completed ('));
      await tester.pumpAndSettle();

      expect(find.text('Completed'), findsWidgets);
    });

    testWidgets('DeliveryDetailScreen displays 5-step lifecycle and agreed insertion points',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final driverProvider = DriverProvider();
      final activeDelivery = driverProvider.deliveries.firstWhere((d) => d.isInTransit);

      await tester.pumpWidget(
        MaterialApp(
          home: DeliveryDetailScreen(
            deliveryId: activeDelivery.id,
            driverProvider: driverProvider,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify 5-step lifecycle progression bar
      expect(find.text('Delivery Lifecycle Flow'), findsOneWidget);
      expect(find.text('Step 3 of 5: In Transit'), findsOneWidget);

      // 2. Verify Agreed Insertion Points
      // Member 5 Map / Member 3 GPS Insertion Point
      expect(find.byType(MapInsertionPoint), findsOneWidget);
      expect(find.textContaining('Map Insertion Point (Member 5 Map / Member 3 GPS)'), findsOneWidget);

      // Member 3 & 5 Safety / Telematics Insertion Point
      expect(find.byType(SafetyTelematicsInsertionPoint), findsOneWidget);
      expect(find.textContaining('Safety & Telematics Insertion Point'), findsOneWidget);

      // Member 5 Camera & POD Insertion Point
      expect(find.byType(CameraPodInsertionPoint), findsOneWidget);
      expect(find.textContaining('Camera & POD Insertion Point (Member 5 Component)'), findsOneWidget);

      // 3. Verify Contextual Action Button
      expect(find.widgetWithText(FilledButton, 'Mark Arrived at Destination'), findsOneWidget);
    });

    testWidgets('ShiftSummaryScreen displays telemetry score and delivery scorecard',
        (WidgetTester tester) async {
      final driverProvider = DriverProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: ShiftSummaryScreen(driverProvider: driverProvider),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Shift Summary & Report'), findsOneWidget);
      expect(find.text('Delivery Performance'), findsOneWidget);
      expect(find.text('Telematics Safety Scorecard'), findsOneWidget);
      expect(find.text('98/100'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'End Shift & Clock Out'), findsOneWidget);
    });

    testWidgets('Driver role routes to DriverHomeScreen in auth gate', (WidgetTester tester) async {
      final authProvider = AuthProvider();
      authProvider.setUser(
        const AppUser(
          id: 'd1',
          email: 'driver@fleetflow.com',
          displayName: 'Sam Driver',
          role: UserRole.driver,
        ),
      );

      await tester.pumpWidget(
        FleetFlowApp(authProvider: authProvider),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sam Driver'), findsOneWidget);
      expect(find.text('ON DUTY'), findsOneWidget);
    });
  });
}
