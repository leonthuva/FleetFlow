import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_config.dart';

class FirebaseProofTokenProvider {
  FirebaseProofTokenProvider({FirebaseAuth? auth}) : _auth = auth;
  final FirebaseAuth? _auth;
  Future<String> token({bool forceRefresh = false}) async {
    final user = (_auth ?? FirebaseAuth.instance).currentUser;
    if (user == null) {
      throw StateError('Sign in before accessing proof storage.');
    }
    final result = await user.getIdTokenResult(forceRefresh);
    if (result.claims?['role'] != 'authenticated') {
      throw StateError(
          'Your account needs the approved Supabase authentication claim. Ask an administrator to provision it, then sign out and sign in again.');
    }
    final token = result.token;
    if (token == null || token.isEmpty) {
      throw StateError('Firebase did not provide an ID token.');
    }
    return token;
  }
}

class SupabaseService {
  static Future<void> initialize() async {
    if (!AppConfig.proofStorageConfigured) return;
    final uri = Uri.tryParse(AppConfig.supabaseUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        !uri.host.endsWith('.supabase.co') ||
        uri.path.isNotEmpty && uri.path != '/') {
      throw StateError('SUPABASE_URL must be an HTTPS Supabase project URL.');
    }
    if (!AppConfig.supabasePublishableKey.startsWith('sb_publishable_')) {
      throw StateError(
          'Configure a Supabase publishable key; privileged server keys are never accepted in the app.');
    }
    await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        publishableKey: AppConfig.supabasePublishableKey,
        debug: false,
        accessToken: () async =>
            FirebaseAuth.instance.currentUser?.getIdToken());
  }
}
