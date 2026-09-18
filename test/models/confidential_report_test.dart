import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConcernReport', () {
    test('parses tenant database row and formats labels', () {
      final report = ConcernReport.fromRow({
        'id': 'report-1',
        'tenant_id': 'tenant-1',
        'category': 'roommate_concern',
        'summary': 'Repeated threatening behavior in the room.',
        'status': 'under_review',
        'response_notes': null,
        'created_at': '2026-09-19T01:00:00Z',
        'reviewed_at': null,
      });

      expect(report.id, 'report-1');
      expect(report.tenantId, 'tenant-1');
      expect(report.category, 'Roommate Concern');
      expect(report.status, 'Under Review');
      expect(report.summary, 'Repeated threatening behavior in the room.');
      expect(report.responseNotes, isEmpty);
      expect(report.isSubmitted, isFalse);
      expect(report.isResolved, isFalse);
    });

    test('recognizes submitted and resolved lifecycle states', () {
      final submitted = ConcernReport(
        id: 'one',
        category: 'Safety concern',
        summary: 'A sufficiently detailed confidential report.',
        status: 'Submitted',
        createdAt: DateTime(2026),
      );
      final resolved = ConcernReport(
        id: 'two',
        category: 'Safety concern',
        summary: 'A sufficiently detailed confidential report.',
        status: 'Resolved',
        createdAt: DateTime(2026),
      );

      expect(submitted.isSubmitted, isTrue);
      expect(resolved.isResolved, isTrue);
    });
  });
}
