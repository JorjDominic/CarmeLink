import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UI Phase 2 final contract', () {
    test('glassmorphism is removed from production UI surfaces', () {
      const files = [
        'lib/core/widgets/adaptive_shell.dart',
        'lib/core/widgets/common_widgets.dart',
        'lib/views/auth/auth_views.dart',
        'lib/views/shared/staff_quick_panel.dart',
        'lib/web/auth/staff_access_page.dart',
        'lib/web/dashboard/widgets/staff_workspace_chrome.dart',
      ];

      for (final path in files) {
        final source = File(path).readAsStringSync();
        expect(
          source.contains('CarmeLinkGlassSurface'),
          isFalse,
          reason: '$path still references CarmeLinkGlassSurface',
        );
        expect(
          source.contains('BackdropFilter('),
          isFalse,
          reason: '$path still contains a backdrop blur',
        );
      }
    });

    test('hamburger is web-only and uses the Material menu-close morph', () {
      final source =
          File('lib/core/widgets/adaptive_shell.dart').readAsStringSync();

      expect(
        source.contains('CarmeLinkSurfaceScope.isWebPortal(context)'),
        isTrue,
      );
      expect(
        source.contains(
          'webPortal && MediaQuery.sizeOf(context).width >= 1200',
        ),
        isTrue,
      );
      expect(source.contains('AnimatedIcons.menu_close'), isTrue);
      expect(source.contains('web-responsive-hamburger'), isTrue);
    });

    test('mobile floating navigation remains solid and floating', () {
      final source =
          File('lib/core/widgets/adaptive_shell.dart').readAsStringSync();

      expect(source.contains('fit: StackFit.expand'), isTrue);
      expect(source.contains('child: _FloatingIslandNavigation('), isTrue);
      expect(source.contains('BackdropFilter('), isFalse);
      expect(source.contains('color: scheme.surface'), isTrue);
    });

    test('mobile sign-in stays icon-led without Email/Password labels', () {
      final source = File('lib/views/auth/auth_views.dart').readAsStringSync();

      final signInStart = source.indexOf('class SignInPage');
      final nextClassStart = source.indexOf(
        'class EmailVerificationCodePage',
        signInStart,
      );

      expect(signInStart, greaterThanOrEqualTo(0));
      expect(nextClassStart, greaterThan(signInStart));

      final signIn = source.substring(signInStart, nextClassStart);

      expect(signIn.contains("labelText: 'Email"), isFalse);
      expect(signIn.contains("labelText: 'Password"), isFalse);
      expect(signIn.contains('Icons.mail_outline'), isTrue);
      expect(signIn.contains('Icons.lock_outline'), isTrue);
    });

    test('dark theme explicitly uses warm Material surfaces', () {
      final source = File('lib/core/theme/app_theme.dart').readAsStringSync();

      expect(source.contains('surfaceContainerLowest:'), isTrue);
      expect(source.contains('surfaceContainerHighest:'), isTrue);
      expect(source.contains('0xFF151310'), isTrue);
      expect(source.contains('0xFF211D19'), isTrue);
      expect(source.contains('Colors.blue'), isFalse);
    });

    test('theme transition is controlled by the mobile MaterialApp', () {
      final source = File('lib/app.dart').readAsStringSync();

      expect(source.contains('themeMode: themeController.themeMode'), isTrue);
      expect(source.contains('themeAnimationDuration:'), isTrue);
      expect(source.contains('themeAnimationCurve:'), isTrue);
    });

    test('settings sign-out waits for auth before navigation reset', () {
      final source =
          File('lib/views/shared/shared_views.dart').readAsStringSync();

      expect(
        source.contains('await SessionController.instance.signOut();'),
        isTrue,
      );
      expect(source.contains('Sign-out failed. Please retry.'), isTrue);
    });

    test('Phase 3 to 5 tools remain discoverable', () {
      final owner = File('lib/views/owner/owner_pages.dart').readAsStringSync();
      final staff = File(
        'lib/web/dashboard/staff_web_portal_shell.dart',
      ).readAsStringSync();

      for (final label in [
        'Cleaning',
        'Inspections',
        'Visitors',
        'Conduct & cases',
        'Employee curfew',
        'Security & retention',
      ]) {
        expect(
          owner.contains(label) || staff.contains(label),
          isTrue,
          reason: 'Missing discoverability for $label',
        );
      }
    });
  });
}
