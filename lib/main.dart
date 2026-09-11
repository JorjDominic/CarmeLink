import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/config/supabase_config.dart';
import 'controllers/session_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await SupabaseConfig.initialize().timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint('Supabase initialize error or timeout: $e');
  }

  runApp(const CarmelitaBootstrap());

  unawaited(SessionController.instance.initialize());
}
