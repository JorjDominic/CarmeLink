import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile and web navigation remain explicitly separated', () {
    final source =
        File('lib/core/widgets/adaptive_shell.dart').readAsStringSync();

    expect(
      source.contains('CarmeLinkSurfaceScope.isWebPortal(context)'),
      isTrue,
    );
    expect(source.contains('bottomNavigationBar: null'), isTrue);
    expect(source.contains('_FloatingIslandNavigation('), isTrue);
  });

  test('floating navigation is solid rather than glass', () {
    final source =
        File('lib/core/widgets/adaptive_shell.dart').readAsStringSync();

    expect(source.contains('BackdropFilter('), isFalse);
    expect(source.contains('ImageFilter.blur('), isFalse);
    expect(source.contains('color: scheme.surface'), isTrue);
  });
}
