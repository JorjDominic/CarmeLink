import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Phase 8 destination participates in existing web workspace restore',
      () {
    final shell = File(
      'lib/web/dashboard/staff_web_portal_shell.dart',
    ).readAsStringSync();
    final persistence = File(
      'lib/services/web_workspace_persistence_service.dart',
    ).readAsStringSync();
    final adaptive =
        File('lib/core/widgets/adaptive_shell.dart').readAsStringSync();
    final phase8 = File(
      'lib/views/shared/move_out_settlement_page.dart',
    ).readAsStringSync();

    expect(shell.contains("label: 'Move-out & settlement'"), isTrue);
    expect(persistence.contains('SharedPreferences'), isTrue);
    expect(persistence.contains('visiblePageLabel'), isTrue);
    expect(persistence.contains('saveDestination'), isTrue);
    expect(adaptive.contains('_restoreWebWorkspaceState'), isTrue);
    expect(adaptive.contains('_persistWorkspaceDestination'), isTrue);
    expect(adaptive.contains('visiblePageLabel'), isTrue);
    expect(phase8.contains('SharedPreferences'), isTrue);
    expect(phase8.contains('carmelink.phase8.selected_case'), isTrue);
    expect(phase8.contains('_selectedCaseId'), isTrue);
    expect(phase8.contains('_selectCase(record.id)'), isTrue);
    expect(phase8.contains('phase8-back-to-queue'), isTrue);

    final shared =
        File('lib/views/shared/shared_views.dart').readAsStringSync();
    expect(
      shared.contains("nav.selectLabel('Move-out & settlement')"),
      isTrue,
    );
  });
}
