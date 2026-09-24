import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('responsive hamburger is production-web only', () {
    final source =
        File('lib/core/widgets/adaptive_shell.dart').readAsStringSync();

    expect(
      source.contains('CarmeLinkSurfaceScope.isWebPortal(context)'),
      isTrue,
    );
    expect(source.contains('MediaQuery.sizeOf(context).width >= 1200'), isTrue);
    expect(source.contains('AnimatedIcons.menu_close'), isTrue);
  });

  test('web drawer slides from the left using a solid Material surface', () {
    final source =
        File('lib/core/widgets/adaptive_shell.dart').readAsStringSync();

    expect(source.contains('showGeneralDialog<void>('), isTrue);
    expect(source.contains('SlideTransition('), isTrue);
    expect(source.contains('CarmeLinkGlassSurface'), isFalse);
  });
}
