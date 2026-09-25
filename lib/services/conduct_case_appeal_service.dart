import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import 'app_notification_service.dart';

class ConductCaseAppealRecord {
  const ConductCaseAppealRecord({
    required this.id,
    required this.caseId,
    required this.tenantId,
    required this.appealStatement,
    required this.supportingInformation,
    required this.status,
    required this.submittedAt,
    required this.updatedAt,
    this.reviewedAt,
    this.decisionNotes = '',
  });

  factory ConductCaseAppealRecord.fromRow(Map<String, dynamic> row) {
    final reviewedAt = row['reviewed_at'] as String?;
    return ConductCaseAppealRecord(
      id: row['id'] as String,
      caseId: row['case_id'] as String,
      tenantId: row['tenant_id'] as String,
      appealStatement: row['appeal_statement'] as String,
      supportingInformation: row['supporting_information'] as String? ?? '',
      status: row['status'] as String,
      submittedAt: DateTime.parse(
        row['submitted_at'] as String,
      ).toLocal(),
      updatedAt: DateTime.parse(
        row['updated_at'] as String,
      ).toLocal(),
      reviewedAt:
          reviewedAt == null ? null : DateTime.parse(reviewedAt).toLocal(),
      decisionNotes: row['decision_notes'] as String? ?? '',
    );
  }

  final String id;
  final String caseId;
  final String tenantId;
  final String appealStatement;
  final String supportingInformation;
  final String status;
  final DateTime submittedAt;
  final DateTime updatedAt;
  final DateTime? reviewedAt;
  final String decisionNotes;
}

class ConductCaseAppealService {
  const ConductCaseAppealService();

  SupabaseClient get _client => SupabaseConfig.client;

  static const _columns =
      'id, case_id, tenant_id, appeal_statement, supporting_information, '
      'status, reviewed_at, decision_notes, submitted_at, updated_at';

  Future<List<ConductCaseAppealRecord>> listForCase(
    String caseId,
  ) async {
    final rows = await _client
        .from('conduct_case_appeals')
        .select(_columns)
        .eq('case_id', caseId)
        .order('submitted_at', ascending: false);

    return rows
        .map<ConductCaseAppealRecord>(
          ConductCaseAppealRecord.fromRow,
        )
        .toList(growable: false);
  }

  Future<String> submitAppeal({
    required String caseId,
    required String statement,
    required String supportingInformation,
  }) async {
    final result = await _client.rpc(
      'submit_conduct_case_appeal',
      params: {
        'p_case_id': caseId,
        'p_appeal_statement': statement.trim(),
        'p_supporting_information': supportingInformation.trim(),
      },
    );
    final appealId = result as String;
    final tenantName =
        _client.auth.currentUser?.userMetadata?['full_name']?.toString().trim();
    unawaited(AppNotificationService.instance.notifyConductAppealSubmitted(
      caseId: caseId,
      tenantName: tenantName?.isNotEmpty == true ? tenantName! : 'A tenant',
    ));
    return appealId;
  }

  Future<void> withdrawAppeal(
    ConductCaseAppealRecord appeal,
  ) async {
    await _client.rpc(
      'withdraw_conduct_case_appeal',
      params: {
        'p_appeal_id': appeal.id,
        'p_expected_updated_at': appeal.updatedAt.toUtc().toIso8601String(),
      },
    );
  }

  Future<void> startReview(
    ConductCaseAppealRecord appeal,
  ) async {
    await _client.rpc(
      'start_conduct_case_appeal_review',
      params: {
        'p_appeal_id': appeal.id,
        'p_expected_updated_at': appeal.updatedAt.toUtc().toIso8601String(),
      },
    );
  }

  Future<void> decideAppeal({
    required ConductCaseAppealRecord appeal,
    required String decision,
    required String notes,
  }) async {
    await _client.rpc(
      'decide_conduct_case_appeal',
      params: {
        'p_appeal_id': appeal.id,
        'p_expected_updated_at': appeal.updatedAt.toUtc().toIso8601String(),
        'p_decision': decision,
        'p_decision_notes': notes.trim(),
      },
    );
    unawaited(AppNotificationService.instance.notifyConductAppealResolved(
      tenantId: appeal.tenantId,
      caseId: appeal.caseId,
      decision: decision,
    ));
  }
}

String conductCaseAppealError(Object error) {
  final message =
      error is PostgrestException ? error.message : error.toString();

  if (message.contains('changed. Refresh')) {
    return 'This appeal changed. Refresh before continuing.';
  }
  if (message.contains('not currently eligible')) {
    return 'This conduct case is not currently eligible for an appeal.';
  }
  if (message.contains('already has an appeal awaiting review')) {
    return 'This case already has an appeal awaiting staff review.';
  }
  if (message.contains('Only owners and caretakers')) {
    return 'Only authorized dormitory staff can review appeals.';
  }
  if (message.contains('not available to your account')) {
    return 'This appeal is not available to your account.';
  }
  if (message.contains('already closed')) {
    return 'This appeal has already been decided or closed.';
  }

  return 'Unable to update this appeal. Check your connection and try again.';
}
