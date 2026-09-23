import 'package:carmelitas_dormitory_system/core/utils/employee_curfew_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('employee curfew policy', () {
    test('weekday validation requires at least one valid weekday', () {
      expect(validateEmployeeCurfewWeekdays(const []), isNotNull);
      expect(validateEmployeeCurfewWeekdays(const [0, 1]), isNotNull);
      expect(validateEmployeeCurfewWeekdays(const [1, 3, 5]), isNull);
    });

    test('effective end date cannot be before start date', () {
      final start = DateTime(2026, 9, 24);
      expect(
        validateEmployeeCurfewEffectiveDates(
          start,
          DateTime(2026, 9, 23),
        ),
        isNotNull,
      );
      expect(
        validateEmployeeCurfewEffectiveDates(
          start,
          DateTime(2026, 10, 24),
        ),
        isNull,
      );
    });

    test('work note must contain useful detail', () {
      expect(validateEmployeeCurfewWorkNote('job'), isNotNull);
      expect(
        validateEmployeeCurfewWorkNote(
          'Evening shift ends after the standard dormitory curfew.',
        ),
        isNull,
      );
    });

    test('time SQL and display conversion are stable', () {
      expect(employeeCurfewTimeSql(23 * 60 + 30), '23:30:00');
      expect(employeeCurfewMinutesFromSql('23:30:00'), 23 * 60 + 30);
      expect(employeeCurfewTimeLabel(23 * 60 + 30), '11:30 PM');
    });

    test('approved profile is effective only on configured weekday/date', () {
      expect(
        employeeCurfewProfileIsEffectiveOn(
          status: 'approved',
          weekdays: const [1, 3, 5],
          effectiveFrom: DateTime(2026, 9, 1),
          effectiveUntil: DateTime(2026, 10, 31),
          at: DateTime(2026, 9, 25),
        ),
        isTrue,
      );

      expect(
        employeeCurfewProfileIsEffectiveOn(
          status: 'approved',
          weekdays: const [1, 3, 5],
          effectiveFrom: DateTime(2026, 9, 1),
          effectiveUntil: DateTime(2026, 10, 31),
          at: DateTime(2026, 9, 26),
        ),
        isFalse,
      );
    });

    test('draft and revoked profiles are never effective', () {
      for (final status in ['draft', 'revoked']) {
        expect(
          employeeCurfewProfileIsEffectiveOn(
            status: status,
            weekdays: const [1, 2, 3, 4, 5, 6, 7],
            effectiveFrom: DateTime(2026, 1, 1),
            at: DateTime(2026, 9, 24),
          ),
          isFalse,
        );
      }
    });

    test('weekday labels are stable', () {
      expect(employeeCurfewWeekdayLabel(1), 'Mon');
      expect(employeeCurfewWeekdayLabel(7), 'Sun');
    });
  });
}
