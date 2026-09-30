import 'package:carmelitas_dormitory_system/core/utils/move_out_settlement_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 8 move-out policy', () {
    test('requires at least 30 days notice', () {
      final notice = DateTime(2026, 9, 30);
      expect(
        MoveOutSettlementPolicy.validateNoticeDates(
          noticeDate: notice,
          plannedMoveOutDate: DateTime(2026, 10, 29),
        ),
        isNotNull,
      );
      expect(
        MoveOutSettlementPolicy.validateNoticeDates(
          noticeDate: notice,
          plannedMoveOutDate: DateTime(2026, 10, 30),
        ),
        isNull,
      );
    });

    test('refund and shortfall never go below zero', () {
      expect(
        MoveOutSettlementPolicy.refundableAmount(
          depositReceived: 4000,
          approvedDeductions: 1200,
        ),
        2800,
      );
      expect(
        MoveOutSettlementPolicy.shortfallAmount(
          depositReceived: 1000,
          approvedDeductions: 1600,
        ),
        600,
      );
      expect(
        MoveOutSettlementPolicy.refundableAmount(
          depositReceived: 1000,
          approvedDeductions: 1600,
        ),
        0,
      );
    });

    test('closure requires resolved clearance and settlement outcome', () {
      expect(
        MoveOutSettlementPolicy.clearanceAllowsClosure(
          const ['cleared', 'not_applicable', 'cleared'],
        ),
        isTrue,
      );
      expect(
        MoveOutSettlementPolicy.clearanceAllowsClosure(
          const ['cleared', 'pending'],
        ),
        isFalse,
      );
      for (final status in ['refunded', 'settled_zero', 'shortfall_pending']) {
        expect(MoveOutSettlementPolicy.settlementAllowsClosure(status), isTrue);
      }
      expect(
          MoveOutSettlementPolicy.settlementAllowsClosure('pending'), isFalse);
    });
  });
}
