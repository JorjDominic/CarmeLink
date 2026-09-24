const List<String> appealEligibleCaseStatuses = <String>[
  'warning_issued',
  'resolved',
  'termination_review_recommended',
];

String conductAppealStatusLabel(String status) => switch (status) {
      'under_review' => 'Under review',
      'accepted' => 'Accepted',
      'denied' => 'Denied',
      'withdrawn' => 'Withdrawn',
      _ => 'Submitted',
    };

bool conductCaseAllowsAppeal(String caseStatus) =>
    appealEligibleCaseStatuses.contains(caseStatus);

bool conductAppealIsOpen(String status) =>
    status == 'submitted' || status == 'under_review';

bool tenantCanWithdrawConductAppeal(String status) => status == 'submitted';

String? validateConductAppealStatement(String value) {
  final clean = value.trim();
  if (clean.length < 10) {
    return 'Appeal statement must contain at least 10 characters.';
  }
  if (clean.length > 4000) {
    return 'Appeal statement must be 4000 characters or fewer.';
  }
  return null;
}

String? validateConductAppealSupportingInformation(String value) {
  if (value.trim().length > 4000) {
    return 'Supporting information must be 4000 characters or fewer.';
  }
  return null;
}

String? validateConductAppealDecisionNotes(String value) {
  final clean = value.trim();
  if (clean.length < 5) {
    return 'Decision notes must contain at least 5 characters.';
  }
  if (clean.length > 4000) {
    return 'Decision notes must be 4000 characters or fewer.';
  }
  return null;
}
