import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth,
        _db = firestore;
  final FirebaseAuth? _auth;
  final FirebaseFirestore? _db;
  FirebaseAuth get auth => _auth ?? FirebaseAuth.instance;
  FirebaseFirestore get db => _db ?? FirebaseFirestore.instance;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _roleSubscription;
  int _generation = 0;
  bool _disposed = false;
  bool _registering = false;
  AppUser? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    _notify();
  }

  @visibleForTesting
  void setUser(AppUser? user) {
    _currentUser = user;
    _errorMessage = null;
    _notify();
  }

  void start() {
    _authSubscription ??= auth.authStateChanges().listen((user) {
      unawaited(_bind(user));
    }, onError: (Object e) {
      _currentUser = null;
      _errorMessage = 'Authentication session failed: $e';
      _notify();
    });
  }

  AppUser _parse(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null || !UserRole.all.contains(data['role'])) {
      throw StateError(
          'Your account has no approved role. Contact your administrator.');
    }
    return AppUser.fromMap(data, documentId: doc.id);
  }

  Future<void> _bind(User? user) async {
    // While registering, the role document does not exist yet. Skip the
    // auth-state callback so the user never sees a false "no approved role".
    if (_registering) return;
    final generation = ++_generation;
    await _roleSubscription?.cancel();
    _currentUser = null;
    if (user == null) {
      _isLoading = false;
      _notify();
      return;
    }
    _isLoading = true;
    _notify();
    try {
      final ref = db.collection('users').doc(user.uid);
      final doc = await ref.get();
      if (generation != _generation || _disposed) return;
      _currentUser = _parse(doc);
      _errorMessage = null;
      _roleSubscription = ref.snapshots().listen((doc) {
        if (generation != _generation || _disposed) return;
        try {
          _currentUser = _parse(doc);
          _errorMessage = null;
        } catch (e) {
          _currentUser = null;
          _errorMessage = e.toString();
        }
        _notify();
      }, onError: (Object e) {
        if (generation == _generation) {
          _currentUser = null;
          _errorMessage = 'Role verification failed: $e';
          _notify();
        }
      });
    } catch (e) {
      if (generation == _generation) {
        _currentUser = null;
        _errorMessage = e.toString();
      }
    } finally {
      if (generation == _generation) {
        _isLoading = false;
        _notify();
      }
    }
  }

  Future<bool> signIn({required String email, required String password}) async {
    _isLoading = true;
    _errorMessage = null;
    _notify();
    try {
      final credentials = await auth.signInWithEmailAndPassword(
          email: email.trim(), password: password);
      await _bind(credentials.user);
      return isAuthenticated;
    } on FirebaseAuthException catch (e) {
      _currentUser = null;
      _errorMessage = e.message ?? 'Sign in failed.';
      return false;
    } catch (e) {
      _currentUser = null;
      _errorMessage = 'Sign in failed: $e';
      return false;
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  /// Self-registration is limited to the `driver` role. Manager and admin
  /// accounts must be provisioned by an administrator; Firestore rules also
  /// reject any other role on create.
  Future<bool> registerDriver({
    required String email,
    required String password,
    required String displayName,
    String? phone,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _registering = true;
    _notify();
    User? created;
    try {
      final credentials = await auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password);
      created = credentials.user;
      if (created == null) throw StateError('Account was not created.');
      final cleanPhone = phone?.trim();
      await db.collection('users').doc(created.uid).set({
        'uid': created.uid,
        'email': email.trim(),
        'displayName': displayName.trim(),
        'role': UserRole.driver,
        if (cleanPhone != null && cleanPhone.isNotEmpty) 'phone': cleanPhone,
        'onShift': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _registering = false;
      await _bind(created);
      return isAuthenticated;
    } on FirebaseAuthException catch (e) {
      _currentUser = null;
      _errorMessage = _registrationMessage(e);
      return false;
    } catch (e) {
      // The account exists but its role document could not be saved (for
      // example permission denied). Remove it so no role-less login remains.
      _currentUser = null;
      _errorMessage = 'Could not finish registration: $e';
      try {
        await created?.delete();
      } catch (_) {
        await auth.signOut();
      }
      return false;
    } finally {
      _registering = false;
      _isLoading = false;
      _notify();
    }
  }

  String _registrationMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account already exists for this email. Sign in instead.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'operation-not-allowed':
        return 'Email/password sign-up is not enabled for this project.';
      default:
        return e.message ?? 'Registration failed.';
    }
  }

  Future<void> signOut() async {
    ++_generation;
    await _roleSubscription?.cancel();
    _currentUser = null;
    _notify();
    await auth.signOut();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _authSubscription?.cancel();
    _roleSubscription?.cancel();
    super.dispose();
  }
}
