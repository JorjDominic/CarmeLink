import 'package:carmelitas_dormitory_system/core/utils/conduct_case_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('conduct case policy', () {
    test('labels supported categories and statuses', () {
      expect(
          conductCategoryLabel('unauthorized_visitor'), 'Unauthorized visitor');
      expect(
        conductStatusLabel('termination_review_recommended'),
        'Termination review',
      );
      expect(conductSourceLabel('room_inspection'), 'Room inspection');
    });

    test('draft and closed cases cannot receive tenant responses', () {
      expect(tenantCanRespondToConductCase('draft'), isFalse);
      expect(tenantCanRespondToConductCase('resolved'), isFalse);
      expect(tenantCanRespondToConductCase('dismissed'), isFalse);
      expect(tenantCanRespondToConductCase('awaiting_response'), isTrue);
      expect(
        tenantCanRespondToConductCase('termination_review_recommended'),
        isTrue,
      );
    });

    test('case title validation rejects short title', () {
      expect(validateConductCaseTitle('ab'), isNotNull);
      expect(validateConductCaseTitle('Quiet-hour concern'), isNull);
    });

    test('case description validation requires useful detail', () {
      expect(validateConductCaseDescription('short'), isNotNull);
      expect(
        validateConductCaseDescription(
          'Reported loud activity continued after the posted quiet hours.',
        ),
        isNull,
      );
    });

    test('tenant response validation requires useful detail', () {
      expect(validateConductResponse('no'), isNotNull);
      expect(
        validateConductResponse(
          'I would like to provide context about the reported incident.',
        ),
        isNull,
      );
    });

    test('warning validation rejects empty or very short warning', () {
      expect(validateConductWarning('bad'), isNotNull);
      expect(
        validateConductWarning(
          'Written warning recorded after staff review of the case.',
        ),
        isNull,
      );
    });

    test('termination recommendation requires explicit reason', () {
      expect(validateTerminationReviewReason('short'), isNotNull);
      expect(
        validateTerminationReviewReason(
          'Repeated verified incidents require a separate administrative review.',
        ),
        isNull,
      );
    });
  });
}
