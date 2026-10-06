import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tenant report choices refresh when owner configuration changes', () {
    final source =
        File('lib/views/tenant/tenant_pages.dart').readAsStringSync();

    expect(source, contains("'tenant-maintenance-options'"));
    expect(source, contains("const ['dormitory_options']"));
    expect(source, contains("'tenant-concern-options'"));
    expect(source, contains("options('maintenance_category')"));
    expect(source, contains("options('common_area')"));
    expect(source, contains("options('report_type')"));
  });

  test('PDF actions explain what the preview can do', () {
    final source = File('lib/views/owner/owner_pages.dart').readAsStringSync();

    expect(source, contains('Print / Download PDF'));
    expect(
      source,
      contains(
          'Open a PDF preview to print, download, or share where supported.'),
    );
  });

  test('visitor schedule changes require confirmation and are shared by roles',
      () {
    final editor = File(
      'lib/views/shared/visitor_schedule_editor.dart',
    ).readAsStringSync();
    final tenant =
        File('lib/views/tenant/tenant_pages.dart').readAsStringSync();
    final staff = File('lib/views/owner/owner_pages.dart').readAsStringSync();

    expect(editor, contains('Confirm schedule change?'));
    expect(editor, contains('Confirm change'));
    expect(editor, contains('Keep current approval'));
    expect(editor, contains('Reason for schedule change'));
    expect(tenant, contains('editVisitorSchedule('));
    expect(staff, contains('staffCanKeepApproval: true'));
  });

  test('visitor workflow has audited rescheduling and no automatic checkout',
      () {
    final migration = File(
      'supabase/migrations/202610070008_phase3_dynamic_options_and_visitor_workflow.sql',
    ).readAsStringSync();

    expect(migration, contains("'rescheduled'"));
    expect(migration, contains('approval_retained'));
    expect(migration, contains("'departure_unconfirmed'"));
    expect(migration, contains("'visitor-reminders'"));
    expect(migration, contains("'server_push', true"));
    expect(migration, isNot(contains("set status = 'completed'")));
  });
}
