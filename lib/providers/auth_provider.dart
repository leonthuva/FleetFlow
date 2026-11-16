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
    if (data == null || !UserRole.all.contains(data['role']))
      throw StateError(
          'Your account has no approved role. Contact your administrator.');
    return AppUser.fromMap(data, documentId: doc.id);
  }

  Future<void> _bind(User? user) async {
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
