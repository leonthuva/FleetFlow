import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

abstract class ForegroundLocation {
  const ForegroundLocation();
  Future<bool> serviceEnabled();
  Future<LocationPermission> permission();
  Future<LocationPermission> requestPermission();
  Future<Position> position();
}

class DeviceForegroundLocation extends ForegroundLocation {
  const DeviceForegroundLocation();
  @override
  Future<bool> serviceEnabled() => Geolocator.isLocationServiceEnabled();
  @override
  Future<LocationPermission> permission() => Geolocator.checkPermission();
  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();
  @override
  Future<Position> position() => Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)));
}

/// Real OpenStreetMap view for the driver screen (Member 3).
///
/// The constructor is unchanged from the placeholder, so existing screens
/// keep working.
/// - Shows the destination pin and the driver's position.
/// - If the parent passes currentDriverLat/currentDriverLng, those are used.
/// - Otherwise this widget reads the phone's GPS once (foreground only).
/// - Nothing is written to Firestore.
class MapInsertionPoint extends StatefulWidget {
  final ForegroundLocation location;
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
    this.location = const DeviceForegroundLocation(),
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
  State<MapInsertionPoint> createState() => _MapInsertionPointState();
}

enum _LocationState {
  checking,
  tracking,
  serviceOff,
  denied,
  deniedForever,
  error,
}

class _MapInsertionPointState extends State<MapInsertionPoint>
    with WidgetsBindingObserver {
  final MapController _mapController = MapController();
  LatLng? _liveLocation;
  _LocationState _state = _LocationState.checking;
  bool _mapReady = false;
  bool _didFitOnce = false;
  bool _starting = false;
  bool _wasPaused = false;

  bool get _parentProvidesLocation =>
      widget.currentDriverLat != null && widget.currentDriverLng != null;

  LatLng get _destination =>
      LatLng(widget.destinationLat, widget.destinationLng);

  LatLng? get _driverLocation {
    if (_parentProvidesLocation) {
      return LatLng(widget.currentDriverLat!, widget.currentDriverLng!);
    }
    return _liveLocation;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!_parentProvidesLocation) {
      _startTracking();
    }
  }

  @override
  void didUpdateWidget(covariant MapInsertionPoint oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fitIfNeeded();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _wasPaused = true;
      return;
    }
    if (state != AppLifecycleState.resumed || !_wasPaused) return;
    _wasPaused = false;
    if (_parentProvidesLocation) return;
    // The user left the app and came back; they may have fixed GPS or
    // permission in phone settings.
    _startTracking();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _startTracking() async {
    if (_starting) return;
    _starting = true;
    try {
      if (!mounted) return;
      setState(() => _state = _LocationState.checking);

      final serviceOn = await widget.location.serviceEnabled();
      if (!mounted) return;
      if (!serviceOn) {
        setState(() => _state = _LocationState.serviceOff);
        return;
      }

      var permission = await widget.location.permission();
      if (permission == LocationPermission.denied) {
        permission = await widget.location.requestPermission();
      }
      if (!mounted) return;
      if (permission == LocationPermission.deniedForever) {
        setState(() => _state = _LocationState.deniedForever);
        return;
      }
      if (permission == LocationPermission.denied) {
        setState(() => _state = _LocationState.denied);
        return;
      }

      final position = await widget.location.position();
      if (!mounted) return;
      setState(() {
        _liveLocation = LatLng(position.latitude, position.longitude);
        _state = _LocationState.tracking;
      });
      _fitIfNeeded();
    } catch (_) {
      if (mounted) setState(() => _state = _LocationState.error);
    } finally {
      _starting = false;
    }
  }

  void _fitIfNeeded() {
    final driver = _driverLocation;
    if (_didFitOnce || !_mapReady || driver == null) return;
    _didFitOnce = true;
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: [driver, _destination],
        padding: const EdgeInsets.all(48),
        maxZoom: 16,
      ),
    );
  }

  void _recenter() {
    if (!_mapReady) return;
    final driver = _driverLocation;
    if (driver == null) {
      if (!_parentProvidesLocation) _startTracking();
      return;
    }
    _mapController.move(driver, 16);
  }

  Widget? _buildStatusBanner() {
    if (_parentProvidesLocation || _state == _LocationState.tracking) {
      return null;
    }

    String message;
    String? actionLabel;
    Future<dynamic> Function()? onAction;

    switch (_state) {
      case _LocationState.checking:
        message = 'Finding your location...';
        break;
      case _LocationState.serviceOff:
        message = 'Location is turned off';
        actionLabel = 'Turn on';
        onAction = Geolocator.openLocationSettings;
        break;
      case _LocationState.denied:
        message = 'Location permission denied';
        actionLabel = 'Allow';
        onAction = _startTracking;
        break;
      case _LocationState.deniedForever:
        message = 'Location permission blocked';
        actionLabel = 'Settings';
        onAction = Geolocator.openAppSettings;
        break;
      case _LocationState.error:
        message = 'Location unavailable';
        actionLabel = 'Retry';
        onAction = _startTracking;
        break;
      case _LocationState.tracking:
        return null;
    }

    return Container(
      padding: const EdgeInsets.only(left: 10, top: 2, bottom: 2, right: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amberAccent.shade400, width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.location_off,
              color: Colors.amberAccent.shade400, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: () => onAction!(),
              style: TextButton.styleFrom(
                foregroundColor: Colors.tealAccent.shade100,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(actionLabel, style: const TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final driver = _driverLocation;
    final banner = _buildStatusBanner();

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade900,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned.fill(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _destination,
                  initialZoom: 14,
                  onMapReady: () {
                    _mapReady = true;
                    _fitIfNeeded();
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.fleetflow.fleet_flow',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _destination,
                        width: 44,
                        height: 44,
                        alignment: Alignment.topCenter,
                        child: Icon(
                          Icons.location_on,
                          color: theme.colorScheme.primary,
                          size: 40,
                        ),
                      ),
                      if (driver != null)
                        Marker(
                          point: driver,
                          width: 28,
                          height: 28,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SimpleAttributionWidget(
                    source: Text('OpenStreetMap contributors'),
                  ),
                ],
              ),
            ),

            // Destination address and location status
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.flag, color: Colors.white, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.destinationAddress,
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
                  if (banner != null) ...[
                    const SizedBox(height: 6),
                    banner,
                  ],
                ],
              ),
            ),

            // Coordinates and buttons
            Positioned(
              bottom: 22,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      driver != null
                          ? 'GPS: ${driver.latitude.toStringAsFixed(4)}, ${driver.longitude.toStringAsFixed(4)}'
                          : 'Dest: ${widget.destinationLat.toStringAsFixed(4)}, ${widget.destinationLng.toStringAsFixed(4)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (widget.onOpenExternalMap != null)
                    IconButton.filledTonal(
                      onPressed: widget.onOpenExternalMap,
                      icon: const Icon(Icons.open_in_new, size: 16),
                      tooltip: 'Open in External Navigation',
                    ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: () {
                      widget.onRecenter?.call();
                      _recenter();
                    },
                    icon: const Icon(Icons.my_location, size: 16),
                    tooltip: 'Recenter to Driver',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
