import 'package:flutter/material.dart';

import 'screens/driver/simulated_safety_demo_screen.dart';

void main() {
  runApp(const SimulatedSafetyDemoApp());
}

class SimulatedSafetyDemoApp extends StatelessWidget {
  const SimulatedSafetyDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FleetFlow Safety Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const SimulatedSafetyDemoScreen(),
    );
  }
}
