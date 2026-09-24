import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/core/utils/visitor_policy.dart';

void main() {
  group('VisitorPolicy', () {
    final now = DateTime(2026, 9, 24, 23, 30);

    test('rejects same-calendar-day requests', () {
      final issue = VisitorPolicy.validateVisit(
        schedule: DateTime(2026, 9, 24, 10),
        expectedDepartureAt: DateTime(2026, 9, 24, 12),
        now: now,
      );

      expect(
        issue,
        'Visitor requests must be submitted at least one calendar day before the visit.',
      );
    });

    test('allows tomorrow even when less than 24 hours away', () {
      final issue = VisitorPolicy.validateVisit(
        schedule: DateTime(2026, 9, 25, 9),
        expectedDepartureAt: DateTime(2026, 9, 25, 10),
        now: now,
      );

      expect(issue, isNull);
    });

    test('rejects arrival before visiting hours', () {
      final issue = VisitorPolicy.validateVisit(
        schedule: DateTime(2026, 9, 25, 8, 59),
        expectedDepartureAt: DateTime(2026, 9, 25, 10),
        now: now,
      );

      expect(
        issue,
        'Expected arrival must be between 9:00 AM and before 9:00 PM.',
      );
    });

    test('accepts departure exactly at 9 PM', () {
      final issue = VisitorPolicy.validateVisit(
        schedule: DateTime(2026, 9, 25, 19),
        expectedDepartureAt: DateTime(2026, 9, 25, 21),
        now: now,
      );

      expect(issue, isNull);
    });

    test('rejects departure after 9 PM', () {
      final issue = VisitorPolicy.validateVisit(
        schedule: DateTime(2026, 9, 25, 19),
        expectedDepartureAt: DateTime(2026, 9, 25, 21, 1),
        now: now,
      );

      expect(issue, 'Expected departure must be no later than 9:00 PM.');
    });

    test('rejects overnight visits', () {
      final issue = VisitorPolicy.validateVisit(
        schedule: DateTime(2026, 9, 25, 19),
        expectedDepartureAt: DateTime(2026, 9, 26, 9),
        now: now,
      );

      expect(
        issue,
        'Visitors must depart on the same day. Overnight stays are not permitted.',
      );
    });

    test('rejects departure before arrival', () {
      final issue = VisitorPolicy.validateVisit(
        schedule: DateTime(2026, 9, 25, 14),
        expectedDepartureAt: DateTime(2026, 9, 25, 13),
        now: now,
      );

      expect(issue, 'Expected departure must be after the expected arrival.');
    });
  });
}
