class MoveOutSettlementPolicy {
  const MoveOutSettlementPolicy._();

  static const int minimumNoticeDays = 30;

  static String? validateNoticeDates({
    required DateTime noticeDate,
    required DateTime plannedMoveOutDate,
  }) {
    final notice = DateTime(noticeDate.year, noticeDate.month, noticeDate.day);
    final planned = DateTime(
      plannedMoveOutDate.year,
      plannedMoveOutDate.month,
      plannedMoveOutDate.day,
    );
    final minimum = notice.add(const Duration(days: minimumNoticeDays));
    if (planned.isBefore(minimum)) {
      return 'Move-out must be planned at least 30 days after notice.';
    }
    return null;
  }

  static double refundableAmount({
    required double depositReceived,
    required double approvedDeductions,
  }) =>
      (depositReceived - approvedDeductions)
          .clamp(0, double.infinity)
          .toDouble();

  static double shortfallAmount({
    required double depositReceived,
    required double approvedDeductions,
  }) =>
      (approvedDeductions - depositReceived)
          .clamp(0, double.infinity)
          .toDouble();

  static bool settlementAllowsClosure(String status) => const {
        'refunded',
        'settled_zero',
        'shortfall_pending',
      }.contains(status.trim().toLowerCase());

  static bool clearanceAllowsClosure(Iterable<String> statuses) {
    final values = statuses.toList(growable: false);
    return values.isNotEmpty &&
        values.every((status) => const {
              'cleared',
              'not_applicable',
            }.contains(status.trim().toLowerCase()));
  }
}
