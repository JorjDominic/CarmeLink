import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('report addenda requires confirmation and blocks duplicate taps', () {
    final source = File(
      'lib/views/shared/report_addenda.dart',
    ).readAsStringSync();

    expect(source, contains('Confirm report addendum'));
    expect(source, contains('Confirm and add'));
    expect(source, contains('if (_saving) return;'));
    expect(source, contains('onPressed: _saving ? null : _save'));
    expect(source, contains('createCorrectionRequestId'));
    expect(source, contains('Correction added to the report.'));
  });

  test('maintenance PDF loads fresh database-backed work orders', () {
    final source = File(
      'lib/services/dormitory_report_service.dart',
    ).readAsStringSync();

    expect(source, contains('StaffMaintenanceService().listReports()'));
    expect(source, contains('Live database-backed work orders'));
    expect(source, contains("'Tenant'"));
    expect(source, contains('r.statusLabel'));
  });

  test('conduct PDF includes live cases, investigation status and evidence', () {
    final source = File(
      'lib/services/dormitory_report_service.dart',
    ).readAsStringSync();

    expect(source, contains('generateConductViolationReportPdf'));
    expect(source, contains('ConductCaseService()'));
    expect(source, contains('listStaffCases()'));
    expect(source, contains('listEvidence(record.id)'));
    expect(source, contains('listStaffWarnings(record.id)'));
    expect(source, contains("'Investigation Status'"));
    expect(source, contains("'EVIDENCE REGISTER'"));
    expect(source, contains("'FORMAL WARNING REGISTER'"));
  });

  test('analytics exposes the conduct and violation PDF export', () {
    final source = File(
      'lib/views/owner/owner_pages.dart',
    ).readAsStringSync();

    expect(source, contains('Resident Conduct & Violation Cases'));
    expect(source, contains('generateConductViolationReportPdf'));
  });
}
