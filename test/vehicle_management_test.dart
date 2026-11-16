import 'dart:async';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_flow/models/vehicle.dart';
import 'package:fleet_flow/providers/auth_provider.dart';
import 'package:fleet_flow/providers/driver_provider.dart';
import 'package:fleet_flow/screens/admin/admin_dashboard_screen.dart';
import 'package:fleet_flow/screens/admin/vehicle_form_screen.dart';
import 'package:fleet_flow/screens/admin/vehicle_management_tab.dart';
import 'package:fleet_flow/screens/driver/driver_home_screen.dart';
import 'package:fleet_flow/services/delivery_service.dart';
import 'package:fleet_flow/services/vehicle_service.dart';

class PendingVehicleService extends VehicleService {
  Completer<String> pending = Completer<String>();
  int calls = 0;
  @override
  Future<String> createVehicle(Vehicle vehicle) {
    calls++;
    return pending.future;
  }
}

class RetryReadService extends VehicleService {
  int reads = 0;
  @override
  Stream<List<Vehicle>> watchVehicles() => ++reads == 1
      ? Stream.error(StateError('Permission denied'))
      : Stream.value(const [
          Vehicle(
              id: 'V1',
              licensePlate: 'WP RETRY-1',
              model: 'Van',
              status: VehicleStatus.available)
        ]);
  @override
  Stream<List<VehicleDriver>> watchDrivers() => Stream.value([]);
}

class RetryAssignmentService extends VehicleService {
  RetryAssignmentService(FakeFirebaseFirestore db)
      : super(firestore: db, currentUid: () => 'manager');
  int calls = 0;
  @override
  Future<void> assignVehicle(
      {required String driverId, required String vehicleId}) async {
    if (++calls == 1) throw StateError('Connection unavailable');
    await super.assignVehicle(driverId: driverId, vehicleId: vehicleId);
  }
}

