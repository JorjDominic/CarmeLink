import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';

void main() {
  test('configured concern keeps original details separate from specific concern', () {
    final report = ConcernReport.fromRow({
      'id': 'report-1',
      'tenant_id': 'tenant-1',
      'category': 'other',
      'report_type_label': 'Other',
      'specific_concern': 'Noise complaint',
      'summary': 'The report details remain unchanged and auditable.',
      'status': 'submitted',
      'response_notes': '',
      'created_at': '2026-10-07T00:00:00Z',
    });

    expect(report.category, 'Other');
    expect(report.specificConcern, 'Noise complaint');
    expect(
      report.summary,
      'The report details remain unchanged and auditable.',
    );
  });

  test('legacy concern still derives a readable category', () {
    final report = ConcernReport.fromRow({
      'id': 'report-2',
      'tenant_id': 'tenant-1',
      'category': 'rule_violation',
      'summary': 'Legacy report remains readable after migration.',
      'status': 'under_review',
      'created_at': '2026-10-07T00:00:00Z',
    });

    expect(report.category, 'Rule Violation');
    expect(report.specificConcern, isEmpty);
  });
}
