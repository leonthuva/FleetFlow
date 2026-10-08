import 'package:flutter/material.dart';

import 'providers/auth_provider.dart';
import 'providers/driver_provider.dart';
import 'providers/history_provider.dart';
import 'providers/notification_provider.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/customer/customer_tracking_screen.dart';
import 'screens/driver/assigned_jobs_screen.dart';
import 'screens/driver/driver_home_screen.dart';
import 'screens/driver/shift_summary_screen.dart';
import 'screens/history/trip_history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'services/firebase_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService().initialize();
  await NotificationService().initialize();
  runApp(const FleetFlowApp());
}

class FleetFlowApp extends StatefulWidget {
  final AuthProvider? authProvider;
  final DriverProvider? driverProvider;
  final NotificationProvider? notificationProvider;
  final HistoryProvider? historyProvider;
  final Widget? home;

  const FleetFlowApp({
    super.key,
    this.authProvider,
    this.driverProvider,
    this.notificationProvider,
    this.historyProvider,
    this.home,
  });

  @override
  State<FleetFlowApp> createState() => _FleetFlowAppState();
}

class _FleetFlowAppState extends State<FleetFlowApp> {
  late final AuthProvider _authProvider;
  late final DriverProvider _driverProvider;
  late final NotificationProvider _notificationProvider;
  late final HistoryProvider _historyProvider;

  @override
  void initState() {
    super.initState();
    _authProvider = widget.authProvider ?? AuthProvider();
    _driverProvider = widget.driverProvider ?? DriverProvider();
    _notificationProvider = widget.notificationProvider ?? NotificationProvider();
    _historyProvider = widget.historyProvider ?? HistoryProvider();
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
        '/admin': (context) => AdminDashboardScreen(
              authProvider: _authProvider,
              historyProvider: _historyProvider,
            ),
        '/driver-home': (context) => DriverHomeScreen(
              authProvider: _authProvider,
              driverProvider: _driverProvider,
              historyProvider: _historyProvider,
            ),
        '/history': (context) => TripHistoryScreen(
              historyProvider: _historyProvider,
              user: _authProvider.currentUser,
            ),
        '/driver/jobs': (context) => AssignedJobsScreen(
              driverProvider: _driverProvider,
            ),
        '/driver/shift-summary': (context) => ShiftSummaryScreen(
              driverProvider: _driverProvider,
            ),
        '/driver/hub': (context) => HomeScreen(authProvider: _authProvider),
        '/notifications': (context) => NotificationsScreen(
              notificationProvider: _notificationProvider,
            ),
        '/customer-tracking': (context) => const CustomerTrackingScreen(),
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
          return AdminDashboardScreen(
            authProvider: _authProvider,
            historyProvider: _historyProvider,
          );
        } else {
          return DriverHomeScreen(
            authProvider: _authProvider,
            driverProvider: _driverProvider,
            historyProvider: _historyProvider,
          );
        }
      },
    );
  }
}
