import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

void main() {
  runApp(const MapProofApp());
}

class MapProofApp extends StatelessWidget {
  const MapProofApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MapProofScreen(),
    );
  }
}

class MapProofScreen extends StatefulWidget {
  const MapProofScreen({super.key});

  @override
  State<MapProofScreen> createState() => _MapProofScreenState();
}

class _MapProofScreenState extends State<MapProofScreen> {
  final MapController _mapController = MapController();
  final LatLng _colombo = const LatLng(6.9271, 79.8612);
  LatLng? _myLocation;
  String _status = 'Tap the location button to check permission';

  Future<void> _findMyLocation() async {
    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!serviceOn) {
      setState(() => _status = 'Location service is OFF on the phone');
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      setState(() => _status = 'Permission DENIED');
      return;
    }
    if (permission == LocationPermission.deniedForever) {
      setState(() => _status =
          'Permission DENIED FOREVER (change it in phone settings)');
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    final here = LatLng(position.latitude, position.longitude);
    setState(() {
      _myLocation = here;
      _status =
          'Permission GRANTED: ${here.latitude.toStringAsFixed(5)}, ${here.longitude.toStringAsFixed(5)}';
    });
    _mapController.move(here, 16);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FleetFlow Map Proof')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _colombo,
              initialZoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.fleetflow.fleet_flow',
              ),
              if (_myLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _myLocation!,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.all(8),
              color: Colors.black87,
              child: Text(
                '$_status\n© OpenStreetMap contributors',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 60),
        child: FloatingActionButton(
          onPressed: _findMyLocation,
          child: const Icon(Icons.my_location),
        ),
      ),
    );
  }
}