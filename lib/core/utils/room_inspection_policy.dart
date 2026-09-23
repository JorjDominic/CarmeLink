const Duration monthlyInspectionNoticeMinimum = Duration(days: 3);

const List<String> roomInspectionFindingCategories = <String>[
  'condition',
  'cleanliness',
  'maintenance',
  'safety',
  'furniture',
  'utilities',
  'other',
];

const List<String> roomInspectionFindingSeverities = <String>[
  'note',
  'minor',
  'moderate',
  'major',
];

String inspectionTypeLabel(String value) => switch (value) {
      'follow_up' => 'Follow-up',
      'move_in' => 'Move-in',
      'move_out' => 'Move-out',
      'emergency' => 'Emergency',
      _ => 'Monthly',
    };

String inspectionStatusLabel(String value) => switch (value) {
      'in_progress' => 'In progress',
      'completed' => 'Completed',
      'cancelled' => 'Cancelled',
      _ => 'Scheduled',
    };

String findingStatusLabel(String value) => switch (value) {
      'monitoring' => 'Monitoring',
      'corrected' => 'Corrected',
      _ => 'Open',
    };

String titleCaseInspectionValue(String value) {
  return value
      .split('_')
      .where((part) => part.isNotEmpty)
      .map(
        (part) => '${part.substring(0, 1).toUpperCase()}${part.substring(1)}',
      )
      .join(' ');
}

String? validateMonthlyInspectionSchedule(
  DateTime scheduledAt, {
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  if (!scheduledAt.isAfter(current)) {
    return 'Inspection schedule must be in the future.';
  }

  final minimum = current.add(monthlyInspectionNoticeMinimum);
  if (scheduledAt.isBefore(minimum)) {
    return 'Monthly inspections require at least three days written notice.';
  }

  return null;
}

String? validateInspectionNotice(String value) {
  final clean = value.trim();
  if (clean.length < 5) {
    return 'Written notice must contain at least 5 characters.';
  }
  if (clean.length > 2000) {
    return 'Written notice must be 2000 characters or fewer.';
  }
  return null;
}

String? validateInspectionFindingDescription(String value) {
  final clean = value.trim();
  if (clean.length < 5) {
    return 'Finding description must contain at least 5 characters.';
  }
  if (clean.length > 2000) {
    return 'Finding description must be 2000 characters or fewer.';
  }
  return null;
}
