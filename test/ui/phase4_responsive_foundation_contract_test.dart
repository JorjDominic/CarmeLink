import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 4 responsive foundation contract', () {
    test('shared breakpoints protect narrow layouts', () {
      final source = File(
        'lib/core/responsive/breakpoints.dart',
      ).readAsStringSync();

      expect(source.contains('columnsForMinTileWidth'), isTrue);
      expect(source.contains('estimated.clamp(1, maxColumns)'), isTrue);
      expect(source.contains('if (value < extraSmall) return 12;'), isTrue);
      expect(source.contains('if (value < phone) return 16;'), isTrue);
    });

    test('shared grids adapt to width and text scale', () {
      final source = File(
        'lib/core/widgets/common_widgets.dart',
      ).readAsStringSync();

      expect(source.contains('AppBreakpoints.columnsForMinTileWidth('), isTrue);
      expect(source.contains('textScale >= 1.35'), isTrue);
      expect(source.contains('width < 600'), isTrue);
      expect(source.contains('width < 1024'), isTrue);
    });

    test('web pages do not reserve mobile bottom-navigation space', () {
      final source = File(
        'lib/core/widgets/common_widgets.dart',
      ).readAsStringSync();

      expect(
        RegExp(
          r'navScope\s*==\s*null\s*\?\s*24\.0\s*:\s*\(webPortal\s*\?\s*32\.0\s*:\s*132\.0\)',
        ).hasMatch(source),
        isTrue,
      );
      expect(
        RegExp(
          r'resolvedFloatingActionButton\s*!=\s*null\s*&&\s*navScope\s*!=\s*null\s*&&\s*!webPortal',
        ).hasMatch(source),
        isTrue,
      );
    });

    test('responsive system matrix covers Phase 4 target widths', () {
      final source = File(
        'test/responsive_system_matrix_test.dart',
      ).readAsStringSync();

      for (final width in ['320', '375', '768', '1024', '1440']) {
        expect(source.contains("'$width"), isTrue, reason: 'Missing $width px');
      }
    });
  });
}
