const List<int> employeeCurfewWeekdays = <int>[1, 2, 3, 4, 5, 6, 7];

String employeeCurfewWeekdayLabel(int day) => switch (day) {
      1 => 'Mon',
      2 => 'Tue',
      3 => 'Wed',
      4 => 'Thu',
      5 => 'Fri',
      6 => 'Sat',
      7 => 'Sun',
      _ => '?',
    };

String employeeCurfewStatusLabel(String status) => switch (status) {
      'approved' => 'Approved',
      'revoked' => 'Revoked',
      _ => 'Draft',
    };

String employeeCurfewTimeLabel(int minutes) {
  final normalized = minutes.clamp(0, 1439);
  final hour24 = normalized ~/ 60;
  final minute = normalized % 60;
  final hour12 = hour24 == 0
      ? 12
      : hour24 > 12
          ? hour24 - 12
          : hour24;
  final suffix = hour24 >= 12 ? 'PM' : 'AM';
  return '$hour12:${minute.toString().padLeft(2, '0')} $suffix';
}

String employeeCurfewTimeSql(int minutes) {
  final normalized = minutes.clamp(0, 1439);
  final hour = normalized ~/ 60;
  final minute = normalized % 60;
  return '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}:00';
}

int employeeCurfewMinutesFromSql(String value) {
  final parts = value.split(':');
  if (parts.length < 2) return 0;
  final hour = int.tryParse(parts[0]) ?? 0;
  final minute = int.tryParse(parts[1]) ?? 0;
  return (hour * 60 + minute).clamp(0, 1439);
}

String? validateEmployeeCurfewWeekdays(Iterable<int> weekdays) {
  final values = weekdays.toSet();
  if (values.isEmpty) return 'Select at least one weekday.';
  if (values.any((day) => day < 1 || day > 7)) {
    return 'Employee curfew weekdays are invalid.';
  }
  return null;
}

String? validateEmployeeCurfewEffectiveDates(
  DateTime effectiveFrom,
  DateTime? effectiveUntil,
) {
  if (effectiveUntil != null) {
    final from = DateTime(
      effectiveFrom.year,
      effectiveFrom.month,
      effectiveFrom.day,
    );
    final until = DateTime(
      effectiveUntil.year,
      effectiveUntil.month,
      effectiveUntil.day,
    );
    if (until.isBefore(from)) {
      return 'Effective end date cannot be before the start date.';
    }
  }
  return null;
}

String? validateEmployeeCurfewWorkNote(String value) {
  final clean = value.trim();
  if (clean.length < 5) {
    return 'Work schedule note must contain at least 5 characters.';
  }
  if (clean.length > 2000) {
    return 'Work schedule note must be 2000 characters or fewer.';
  }
  return null;
}

bool employeeCurfewProfileIsEffectiveOn({
  required String status,
  required List<int> weekdays,
  required DateTime effectiveFrom,
  DateTime? effectiveUntil,
  required DateTime at,
}) {
  if (status != 'approved') return false;

  final day = DateTime(at.year, at.month, at.day);
  final start = DateTime(
    effectiveFrom.year,
    effectiveFrom.month,
    effectiveFrom.day,
  );
  final end = effectiveUntil == null
      ? null
      : DateTime(
          effectiveUntil.year,
          effectiveUntil.month,
          effectiveUntil.day,
        );

  if (day.isBefore(start)) return false;
  if (end != null && day.isAfter(end)) return false;
  return weekdays.contains(at.weekday);
}
