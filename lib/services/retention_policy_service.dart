import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';

class RetentionPolicySetting {
  const RetentionPolicySetting({
    required this.recordKey,
    required this.displayName,
    required this.description,
    required this.reviewStatus,
    required this.reviewNotes,
    required this.enforcementEnabled,
    required this.updatedAt,
    this.proposedRetentionDays,
  });

  factory RetentionPolicySetting.fromRow(Map<String, dynamic> row) {
    return RetentionPolicySetting(
      recordKey: row['record_key'] as String,
      displayName: row['display_name'] as String,
      description: row['description'] as String,
      proposedRetentionDays: (row['proposed_retention_days'] as num?)?.toInt(),
      reviewStatus: row['review_status'] as String,
      reviewNotes: row['review_notes'] as String? ?? '',
      enforcementEnabled: row['enforcement_enabled'] as bool? ?? false,
      updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
    );
  }

  final String recordKey;
  final String displayName;
  final String description;
  final int? proposedRetentionDays;
  final String reviewStatus;
  final String reviewNotes;
  final bool enforcementEnabled;
  final DateTime updatedAt;
}

class RetentionPolicyEvent {
  const RetentionPolicyEvent({
    required this.id,
    required this.recordKey,
    required this.actorName,
    required this.reviewStatus,
    required this.notes,
    required this.createdAt,
    this.previousDays,
    this.proposedDays,
    this.previousReviewStatus,
  });

  factory RetentionPolicyEvent.fromRow(Map<String, dynamic> row) {
    return RetentionPolicyEvent(
      id: row['id'] as String,
      recordKey: row['record_key'] as String,
      actorName: row['actor_name'] as String,
      previousDays: (row['previous_days'] as num?)?.toInt(),
      proposedDays: (row['proposed_days'] as num?)?.toInt(),
      previousReviewStatus: row['previous_review_status'] as String?,
      reviewStatus: row['review_status'] as String,
      notes: row['notes'] as String? ?? '',
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    );
  }

  final String id;
  final String recordKey;
  final String actorName;
  final int? previousDays;
  final int? proposedDays;
  final String? previousReviewStatus;
  final String reviewStatus;
  final String notes;
  final DateTime createdAt;
}

class RetentionPolicyService {
  const RetentionPolicyService();

  SupabaseClient get _client => SupabaseConfig.client;

  Future<List<RetentionPolicySetting>> listSettings() async {
    final rows = await _client
        .from('retention_policy_settings')
        .select(
          'record_key, display_name, description, proposed_retention_days, '
          'review_status, review_notes, enforcement_enabled, updated_at',
        )
        .order('display_name');

    return rows
        .map<RetentionPolicySetting>(RetentionPolicySetting.fromRow)
        .toList(growable: false);
  }

  Future<List<RetentionPolicyEvent>> listEvents(String recordKey) async {
    final rows = await _client
        .from('retention_policy_events')
        .select(
          'id, record_key, actor_name, previous_days, proposed_days, '
          'previous_review_status, review_status, notes, created_at',
        )
        .eq('record_key', recordKey)
        .order('created_at', ascending: false);

    return rows
        .map<RetentionPolicyEvent>(RetentionPolicyEvent.fromRow)
        .toList(growable: false);
  }

  Future<void> updateSetting({
    required String recordKey,
    required int? proposedRetentionDays,
    required String reviewStatus,
    required String reviewNotes,
  }) async {
    await _client.rpc(
      'update_retention_policy_setting',
      params: {
        'p_record_key': recordKey,
        'p_proposed_retention_days': proposedRetentionDays,
        'p_review_status': reviewStatus,
        'p_review_notes': reviewNotes.trim(),
      },
    );
  }
}

String retentionPolicyError(Object error) {
  final message =
      error is PostgrestException ? error.message : error.toString();

  if (message.contains('Only owners and caretakers')) {
    return 'Only authorized dormitory staff can manage retention settings.';
  }
  if (message.contains('Retention days')) {
    return 'Retention days must be a whole number greater than zero.';
  }
  if (message.contains('record group not found')) {
    return 'The selected retention record group no longer exists.';
  }

  return 'Unable to update retention settings. Check your connection and try again.';
}
