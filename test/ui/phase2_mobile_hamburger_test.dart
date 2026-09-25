import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 2 mobile hamburger', () {
    test('mobile top-level pages restore the normal hamburger', () {
      final source =
          File('lib/core/widgets/common_widgets.dart').readAsStringSync();

      expect(
        source.contains(
          'final showMobileMenu = !webPortal && navScope != null;',
        ),
        isTrue,
      );
      expect(source.contains("Key('mobile-hamburger-menu')"), isTrue);
      expect(source.contains('Icons.menu_rounded'), isTrue);
      expect(source.contains('onPressed: navScope.openMenu'), isTrue);
    });

    test('mobile hamburger is explicitly excluded from production web', () {
      final source =
          File('lib/core/widgets/common_widgets.dart').readAsStringSync();

      expect(source.contains('!webPortal && navScope != null'), isTrue);
    });

    test('narrow web keeps its separate animated hamburger', () {
      final source =
          File('lib/core/widgets/adaptive_shell.dart').readAsStringSync();

      expect(source.contains("Key('web-responsive-hamburger')"), isTrue);
      expect(source.contains('AnimatedIcons.menu_close'), isTrue);
      expect(
        source.contains(
          'webPortal && MediaQuery.sizeOf(context).width >= 1200',
        ),
        isTrue,
      );
    });
  });
}