void main() {
  Future<FakeFirebaseFirestore> database() async {
    final db = FakeFirebaseFirestore();
    await db.doc('users/manager').set({'role': 'admin'});
    await db
        .doc('users/driver')
        .set({'role': 'driver', 'displayName': 'Driver One', 'onShift': false});
    return db;
  }

  void largeScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets(
      'manager creates and edits a vehicle, assigns it, and driver home updates',
      (tester) async {
    largeScreen(tester);
    final db = await database();
    final service = VehicleService(firestore: db, currentUid: () => 'manager');
    final auth = AuthProvider(
        auth: MockFirebaseAuth(mockUser: MockUser(uid: 'manager')),
        firestore: db);
    addTearDown(auth.dispose);
    await auth.signIn(email: 'manager@example.test', password: 'test-only');
    final driver = DriverProvider(
        service: DeliveryService(firestore: db, currentUid: () => 'driver'));
    addTearDown(driver.dispose);
    driver.bindUser('driver');
    await tester.pumpWidget(MaterialApp(
        home: AdminDashboardScreen(
            authProvider: auth,
            vehicleService: service,
            service:
                DeliveryService(firestore: db, currentUid: () => 'manager'))));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationDestination, 'Vehicles'));
    await tester.pumpAndSettle();
    expect(
        find.text('No vehicles yet. Add a vehicle to begin.'), findsOneWidget);
    await tester.tap(find.text('Add vehicle'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'License plate'), 'WP ABC-1234');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Model'), 'Delivery Van');
    await tester.tap(find.text('Save vehicle'));
    await tester.pumpAndSettle();
    expect(find.text('WP ABC-1234'), findsOneWidget);
    await tester.tap(find.byTooltip('Edit WP ABC-1234'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Model'), 'Updated Van');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('In use').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save vehicle'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Updated Van'), findsOneWidget);
    final id = (await db.collection('vehicles').get()).docs.single.id;
    expect((await db.doc('vehicles/$id').get()).data()!['status'], 'in_use');
    await tester.tap(find.text('Assign vehicle'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('WP ABC-1234').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save assignment'));
    await tester.pumpAndSettle();
    expect((await db.doc('users/driver').get()).data()!['activeVehicleId'], id);
    await tester.pumpWidget(
        MaterialApp(home: DriverHomeScreen(driverProvider: driver)));
    await tester.pumpAndSettle();
    expect(find.text('Updated Van (WP ABC-1234)'), findsOneWidget);
    await service.assignVehicle(driverId: 'driver', vehicleId: '');
    await tester.pumpAndSettle();
    expect(find.text('No assigned vehicle (Unassigned)'), findsOneWidget);
  });

  testWidgets('vehicle form validates required fields without writing',
      (tester) async {
    final service = PendingVehicleService();
    await tester
        .pumpWidget(MaterialApp(home: VehicleFormScreen(service: service)));
    await tester.tap(find.text('Save vehicle'));
    await tester.pump();
    expect(find.text('License plate is required'), findsOneWidget);
    expect(find.text('Model is required'), findsOneWidget);
    expect(service.calls, 0);
  });

  testWidgets(
      'save stays pending, blocks duplicates, shows failure and permits retry',
      (tester) async {
    largeScreen(tester);
    final service = PendingVehicleService();
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) =>
                                VehicleFormScreen(service: service))),
                    child: const Text('Open form'))))));
    await tester.tap(find.text('Open form'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'License plate'), 'WP TEST-1');
    await tester.enterText(find.widgetWithText(TextFormField, 'Model'), 'Van');
    await tester.tap(find.text('Save vehicle'));
    await tester.pump();
    expect(service.calls, 1);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(find.byType(VehicleFormScreen), findsOneWidget);
    service.pending.completeError(StateError('Connection unavailable'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Connection unavailable'), findsOneWidget);
    expect(find.text('WP TEST-1'), findsOneWidget);
    service.pending = Completer<String>();
    await tester.tap(find.text('Save vehicle'));
    await tester.pump();
    expect(service.calls, 2);
    service.pending.complete('V1');
    await tester.pumpAndSettle();
    expect(find.text('Open form'), findsOneWidget);
    expect(find.byType(VehicleFormScreen), findsNothing);
  });

  testWidgets(
      'inventory permission error is visible and retry reloads the stream',
      (tester) async {
    final service = RetryReadService();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: VehicleManagementTab(service: service))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Permission denied'), findsOneWidget);
    await tester.tap(find.text('Retry vehicles'));
    await tester.pumpAndSettle();
    expect(find.text('WP RETRY-1'), findsOneWidget);
    expect(find.text('No drivers found.'), findsOneWidget);
  });

  testWidgets(
      'assignment failure preserves selection and retries real persistence',
      (tester) async {
    largeScreen(tester);
    final db = await database();
    final working = RetryAssignmentService(db);
    await db.doc('vehicles/V1').set(
        {'licensePlate': 'WP TEST-1', 'model': 'Van', 'status': 'available'});
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: VehicleManagementTab(service: working))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Assign vehicle'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('WP TEST-1').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save assignment'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Connection unavailable'), findsOneWidget);
    expect(
        (await db.doc('users/driver').get())
            .data()!
            .containsKey('activeVehicleId'),
        isFalse);
    await tester.tap(find.text('Save assignment'));
    await tester.pumpAndSettle();
    expect(working.calls, 2);
    expect(
        (await db.doc('users/driver').get()).data()!['activeVehicleId'], 'V1');
  });

  testWidgets('a signed-in driver cannot open manager vehicle controls',
      (tester) async {
    final db = await database();
    final auth = AuthProvider(
        auth: MockFirebaseAuth(mockUser: MockUser(uid: 'driver')),
        firestore: db);
    addTearDown(auth.dispose);
    await auth.signIn(email: 'driver@example.test', password: 'test-only');
    await tester.pumpWidget(
        MaterialApp(home: AdminDashboardScreen(authProvider: auth)));
    expect(find.text('Manager Authorization Required'), findsOneWidget);
    expect(find.text('Add vehicle'), findsNothing);
  });
}
