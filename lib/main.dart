import 'package:flutter/material.dart';

import 'providers/auth_provider.dart';
import 'providers/driver_provider.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/driver/assigned_jobs_screen.dart';
import 'screens/driver/driver_home_screen.dart';
import 'screens/driver/shift_summary_screen.dart';
import 'services/firebase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService().initialize();
  runApp(const FleetFlowApp());
}

class FleetFlowApp extends StatefulWidget {
  final AuthProvider? authProvider;
  final DriverProvider? driverProvider;
  final Widget? home;

  const FleetFlowApp({
    super.key,
    this.authProvider,
    this.driverProvider,
    this.home,
  });

  @override
  State<FleetFlowApp> createState() => _FleetFlowAppState();
}

class _FleetFlowAppState extends State<FleetFlowApp> {
  late final AuthProvider _authProvider;
  late final DriverProvider _driverProvider;

  @override
  void initState() {
    super.initState();
    _authProvider = widget.authProvider ?? AuthProvider();
    _driverProvider = widget.driverProvider ?? DriverProvider();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FleetFlow',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: widget.home ?? _buildAuthGate(),
      routes: {
        '/login': (context) => LoginScreen(authProvider: _authProvider),
        '/admin': (context) => AdminDashboardScreen(authProvider: _authProvider),
        '/driver-home': (context) => DriverHomeScreen(
              authProvider: _authProvider,
              driverProvider: _driverProvider,
            ),
        '/driver/jobs': (context) => AssignedJobsScreen(
              driverProvider: _driverProvider,
            ),
        '/driver/shift-summary': (context) => ShiftSummaryScreen(
              driverProvider: _driverProvider,
            ),
      },
    );
  }

  Widget _buildAuthGate() {
    return ListenableBuilder(
      listenable: _authProvider,
      builder: (context, _) {
        if (!_authProvider.isAuthenticated) {
          return LoginScreen(authProvider: _authProvider);
        }

        final user = _authProvider.currentUser;
        if (user != null && user.isManager) {
          return AdminDashboardScreen(authProvider: _authProvider);
        } else {
          return DriverHomeScreen(
            authProvider: _authProvider,
            driverProvider: _driverProvider,
          );
        }
      },
    );
  }
}