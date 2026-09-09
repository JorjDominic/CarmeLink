import 'package:flutter/material.dart';

import 'app.dart';
import 'core/config/supabase_config.dart';
import 'controllers/session_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();
  await SessionController.instance.initialize();
  runApp(const CarmelitaBootstrap());
}
