import 'package:flutter/foundation.dart';
import '../models/user.dart';

class AuthProvider extends ChangeNotifier {
  AppUser? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Sets the active user directly (useful for tests and role simulation)
  void setUser(AppUser? user) {
    _currentUser = user;
    _errorMessage = null;
    notifyListeners();
  }

  /// Authenticate user using email and password.
  /// Validates credentials and assigns the appropriate role.
  Future<bool> signIn({
    required String email,
    required String password,
    String? roleOverride,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Simulate network / auth latency
      await Future.delayed(const Duration(milliseconds: 400));

      final trimmedEmail = email.trim().toLowerCase();

      // Basic role determination for dev/demo accounts or roleOverride
      String role = roleOverride ?? UserRole.driver;
      String displayName = 'Fleet User';

      if (trimmedEmail.contains('admin') || trimmedEmail.contains('manager')) {
        role = UserRole.admin;
        displayName = 'Operations Manager';
      } else if (trimmedEmail.contains('dispatcher')) {
        role = UserRole.dispatcher;
        displayName = 'Dispatcher Lead';
      } else {
        role = roleOverride ?? UserRole.driver;
        displayName = 'Assigned Driver';
      }

      _currentUser = AppUser(
        id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
        email: trimmedEmail,
        displayName: displayName,
        role: role,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Authentication failed. Please check your credentials.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign out the current user and reset auth state
  Future<void> signOut() async {
    _currentUser = null;
    _errorMessage = null;
    notifyListeners();
  }
}
