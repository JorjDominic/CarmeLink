const List<String> retentionReviewStatuses = <String>[
  'draft',
  'pending_review',
  'reviewed',
];

String retentionReviewStatusLabel(String status) => switch (status) {
      'pending_review' => 'Pending review',
      'reviewed' => 'Reviewed',
      _ => 'Draft',
    };

String? validateRetentionDays(String value) {
  final clean = value.trim();
  if (clean.isEmpty) return null;

  final parsed = int.tryParse(clean);
  if (parsed == null || parsed <= 0) {
    return 'Retention days must be a whole number greater than zero.';
  }
  return null;
}

String? validateRetentionReviewNotes(String value) {
  if (value.trim().length > 4000) {
    return 'Review notes must be 4000 characters or fewer.';
  }
  return null;
}

bool retentionEnforcementMayRun(bool enforcementEnabled) => enforcementEnabled;
