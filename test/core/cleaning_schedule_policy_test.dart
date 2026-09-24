import 'package:carmelitas_dormitory_system/core/utils/cleaning_schedule_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('cleaning schedule policy', () {
    test('weekday labels use Monday through Sunday', () {
      expect(cleaningWeekdayLabel(1), 'Monday');
      expect(cleaningWeekdayLabel(7), 'Sunday');
      expect(cleaningWeekdayShort(3), 'Wed');
    });

    test('invalid weekday returns safe label', () {
      expect(cleaningWeekdayLabel(0), 'Unknown day');
      expect(cleaningWeekdayLabel(8), 'Unknown day');
    });

    test('normalizes duplicate and unordered weekdays', () {
      expect(normalizeCleaningWeekdays([5, 1, 3, 1, 7]), [1, 3, 5, 7]);
    });

    test('drops unsupported weekday values', () {
      expect(normalizeCleaningWeekdays([0, 1, 8, 7]), [1, 7]);
    });

    test('rejects very short report details', () {
      expect(validateCleaningReportDescription('no'), isNotNull);
    });

    test('accepts useful report details', () {
      expect(
        validateCleaningReportDescription(
          'Assigned cleaning duty was not completed today.',
        ),
        isNull,
      );
    });

    test('rejects report details over 1500 characters', () {
      final tooLong = List.filled(1501, 'a').join();
      expect(validateCleaningReportDescription(tooLong), isNotNull);
    });
  });
}
