import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'web/demo/demo_store.dart';
import 'web/demo/demo_ui.dart';
import 'web/landing/landing_page.dart';
import 'web/preview/staff_preview_app.dart';
import 'web/theme/web_theme.dart';

/// Debug-only, isolated demonstration. Production still uses main_web.dart.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('CARMELINK_LOCAL_PREVIEW');
  if (!kDebugMode || !enabled) {
    runApp(const MaterialApp(home: Scaffold(
      body: Center(child: Text('Local preview is disabled.')))));
    return;
  }
  runApp(const CarmeLinkLocalDemoApp());
}

/// Public landing is ALWAYS first. Both pages use the same in-memory fixture.
class CarmeLinkLocalDemoApp extends StatefulWidget {
  const CarmeLinkLocalDemoApp({super.key});

  @override
  State<CarmeLinkLocalDemoApp> createState() => _CarmeLinkLocalDemoAppState();
}

class _CarmeLinkLocalDemoAppState extends State<CarmeLinkLocalDemoApp> {
  final DemoStore _store = DemoStore();

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'CarmeLink | Local website demo',
    theme: WebTheme.light(),
    debugShowCheckedModeBanner: false,
    initialRoute: '/',
    routes: {
      '/': (context) => Stack(children: [
        LandingPage(
          onStaffPortal: () => Navigator.of(context).pushNamed('/staff')),
        Positioned(right: 18, bottom: 22, child: SafeArea(
          child: FloatingActionButton.extended(
            heroTag: 'local-demo-inquiry',
            tooltip: 'Try a fictional inquiry without sending it',
            onPressed: () => showDialog<void>(context: context,
              builder: (_) => DemoPublicInquiryDialog(store: _store)),
            icon: const Icon(Icons.edit_note_outlined),
            label: const Text('Try demo inquiry'),
          ),
        )),
      ]),
      '/staff': (context) => StaffPreviewPage(store: _store),
    },
  );
}
