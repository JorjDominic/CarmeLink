import 'dart:async';

import 'package:flutter/material.dart';

import 'controllers/session_controller.dart';
import 'core/config/supabase_config.dart';
import 'web/app/carmelink_web_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Public pages remain available if the staff authentication service fails.
  var authReady = false;
  try {
    await SupabaseConfig.initialize().timeout(const Duration(seconds: 10));
    authReady = true;
  } catch (error) {
    debugPrint('Web authentication initialization failed: $error');
  }

  runApp(CarmeLinkWebApp(authReady: authReady));
  if (authReady) {
    unawaited(
      SessionController.instance.initialize(
        passwordRecoveryRequested:
            SessionController.isPasswordRecoveryUri(Uri.base),
      ),
    );
  }
}
