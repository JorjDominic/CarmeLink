import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Phase 2 chrome now uses solid surfaces', () {
    const files = [
      'lib/core/widgets/common_widgets.dart',
      'lib/views/auth/auth_views.dart',
      'lib/views/shared/staff_quick_panel.dart',
      'lib/web/auth/staff_access_page.dart',
      'lib/web/dashboard/widgets/staff_workspace_chrome.dart',
    ];

    for (final path in files) {
      final source = File(path).readAsStringSync();
      expect(source.contains('CarmeLinkGlassSurface'), isFalse);
    }
  });
}
