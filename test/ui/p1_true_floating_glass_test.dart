import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile floating navigation remains a true overlay', () {
    final source =
        File('lib/core/widgets/adaptive_shell.dart').readAsStringSync();

    expect(source.contains('bottomNavigationBar: null'), isTrue);
    expect(source.contains('fit: StackFit.expand'), isTrue);
    expect(source.contains('Positioned('), isTrue);
    expect(source.contains('child: _FloatingIslandNavigation('), isTrue);
  });

  test('the floating island no longer uses glass blur', () {
    final source =
        File('lib/core/widgets/adaptive_shell.dart').readAsStringSync();

    expect(source.contains('BackdropFilter('), isFalse);
  });
}
