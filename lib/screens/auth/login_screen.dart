import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/custom_text_field.dart';

class LoginScreen extends StatefulWidget {
  final AuthProvider authProvider;
  final VoidCallback? onLoginSuccess;

  const LoginScreen({
    super.key,
    required this.authProvider,
    this.onLoginSuccess,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  String _selectedRole = UserRole.admin;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  void _handleRoleSwitch(String role) {
    setState(() {
      _selectedRole = role;
      if (role == UserRole.admin) {
        _emailController.text = 'admin@fleetflow.com';
        _passwordController.text = 'admin123';
      } else if (role == UserRole.dispatcher) {
        _emailController.text = 'dispatcher@fleetflow.com';
        _passwordController.text = 'dispatch123';
      } else {
        _emailController.text = 'driver@fleetflow.com';
        _passwordController.text = 'driver123';
      }
    });
  }

  Future<void> _submit() async {
    widget.authProvider.clearError();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final success = await widget.authProvider.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      roleOverride: _selectedRole,
    );

    if (success && mounted) {
      if (widget.onLoginSuccess != null) {
        widget.onLoginSuccess!();
      } else {
        final user = widget.authProvider.currentUser;
        if (user != null && user.isManager) {
          Navigator.of(context).pushReplacementNamed('/admin');
        } else {
          Navigator.of(context).pushReplacementNamed('/driver-home');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FleetFlow'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: ListenableBuilder(
                listenable: widget.authProvider,
                builder: (context, _) {
                  return Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // App Brand Card (keeps smoke test expectations intact)
                        const AppCard(
                          title: 'FleetFlow',
                          subtitle: 'Fleet & Delivery Management System',
                        ),
                        const SizedBox(height: 24),

                        Text(
                          'Sign In to Your Account',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Select your role or enter your credentials below',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 18),

                        // Role Selector Chips (Manager vs Driver)
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: UserRole.admin,
                              label: Text('Manager'),
                              icon: Icon(Icons.admin_panel_settings_outlined),
                            ),
                            ButtonSegment(
                              value: UserRole.driver,
                              label: Text('Driver'),
                              icon: Icon(Icons.local_shipping_outlined),
                            ),
                          ],
                          selected: {_selectedRole},
                          onSelectionChanged: (selection) {
                            if (selection.isNotEmpty) {
                              _handleRoleSwitch(selection.first);
                            }
                          },
                        ),
                        const SizedBox(height: 20),

                        // Error Banner if present
                        if (widget.authProvider.errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              border: Border.all(color: Colors.red.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: Colors.red.shade700),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.authProvider.errorMessage!,
                                    style: TextStyle(color: Colors.red.shade900),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Email Field
                        CustomTextField(
                          controller: _emailController,
                          label: 'Email Address',
                          hint: 'user@fleetflow.com',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: _validateEmail,
                          enabled: !widget.authProvider.isLoading,
                        ),
                        const SizedBox(height: 16),

                        // Password Field
                        CustomTextField(
                          controller: _passwordController,
                          label: 'Password',
                          hint: 'Enter your password',
                          prefixIcon: Icons.lock_outline,
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          validator: _validatePassword,
                          enabled: !widget.authProvider.isLoading,
                        ),
                        const SizedBox(height: 24),

                        // Sign In Action Button
                        FilledButton(
                          onPressed: widget.authProvider.isLoading ? null : _submit,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: widget.authProvider.isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  _selectedRole == UserRole.admin
                                      ? 'Sign In as Manager'
                                      : 'Sign In as Driver',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
