import 'package:flutter/material.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_text_field.dart';

/// Driver self-registration. Manager and admin accounts are created by an
/// administrator and cannot be registered here.
class RegisterScreen extends StatefulWidget {
  final AuthProvider authProvider;

  const RegisterScreen({super.key, required this.authProvider});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validateName(String? v) =>
      (v == null || v.trim().length < 2) ? 'Full name is required' : null;

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    if (!RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(v.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePhone(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    return RegExp(r'^[+\d][\d\s-]{6,}$').hasMatch(v.trim())
        ? null
        : 'Enter a valid phone number';
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  String? _validateConfirm(String? v) =>
      v != _passwordController.text ? 'Passwords do not match' : null;

  Future<void> _submit() async {
    widget.authProvider.clearError();
    if (!_formKey.currentState!.validate()) return;
    final ok = await widget.authProvider.registerDriver(
      email: _emailController.text,
      password: _passwordController.text,
      displayName: _nameController.text,
      phone: _phoneController.text,
    );
    if (ok && mounted) {
      // The auth gate shows the driver home once the session is bound.
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Driver Sign Up'), centerTitle: true),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: ListenableBuilder(
                listenable: widget.authProvider,
                builder: (context, _) {
                  final loading = widget.authProvider.isLoading;
                  final error = widget.authProvider.errorMessage;
                  return Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Create a driver account',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 6),
                        Text(
                          'Manager and admin accounts are created by an administrator.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 18),
                        if (error != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              border: Border.all(color: Colors.red.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(error,
                                style: TextStyle(color: Colors.red.shade900)),
                          ),
                          const SizedBox(height: 16),
                        ],
                        CustomTextField(
                          controller: _nameController,
                          label: 'Full Name',
                          prefixIcon: Icons.person_outline,
                          validator: _validateName,
                          enabled: !loading,
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _emailController,
                          label: 'Email Address',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: _validateEmail,
                          enabled: !loading,
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _phoneController,
                          label: 'Phone (optional)',
                          prefixIcon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          validator: _validatePhone,
                          enabled: !loading,
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _passwordController,
                          label: 'Password',
                          prefixIcon: Icons.lock_outline,
                          obscureText: _obscure,
                          suffixIcon: IconButton(
                            icon: Icon(_obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                          validator: _validatePassword,
                          enabled: !loading,
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _confirmController,
                          label: 'Confirm Password',
                          prefixIcon: Icons.lock_outline,
                          obscureText: _obscure,
                          validator: _validateConfirm,
                          enabled: !loading,
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: loading ? null : _submit,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Text('Create Account',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
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
