const List<String> cleaningWeekdayNames = <String>[
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

String cleaningWeekdayLabel(int weekday) {
  if (weekday < 1 || weekday > 7) return 'Unknown day';
  return cleaningWeekdayNames[weekday - 1];
}

String cleaningWeekdayShort(int weekday) {
  final label = cleaningWeekdayLabel(weekday);
  if (label == 'Unknown day') return label;
  return label.substring(0, 3);
}

List<int> normalizeCleaningWeekdays(Iterable<int> weekdays) {
  final values = weekdays.where((day) => day >= 1 && day <= 7).toSet().toList()
    ..sort();
  return values;
}

String? validateCleaningReportDescription(String value) {
  final clean = value.trim();
  if (clean.length < 5) {
    return 'Add at least 5 characters describing the missed cleaning duty.';
  }
  if (clean.length > 1500) {
    return 'Keep the report to 1500 characters or fewer.';
  }
  return null;
}

String cleaningReportStatusLabel(String value) => switch (value) {
      'reviewing' => 'Reviewing',
      'resolved' => 'Resolved',
      'dismissed' => 'Dismissed',
      _ => 'Open',
    };
