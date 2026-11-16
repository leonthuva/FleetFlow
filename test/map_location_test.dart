import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:fleet_flow/widgets/driver/map_insertion_point.dart';

class FakeLocation extends ForegroundLocation {
  bool enabled = true;
  LocationPermission granted = LocationPermission.denied;
  int checks = 0;
  @override
  Future<bool> serviceEnabled() async {
    checks++;
    return enabled;
  }

  @override
  Future<LocationPermission> permission() async => granted;
  @override
  Future<LocationPermission> requestPermission() async => granted;
  @override
  Future<Position> position() async => Position(
      latitude: 6.9,
      longitude: 79.8,
      timestamp: DateTime(2026),
      accuracy: 1,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0);
}

void main() {
  for (final permission in [
    LocationPermission.denied,
    LocationPermission.deniedForever
  ]) {
    testWidgets('map handles $permission without fabricated GPS',
        (tester) async {
      final location = FakeLocation()..granted = permission;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: MapInsertionPoint(
                  destinationLat: 6.9,
                  destinationLng: 79.8,
                  destinationAddress: 'Colombo',
                  location: location))));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('GPS:'), findsNothing);
      expect(find.text('OpenStreetMap contributors'), findsOneWidget);
    });
  }
  testWidgets('service disabled is checked again on resume', (tester) async {
    final location = FakeLocation()..enabled = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MapInsertionPoint(
                destinationLat: 6.9,
                destinationLng: 79.8,
                destinationAddress: 'Colombo',
                location: location))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(location.checks, 1);
    tester.binding
        .handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(location.checks, 2);
  });
}
