import 'package:fleet_flow/screens/admin/create_delivery_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const drivers = [
    DemoDriver(id: 'driver-1', name: 'Demo Driver', status: 'On Shift'),
  ];

  Future<void> pumpForm(
    WidgetTester tester, {
    List<DemoDriver> demoDrivers = drivers,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(home: CreateDeliveryScreen(drivers: demoDrivers)),
    );
  }

  testWidgets('validates required delivery and assignment fields', (
    tester,
  ) async {
    await pumpForm(tester);

    await tester.ensureVisible(
      find.byKey(const Key('preview-delivery-button')),
    );
    await tester.tap(find.byKey(const Key('preview-delivery-button')));
    await tester.pump();

    expect(find.text('Recipient name is required'), findsOneWidget);
    expect(find.text('Recipient phone is required'), findsOneWidget);
    expect(find.text('Pickup address is required'), findsOneWidget);
    expect(find.text('Delivery address is required'), findsOneWidget);
    expect(find.text('Package description is required'), findsOneWidget);
    expect(find.text('Driver assignment is required'), findsOneWidget);
  });

  testWidgets('shows a visible not-saved outcome after a valid preview', (
    tester,
  ) async {
    await pumpForm(tester);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Alex Recipient');
    await tester.enterText(fields.at(1), '+94 77 123 4567');
    await tester.enterText(fields.at(2), 'Central Hub');
    await tester.enterText(fields.at(3), '10 Main Street');
    await tester.enterText(fields.at(4), 'Two cartons');

    await tester.ensureVisible(find.byKey(const Key('driver-picker')));
    await tester.tap(find.byKey(const Key('driver-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Demo Driver').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('preview-delivery-button')),
    );
    await tester.tap(find.byKey(const Key('preview-delivery-button')));
    await tester.pump();
    expect(find.text('Checking preview…'), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.text('Delivery was not saved'), findsOneWidget);
    expect(find.textContaining('shared contract is approved'), findsOneWidget);
  });

  testWidgets('shows an empty assignment state when no drivers are on shift', (
    tester,
  ) async {
    await pumpForm(
      tester,
      demoDrivers: const [
        DemoDriver(id: 'driver-2', name: 'Off-duty Driver', status: 'Off Duty'),
      ],
    );

    expect(find.text('No on-shift demo drivers available'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('preview-delivery-button')),
    );
    expect(button.onPressed, isNull);
  });
}
