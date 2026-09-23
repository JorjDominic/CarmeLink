import 'package:carmelitas_dormitory_system/core/utils/retention_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('retention policy configuration', () {
    test('blank retention days are allowed while policy is unresolved', () {
      expect(validateRetentionDays(''), isNull);
    });

    test('positive whole-number retention days are accepted', () {
      expect(validateRetentionDays('1'), isNull);
      expect(validateRetentionDays('365'), isNull);
    });

    test('zero, negative, and non-number values are rejected', () {
      expect(validateRetentionDays('0'), isNotNull);
      expect(validateRetentionDays('-5'), isNotNull);
      expect(validateRetentionDays('thirty'), isNotNull);
    });

    test('review labels are stable', () {
      expect(retentionReviewStatusLabel('draft'), 'Draft');
      expect(
        retentionReviewStatusLabel('pending_review'),
        'Pending review',
      );
      expect(retentionReviewStatusLabel('reviewed'), 'Reviewed');
    });

    test('review notes enforce the configured length boundary', () {
      expect(validateRetentionReviewNotes(''), isNull);
      expect(validateRetentionReviewNotes('a' * 4000), isNull);
      expect(validateRetentionReviewNotes('a' * 4001), isNotNull);
    });

    test('enforcement helper remains false when backend says disabled', () {
      expect(retentionEnforcementMayRun(false), isFalse);
    });
  });
}
