import 'package:flutter/material.dart';
import '../providers/auth_provider.dart';
import '../providers/driver_provider.dart';
import 'driver/driver_home_screen.dart';

/// Compatibility entry point for the original driver hub.
class HomeScreen extends StatefulWidget {
  final AuthProvider? authProvider;
  const HomeScreen({super.key, this.authProvider});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final provider = DriverProvider();
  void sync() =>
      provider.bindUser(widget.authProvider?.currentUser?.isDriver == true
          ? widget.authProvider!.currentUser!.id
          : null);
  @override
  void initState() {
    super.initState();
    widget.authProvider?.addListener(sync);
    sync();
  }

  @override
  void dispose() {
    widget.authProvider?.removeListener(sync);
    provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DriverHomeScreen(
      authProvider: widget.authProvider, driverProvider: provider);
}
