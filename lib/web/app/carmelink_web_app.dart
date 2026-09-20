import 'package:flutter/material.dart';

import '../auth/staff_gate.dart';
import '../landing/landing_page.dart';
import '../theme/web_theme.dart';
import 'web_routes.dart';

/// Separate Flutter web application. Does not alter the mobile app's routing.
class CarmeLinkWebApp extends StatelessWidget {
  const CarmeLinkWebApp({super.key, this.authReady = true});

  final bool authReady;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CarmeLink | Carmelita Dormitory',
      debugShowCheckedModeBanner: false,
      theme: WebTheme.light(),
      initialRoute: WebRoutes.home,
      routes: {
        WebRoutes.home: (context) => LandingPage(
              onStaffPortal: () => Navigator.of(context).pushNamed(WebRoutes.staff),
            ),
        WebRoutes.staff: (context) => authReady
            ? const StaffGate()
            : const _StaffUnavailablePage(),
      },
      onUnknownRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (context) => const _NotFoundPage(),
      ),
    );
  }
}

class _NotFoundPage extends StatelessWidget {
  const _NotFoundPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Page not found', style: TextStyle(fontSize: 24)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                WebRoutes.home,
                (route) => false,
              ),
              child: const Text('Return to website'),
            ),
          ],
        ),
      ),
    );
  }
}


class _StaffUnavailablePage extends StatelessWidget {
  const _StaffUnavailablePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Staff portal')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 42),
              const SizedBox(height: 14),
              const Text(
                'Staff sign-in is temporarily unavailable. '
                'Please check the connection and reload the page.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                  WebRoutes.home,
                  (route) => false,
                ),
                child: const Text('Return to website'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
