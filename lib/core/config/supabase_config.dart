import 'package:supabase_flutter/supabase_flutter.dart';

/// Central configuration and access point for the app's Supabase client.
abstract final class SupabaseConfig {
  static const String url = String.fromEnvironment('SUPABASE_URL',
      defaultValue: 'https://iuplkgvitovzjbmtzpme.supabase.co');
  static const String passwordRecoveryRedirectUrl = String.fromEnvironment(
    'PASSWORD_RECOVERY_REDIRECT_URL',
    defaultValue: 'https://carmelitasdormitory.site/reset-password',
  );
  static const String publishableKey = String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
      defaultValue: 'sb_publishable_b5D9jzxkduw55AJj3njOnQ_m1E7cxJP');

  static Future<void> initialize() async {
    if (const bool.hasEnvironment('SUPABASE_URL') !=
        const bool.hasEnvironment('SUPABASE_PUBLISHABLE_KEY')) {
      throw StateError(
          'Set both SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY for a custom project.');
    }
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
