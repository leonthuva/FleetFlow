import 'package:flutter/material.dart';

class CameraPodInsertionPoint extends StatelessWidget {
  final String deliveryId;
  final String? initialPhotoUrl, initialNotes;
  final ValueChanged<String>? onPhotoCaptured;
  final void Function(String, String)? onDetailsSubmitted;
  final bool isRequired;
  const CameraPodInsertionPoint(
      {super.key,
      required this.deliveryId,
      this.initialPhotoUrl,
      this.initialNotes,
      this.onPhotoCaptured,
      this.onDetailsSubmitted,
      this.isRequired = true});
  @override
  Widget build(BuildContext context) => const Card(
      child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
              'Open an arrived assignment to capture proof. Secure upload is currently unavailable.')));
}
