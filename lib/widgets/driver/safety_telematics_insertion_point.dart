import 'package:flutter/material.dart';

/// Contract & Insertion Point for:
/// - Member 3: Smartphone sensor telematics (speed, harsh braking, acceleration)
/// - Member 5: Safety notifications, speed limit warnings, and SOS trigger
class SafetyTelematicsInsertionPoint extends StatelessWidget {
  final double currentSpeedKmh;
  final double speedLimitKmh;
  final int safetyScore; // 0 to 100
  final int harshBrakingCount;
  final VoidCallback? onEmergencySosPressed;

  const SafetyTelematicsInsertionPoint({
    super.key,
    this.currentSpeedKmh = 42.0,
    this.speedLimitKmh = 50.0,
    this.safetyScore = 98,
    this.harshBrakingCount = 0,
    this.onEmergencySosPressed,
  });

  bool get isSpeeding => currentSpeedKmh > speedLimitKmh;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Insertion Header Banner (Contract Agreement)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, color: Colors.amber.shade800, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Safety & Telematics Insertion Point (Member 3 & 5)',
                      style: TextStyle(
                        color: Colors.amber.shade900,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Speed & Telemetry Readings
            Row(
              children: [
                // Speedometer Indicator
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSpeeding ? Colors.red.shade50 : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSpeeding ? Colors.red.shade300 : Colors.green.shade300,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.speed,
                              size: 16,
                              color: isSpeeding ? Colors.red.shade700 : Colors.green.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'LIVE SPEED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isSpeeding ? Colors.red.shade800 : Colors.green.shade800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              currentSpeedKmh.toStringAsFixed(0),
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: isSpeeding ? Colors.red.shade900 : Colors.green.shade900,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'km/h',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.shade400),
                              ),
                              child: Text(
                                'Limit ${speedLimitKmh.toInt()}',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Driving Safety Score
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'SAFETY',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$safetyScore%',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                        Text(
                          '$harshBrakingCount harsh events',
                          style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Emergency SOS Assistance Button
            OutlinedButton.icon(
              onPressed: onEmergencySosPressed ?? () => _showSosDialog(context),
              icon: const Icon(Icons.emergency_outlined, color: Colors.red),
              label: const Text(
                'Safety / Roadside Assistance (SOS)',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.red.shade300),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSosDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Emergency SOS'),
          ],
        ),
        content: const Text(
          'This alerts the Fleet Dispatcher with your current GPS coordinates, vehicle ID, and triggers emergency protocol.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🚨 Emergency alert dispatched to Manager!'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirm SOS Alert'),
          ),
        ],
      ),
    );
  }
}

/// Compact horizontal banner used at top of Driver Home or Delivery screen
class SafetyBannerWidget extends StatelessWidget {
  final int safetyScore;
  final bool isSafe;

  const SafetyBannerWidget({
    super.key,
    this.safetyScore = 98,
    this.isSafe = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isSafe ? Colors.teal.shade50 : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSafe ? Colors.teal.shade200 : Colors.amber.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isSafe ? Icons.verified_user : Icons.warning_amber_rounded,
            color: isSafe ? Colors.teal.shade700 : Colors.amber.shade800,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isSafe
                  ? 'Telematics Active: Safe Driving Mode ($safetyScore/100)'
                  : 'Telematics Alert: Speed or Harsh Braking Warning',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSafe ? Colors.teal.shade900 : Colors.amber.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
