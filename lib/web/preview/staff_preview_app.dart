import 'package:flutter/material.dart';

import '../demo/demo_portal.dart';
import '../demo/demo_store.dart';
import '../demo/demo_ui.dart';
import '../theme/web_theme.dart';
import '../widgets/web_brand.dart';

/// Standalone access-screen test host. Actual local app starts on landing page.
class StaffPreviewApp extends StatelessWidget {
  const StaffPreviewApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'CarmeLink | Local staff demonstration',
    theme: WebTheme.light(),
    debugShowCheckedModeBanner: false,
    home: const StaffPreviewPage(),
  );
}

/// Local demo selector. Does not create a Supabase session or credentials.
class StaffPreviewPage extends StatelessWidget {
  const StaffPreviewPage({super.key, this.store});
  final DemoStore? store;

  void _open(BuildContext context, String role) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => DemoPortal(role: role, store: store)));
  }

  Widget _accessContent(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      const Align(alignment: Alignment.centerLeft, child: DemoBadge()),
      const SizedBox(height: 22),
      const Text('Preview the staff portal.',
        style: TextStyle(fontWeight: FontWeight.w800,
          color: WebPalette.ink, fontSize: 33, letterSpacing: -1)),
      const SizedBox(height: 10),
      const Text('Explore the mobile staff operations with fictional local records, in a desktop-friendly interface.',
        style: TextStyle(color: WebPalette.muted, height: 1.5)),
      const SizedBox(height: 24),
      const _DemoNotice(),
      const SizedBox(height: 22),
      FilledButton.icon(key: const Key('preview-owner'),
        onPressed: () => _open(context, 'Owner'),
        icon: const Icon(Icons.admin_panel_settings_outlined),
        label: const Text('Preview as Owner')),
      const SizedBox(height: 12),
      OutlinedButton.icon(key: const Key('preview-caretaker'),
        onPressed: () => _open(context, 'Caretaker'),
        icon: const Icon(Icons.manage_accounts_outlined),
        label: const Text('Preview as Caretaker')),
      const SizedBox(height: 17),
      const Text('No password required. Demo accounts cannot access live data. Edits reset when you reload.',
        textAlign: TextAlign.center,
        style: TextStyle(color: WebPalette.muted, fontSize: 12)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 850;
    return Scaffold(
      appBar: AppBar(toolbarHeight: 80,
        leading: Navigator.of(context).canPop()
          ? IconButton(tooltip: 'Back to website',
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop()) : null,
        title: const WebBrand(compact: true),
        actions: const [Padding(padding: EdgeInsets.only(right: 18),
          child: Center(child: Text('SAMPLE DATA',
            style: TextStyle(fontSize: 10, letterSpacing: 1.1,
              color: WebPalette.muted, fontWeight: FontWeight.w700))))],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1140),
            child: DemoSectionCard(padding: EdgeInsets.zero,
              child: ClipRRect(borderRadius: BorderRadius.circular(22),
                child: Flex(direction: compact ? Axis.vertical : Axis.horizontal,
                  children: [
                    SizedBox(width: compact ? double.infinity : 440,
                      height: compact ? 170 : 570,
                      child: Stack(fit: StackFit.expand, children: [
                        Image.asset('assets/web/photos/courtyard.jpg',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) =>
                            const ColoredBox(color: WebPalette.plum)),
                        ColoredBox(color: WebPalette.ink.withValues(alpha: .55)),
                        const Positioned(left: 32, right: 32, bottom: 30,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min, children: [
                              Text('A BETTER WAY TO MANAGE',
                                style: TextStyle(color: Colors.white70,
                                  fontSize: 10, letterSpacing: 1.7,
                                  fontWeight: FontWeight.w800)),
                              SizedBox(height: 8),
                              Text('Your dormitory, in focus.',
                                style: TextStyle(color: Colors.white,
                                  fontSize: 29, fontWeight: FontWeight.w800)),
                            ])),
                      ])),
                    if (compact)
                      Padding(padding: const EdgeInsets.all(25),
                        child: _accessContent(context))
                    else
                      Expanded(child: Padding(
                        padding: const EdgeInsets.all(48),
                        child: _accessContent(context))),
                  ]))),
          ),
        ),
      ),
    );
  }
}

class _DemoNotice extends StatelessWidget {
  const _DemoNotice();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: WebPalette.sand,
      borderRadius: BorderRadius.circular(14)),
    child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.info_outline, color: WebPalette.plum, size: 21),
      SizedBox(width: 10),
      Expanded(child: Text('Functional CRUD demonstration · No Supabase · No emails, SMS, payments, GPS or notifications are actually sent.',
        style: TextStyle(color: WebPalette.ink, fontSize: 12, height: 1.45))),
    ]),
  );
}
