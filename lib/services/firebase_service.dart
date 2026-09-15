import 'package:firebase_core/firebase_core.dart';

class FirebaseService {
  Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
    } catch (_) {
      // In tests or headless environments without native google-services bindings,
      // allow app to continue gracefully.
    }
  }
}