import 'package:flutter/material.dart';

import 'providers/auth_provider.dart';
import 'providers/driver_provider.dart';
import 'providers/notification_provider.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/customer/customer_tracking_screen.dart';
import 'screens/driver/assigned_jobs_screen.dart';
import 'screens/driver/driver_home_screen.dart';
import 'screens/driver/shift_summary_screen.dart';
import 'screens/history/history_page.dart';
import 'screens/history/delivery_history_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'services/firebase_service.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await FirebaseService().initialize();
    await SupabaseService.initialize();
    runApp(const FleetFlowApp());
  } catch (e) {
    runApp(MaterialApp(
        home: Scaffold(
            body: Center(
                child: Text('FleetFlow could not initialize Firebase: $e')))));
  }
}

class FleetFlowApp extends StatefulWidget {
  final AuthProvider? authProvider;
  final DriverProvider? driverProvider;
  final NotificationProvider? notificationProvider;
  final Widget? home;

  const FleetFlowApp({
    super.key,
    this.authProvider,
    this.driverProvider,
    this.notificationProvider,
    this.home,
  });

  @override
  State<FleetFlowApp> createState() => _FleetFlowAppState();
}

class _FleetFlowAppState extends State<FleetFlowApp> {
  late final AuthProvider _authProvider;
  late final DriverProvider _driverProvider;
  late final NotificationProvider _notificationProvider;

  @override
  void initState() {
    super.initState();
    _authProvider = widget.authProvider ?? (AuthProvider()..start());
    _driverProvider = widget.driverProvider ?? DriverProvider();
    _authProvider.addListener(_syncDriver);
    _notificationProvider =
        widget.notificationProvider ?? NotificationProvider();
    _syncDriver();
  }

  void _syncDriver() {
    _notificationProvider.bindUser(_authProvider.currentUser?.id);
    _driverProvider.bindUser(_authProvider.currentUser?.isDriver == true
        ? _authProvider.currentUser!.id
        : null);
  }

  @override
  void dispose() {
    _authProvider.removeListener(_syncDriver);
    if (widget.authProvider == null) _authProvider.dispose();
    if (widget.driverProvider == null) _driverProvider.dispose();
    if (widget.notificationProvider == null) _notificationProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
        listenable: _authProvider,
        builder: (context, _) => MaterialApp(
              key: ValueKey(
                  "${_authProvider.currentUser?.id}:${_authProvider.currentUser?.role}"),
              title: 'FleetFlow',
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
                useMaterial3: true,
              ),
              home: widget.home ?? _buildAuthGate(),
              routes: {
                '/login': (context) => LoginScreen(authProvider: _authProvider),
                '/admin': (context) =>
                    AdminDashboardScreen(authProvider: _authProvider),
                '/driver-home': (context) => _driverGuard(DriverHomeScreen(
                      authProvider: _authProvider,
                      driverProvider: _driverProvider,
                    )),
                '/driver/jobs': (context) => _driverGuard(AssignedJobsScreen(
                      driverProvider: _driverProvider,
                    )),
                '/driver/shift-summary': (context) =>
                    _driverGuard(ShiftSummaryScreen(
                      driverProvider: _driverProvider,
                    )),
                '/driver/hub': (context) => _driverGuard(DriverHomeScreen(
                    authProvider: _authProvider,
                    driverProvider: _driverProvider)),
                '/notifications': (context) => NotificationsScreen(
                      notificationProvider: _notificationProvider,
                    ),
                '/trip-history': (context) => _authProvider.currentUser == null
                    ? LoginScreen(authProvider: _authProvider)
                    : HistoryPage(user: _authProvider.currentUser!),
                '/delivery-history': (context) => _authProvider.currentUser ==
                        null
                    ? LoginScreen(authProvider: _authProvider)
                    : DeliveryHistoryScreen(user: _authProvider.currentUser!),
                '/customer-tracking': (context) =>
                    const CustomerTrackingScreen(),
              },
            ));
  }

  Widget _driverGuard(Widget child) =>
      _authProvider.currentUser?.isDriver == true
          ? child
          : const Scaffold(
              body: Center(child: Text('Driver authorization required')));

  Widget _buildAuthGate() {
    return ListenableBuilder(
      listenable: _authProvider,
      builder: (context, _) {
        if (_authProvider.isLoading) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
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
