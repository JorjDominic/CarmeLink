import 'package:carmelitas_dormitory_system/core/utils/room_inspection_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('room inspection policy', () {
    final now = DateTime(2026, 9, 24, 8);

    test('monthly inspection under three days is rejected', () {
      final scheduled = now.add(const Duration(days: 2, hours: 23));
      expect(
        validateMonthlyInspectionSchedule(scheduled, now: now),
        isNotNull,
      );
    });

    test('monthly inspection exactly three days ahead is accepted', () {
      final scheduled = now.add(const Duration(days: 3));
      expect(
        validateMonthlyInspectionSchedule(scheduled, now: now),
        isNull,
      );
    });

    test('past inspection schedule is rejected', () {
      expect(
        validateMonthlyInspectionSchedule(
          now.subtract(const Duration(minutes: 1)),
          now: now,
        ),
        isNotNull,
      );
    });

    test('written notice must be meaningful', () {
      expect(validateInspectionNotice('no'), isNotNull);
      expect(
        validateInspectionNotice(
          'Monthly inspection is scheduled for this room.',
        ),
        isNull,
      );
    });

    test('finding description must be meaningful', () {
      expect(validateInspectionFindingDescription('bad'), isNotNull);
      expect(
        validateInspectionFindingDescription(
          'Loose bed-frame bolt observed near the upper bunk.',
        ),
        isNull,
      );
    });

    test('inspection labels are readable', () {
      expect(inspectionTypeLabel('follow_up'), 'Follow-up');
      expect(inspectionStatusLabel('in_progress'), 'In progress');
      expect(findingStatusLabel('corrected'), 'Corrected');
    });

    test('title case helper supports underscored values', () {
      expect(titleCaseInspectionValue('follow_up'), 'Follow Up');
    });
  });
}
