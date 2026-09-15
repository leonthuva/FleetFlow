import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(const FleetFlowApp());
}

class FleetFlowApp extends StatelessWidget {
  const FleetFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FleetFlow',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}