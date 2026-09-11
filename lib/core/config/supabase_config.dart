import 'package:supabase_flutter/supabase_flutter.dart';

/// Central configuration and access point for the app's Supabase client.
abstract final class SupabaseConfig {
  static const String url = 'https://iuplkgvitovzjbmtzpme.supabase.co';
  static const String publishableKey =
      'sb_publishable_b5D9jzxkduw55AJj3njOnQ_m1E7cxJP';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: url,
      publishableKey: publishableKey,
    );
  }

  static bool get isInitialized {
    try {
      Supabase.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  static SupabaseClient? get clientSafe {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static SupabaseClient get client => Supabase.instance.client;
}
