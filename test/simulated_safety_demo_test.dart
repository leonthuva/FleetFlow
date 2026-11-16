import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_flow/screens/driver/simulated_safety_demo_screen.dart';

void main() {
  testWidgets('labels simulated values and events without claiming alerts',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SimulatedSafetyDemoScreen(),
    ));

    expect(find.textContaining('SIMULATED DATA ONLY'), findsOneWidget);
    expect(find.textContaining('simulated 50 km/h zone'), findsOneWidget);
    expect(find.text('Simulate speeding event'), findsOneWidget);
    expect(find.text('Simulate harsh braking event'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('simulate-speeding')));
    await tester.pump();

    expect(find.text('Simulated speeding event'), findsOneWidget);
    expect(find.text('Demo state only. No alert was sent.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('reset-simulation')));
    await tester.pump();
    expect(find.text('Simulated speeding event'), findsNothing);
  });
}
