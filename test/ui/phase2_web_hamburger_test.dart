import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 2 responsive web hamburger', () {
    test('desktop sidebar starts at 1200 logical pixels', () {
      final source =
          File('lib/core/widgets/adaptive_shell.dart').readAsStringSync();

      expect(
        source.contains(
          'webPortal && MediaQuery.sizeOf(context).width >= 1200',
        ),
        isTrue,
      );
    });

    test('phone and tablet web get a guaranteed compact header', () {
      final source =
          File('lib/core/widgets/adaptive_shell.dart').readAsStringSync();

      expect(
        source.contains('class _CompactWebNavigationBar'),
        isTrue,
      );
      expect(
        source.contains("Key('compact-web-navigation-bar')"),
        isTrue,
      );
      expect(
        source.contains("Key('web-responsive-hamburger')"),
        isTrue,
      );
    });

    test('hamburger uses the standard Material menu-close morph', () {
      final source =
          File('lib/core/widgets/adaptive_shell.dart').readAsStringSync();

      expect(source.contains('AnimatedIcons.menu_close'), isTrue);
      expect(source.contains('AnimationController('), isTrue);
      expect(source.contains('Curves.easeInOutCubic'), isTrue);
    });

    test('drawer still slides in from the left', () {
      final source =
          File('lib/core/widgets/adaptive_shell.dart').readAsStringSync();

      expect(source.contains('showGeneralDialog<void>('), isTrue);
      expect(source.contains('SlideTransition('), isTrue);
      expect(source.contains('Offset(-1.06, 0)'), isTrue);
    });

    test('mobile does not receive the web compact header', () {
      final source =
          File('lib/core/widgets/adaptive_shell.dart').readAsStringSync();

      expect(
        RegExp(r'body:\s*webPortal\s*\?\s*desktopWeb').hasMatch(source),
        isTrue,
      );
      expect(source.contains(': Stack('), isTrue);
      expect(source.contains('_FloatingIslandNavigation('), isTrue);
    });

    test('PageFrame no longer owns the responsive web hamburger', () {
      final source =
          File('lib/core/widgets/common_widgets.dart').readAsStringSync();

      expect(source.contains('showWebMenu'), isFalse);
      expect(source.contains('web-responsive-hamburger'), isFalse);
    });
  });
}
