import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tenant and staff profile expose move-out workflow', () {
    final shared =
        File('lib/views/shared/shared_views.dart').readAsStringSync();
    final page = File('lib/views/shared/move_out_settlement_page.dart')
        .readAsStringSync();

    expect(shared.contains("import 'move_out_settlement_page.dart';"), isTrue);
    expect(shared.contains('Move-out notice & settlement'), isTrue);
    expect(shared.contains('Move-out & settlement'), isTrue);
    expect(shared.contains("nav.selectLabel('Move-out & settlement')"), isTrue);
    expect(page.contains("key: const Key('phase8-submit-notice')"), isTrue);
    expect(page.contains("key: const Key('phase8-schedule-final-inspection')"),
        isTrue);
    expect(page.contains("key: const Key('phase8-add-deduction')"), isTrue);
    expect(page.contains("key: const Key('phase8-record-settlement-outcome')"),
        isTrue);
    expect(page.contains("key: const Key('phase8-ready-for-closure')"), isTrue);
    expect(page.contains("key: const Key('phase8-acknowledge-settlement')"),
        isTrue);
    expect(page.contains('Jorj-reviewed'), isFalse);
  });

  test('staff web sidebar exposes move-out and listens to phase8 tables', () {
    final source = File(
      'lib/web/dashboard/staff_web_portal_shell.dart',
    ).readAsStringSync();
    expect(source.contains("label: 'Move-out & settlement'"), isTrue);
    expect(source.contains("page: MoveOutSettlementPage()"), isTrue);
    for (final table in [
      'move_out_cases',
      'move_out_clearance_items',
      'move_out_deductions',
      'move_out_settlements',
    ]) {
      expect(source.contains("'$table'"), isTrue, reason: table);
    }
  });
}
