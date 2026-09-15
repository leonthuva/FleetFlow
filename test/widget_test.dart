import 'package:flutter_test/flutter_test.dart';

import 'package:fleet_flow/main.dart';

void main() {
  testWidgets('FleetFlow home screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const FleetFlowApp());

    expect(find.text('FleetFlow'), findsNWidgets(2));
    expect(find.text('Fleet & Delivery Management System'), findsOneWidget);
  });
}