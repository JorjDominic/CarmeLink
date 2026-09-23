const List<String> conductCaseCategories = <String>[
  'rule_violation',
  'misconduct',
  'unauthorized_visitor',
  'roommate_conflict',
  'safety',
  'property_damage',
  'curfew',
  'other',
];

const List<String> conductCaseSources = <String>[
  'manual',
  'confidential_report',
  'room_inspection',
  'cleaning_report',
  'curfew',
  'visitor',
  'maintenance',
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
