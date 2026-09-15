import 'package:flutter/material.dart';

import '../widgets/app_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FleetFlow'),
      ),
      body: const Center(
        child: AppCard(
          title: 'FleetFlow',
          subtitle: 'Fleet & Delivery Management System',
        ),
      ),
    );
  }
}