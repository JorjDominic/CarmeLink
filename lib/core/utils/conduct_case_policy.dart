const List<String> conductCaseCategories = <String>[
  'curfew',
  'misconduct',
  'property_damage',
  'roommate_conflict',
  'rule_violation',
  'safety',
  'unauthorized_visitor',
  'other',
];

/// Manual stays first because it is the normal/default workflow. The linked
/// record sources are alphabetical and the literal catch-all remains last.
const List<String> conductCaseSources = <String>[
  'manual',
  'cleaning_report',
  'confidential_report',
  'curfew',
  'maintenance',
  'room_inspection',
  'visitor',
  'other',
];

String conductCategoryLabel(String value) => switch (value) {
      'rule_violation' => 'Rule violation',
      'unauthorized_visitor' => 'Unauthorized visitor',
      'roommate_conflict' => 'Roommate conflict',
      'property_damage' => 'Property damage',
      'misconduct' => 'Misconduct',
      'safety' => 'Safety',
      'curfew' => 'Curfew',
      _ => 'Other',
    };

String conductCategoryDisplayLabel(String value, [String? detail]) {
  final label = conductCategoryLabel(value);
  final specific = detail?.trim() ?? '';
  return value == 'other' && specific.isNotEmpty ? '$label — $specific' : label;
}

String conductSourceLabel(String value) => switch (value) {
      'confidential_report' => 'Confidential report',
      'room_inspection' => 'Room inspection',
      'cleaning_report' => 'Cleaning report',
      'curfew' => 'Curfew record',
      'visitor' => 'Visitor record',
      'maintenance' => 'Maintenance record',
      'other' => 'Other source',
      _ => 'Manual case',
    };

String conductSourceDisplayLabel(String value, [String? detail]) {
  final label = conductSourceLabel(value);
  final specific = detail?.trim() ?? '';
  return value == 'other' && specific.isNotEmpty ? '$label — $specific' : label;
}

String conductStatusLabel(String value) => switch (value) {
      'awaiting_response' => 'Awaiting response',
      'under_review' => 'Under review',
      'warning_issued' => 'Warning issued',
      'resolved' => 'Resolved',
      'dismissed' => 'Dismissed',
      'termination_review_recommended' => 'Termination review',
      _ => 'Draft',
    };

bool conductCaseIsClosed(String status) =>
    status == 'resolved' || status == 'dismissed';

bool tenantCanRespondToConductCase(String status) =>
    status != 'draft' && !conductCaseIsClosed(status);

String? validateConductCaseTitle(String value) {
  final clean = value.trim();
  if (clean.length < 3) return 'Case title must contain at least 3 characters.';
  if (clean.length > 160) return 'Case title must be 160 characters or fewer.';
  return null;
}

String? validateConductCaseDescription(String value) {
  final clean = value.trim();
  if (clean.length < 10) {
    return 'Case description must contain at least 10 characters.';
  }
  if (clean.length > 4000) {
    return 'Case description must be 4000 characters or fewer.';
  }
  return null;
}

String? validateConductOtherDetail(
  String value, {
  required String fieldLabel,
}) {
  final clean = value.trim();
  if (clean.length < 2) return 'Please specify $fieldLabel.';
  if (clean.length > 120) return '$fieldLabel must be 120 characters or fewer.';
  return null;
}

String? validateConductResponse(String value) {
  final clean = value.trim();
  if (clean.length < 5) return 'Response must contain at least 5 characters.';
  if (clean.length > 4000) return 'Response must be 4000 characters or fewer.';
  return null;
}

String? validateConductWarning(String value) {
  final clean = value.trim();
  if (clean.length < 5) return 'Warning must contain at least 5 characters.';
  if (clean.length > 3000) return 'Warning must be 3000 characters or fewer.';
  return null;
}

String? validateTerminationReviewReason(String value) {
  final clean = value.trim();
  if (clean.length < 10) {
    return 'Termination review reason must contain at least 10 characters.';
  }
  if (clean.length > 4000) {
    return 'Termination review reason must be 4000 characters or fewer.';
  }
  return null;
}
