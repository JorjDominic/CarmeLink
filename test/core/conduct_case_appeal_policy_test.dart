import 'package:carmelitas_dormitory_system/core/utils/conduct_case_appeal_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('conduct case appeal policy', () {
    test('only applicable conduct decisions allow appeal', () {
      expect(conductCaseAllowsAppeal('warning_issued'), isTrue);
      expect(conductCaseAllowsAppeal('resolved'), isTrue);
      expect(
        conductCaseAllowsAppeal('termination_review_recommended'),
        isTrue,
      );

      expect(conductCaseAllowsAppeal('draft'), isFalse);
      expect(conductCaseAllowsAppeal('awaiting_response'), isFalse);
      expect(conductCaseAllowsAppeal('under_review'), isFalse);
      expect(conductCaseAllowsAppeal('dismissed'), isFalse);
    });

    test('open appeal states are submitted and under review', () {
      expect(conductAppealIsOpen('submitted'), isTrue);
      expect(conductAppealIsOpen('under_review'), isTrue);
      expect(conductAppealIsOpen('accepted'), isFalse);
      expect(conductAppealIsOpen('denied'), isFalse);
      expect(conductAppealIsOpen('withdrawn'), isFalse);
    });

    test('tenant can withdraw only a newly submitted appeal', () {
      expect(tenantCanWithdrawConductAppeal('submitted'), isTrue);
      expect(tenantCanWithdrawConductAppeal('under_review'), isFalse);
      expect(tenantCanWithdrawConductAppeal('accepted'), isFalse);
    });

    test('appeal statement requires meaningful detail', () {
      expect(validateConductAppealStatement('too short'), isNotNull);
      expect(
        validateConductAppealStatement(
          'I am contesting this decision because the recorded context is incomplete.',
        ),
        isNull,
      );
    });

    test('supporting information is optional', () {
      expect(validateConductAppealSupportingInformation(''), isNull);
      expect(
        validateConductAppealSupportingInformation(
          'Additional date and context for staff review.',
        ),
        isNull,
      );
    });

    test('decision notes require a clear explanation', () {
      expect(validateConductAppealDecisionNotes('no'), isNotNull);
      expect(
        validateConductAppealDecisionNotes(
          'Reviewed supporting information and recorded the administrative decision.',
        ),
        isNull,
      );
    });

    test('status labels remain stable', () {
      expect(conductAppealStatusLabel('submitted'), 'Submitted');
      expect(conductAppealStatusLabel('under_review'), 'Under review');
      expect(conductAppealStatusLabel('accepted'), 'Accepted');
      expect(conductAppealStatusLabel('denied'), 'Denied');
      expect(conductAppealStatusLabel('withdrawn'), 'Withdrawn');
    });
  });
}
