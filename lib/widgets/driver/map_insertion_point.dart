import 'package:flutter/material.dart';

/// Contract & Insertion Point for:
/// - Member 5: Map visualization & route polyline rendering
/// - Member 3: Live GPS tracking stream & driver location telemetry
class MapInsertionPoint extends StatelessWidget {
  final double destinationLat;
  final double destinationLng;
  final String destinationAddress;
  final double? currentDriverLat;
  final double? currentDriverLng;
  final bool isNavigationActive;
  final VoidCallback? onStartNavigation;
  final VoidCallback? onRecenter;
  final VoidCallback? onOpenExternalMap;
  final double height;

  const MapInsertionPoint({
    super.key,
    required this.destinationLat,
    required this.destinationLng,
    required this.destinationAddress,
    this.currentDriverLat,
    this.currentDriverLng,
    this.isNavigationActive = false,
    this.onStartNavigation,
    this.onRecenter,
    this.onOpenExternalMap,
    this.height = 240,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasDriverLocation = currentDriverLat != null && currentDriverLng != null;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade900,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Background Map Visualization Mock / Canvas
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blueGrey.shade800,
                      Colors.blueGrey.shade900,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: CustomPaint(
                  painter: _MapGridPainter(),
                ),
              ),
            ),

            // Insertion Point Identifier Banner (Team Agreement Notice)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.tealAccent.shade400, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.map_outlined, color: Colors.tealAccent.shade400, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Map Insertion Point (Member 5 Map / Member 3 GPS)',
                        style: TextStyle(
                          color: Colors.tealAccent.shade100,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Destination Pin & Driver Marker Visualization
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.4),
                          blurRadius: 16,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black89,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      destinationAddress,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Coordinates & Telemetry Floating Strip
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      hasDriverLocation
                          ? 'GPS: ${currentDriverLat!.toStringAsFixed(4)}, ${currentDriverLng!.toStringAsFixed(4)}'
                          : 'Dest: ${destinationLat.toStringAsFixed(4)}, ${destinationLng.toStringAsFixed(4)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (onOpenExternalMap != null)
                    IconButton.filledTonal(
                      onPressed: onOpenExternalMap,
                      icon: const Icon(Icons.open_in_new, size: 16),
                      tooltip: 'Open in External Navigation',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.15),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  if (onRecenter != null) ...[
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: onRecenter,
                      icon: const Icon(Icons.my_location, size: 16),
                      tooltip: 'Recenter to Driver',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.15),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lightweight decorative painter for the map preview background
class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1.0;

    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Decorative simulated arterial road
    final roadPaint = Paint()
      ..color = Colors.amber.withOpacity(0.25)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(0, size.height * 0.8)
      ..quadraticBezierTo(
        size.width * 0.45,
        size.height * 0.6,
        size.width * 0.5,
        size.height * 0.5,
      )
      ..lineTo(size.width, size.height * 0.2);

    canvas.drawPath(path, roadPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
