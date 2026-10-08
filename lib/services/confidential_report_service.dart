import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../models/models.dart';
import '../core/utils/confidential_review_action.dart';

class ConfidentialReportAddendum {
  const ConfidentialReportAddendum({
    required this.id,
    required this.reportId,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    required this.body,
    required this.createdAt,
  });

  factory ConfidentialReportAddendum.fromRow(Map<String, dynamic> row) {
    return ConfidentialReportAddendum(
      id: row['id'] as String,
      reportId: row['report_id'] as String,
      authorId: row['author_id'] as String,
      authorName: row['author_name'] as String? ?? 'User',
      authorRole:
          (row['author_role'] as String? ?? 'user').replaceAll('_', ' '),
      body: row['body'] as String,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    );
  }

  final String id;
  final String reportId;
  final String authorId;
  final String authorName;
  final String authorRole;
  final String body;
  final DateTime createdAt;
}

class ConfidentialReportService {
  const ConfidentialReportService();

  SupabaseClient get _client => SupabaseConfig.client;

  String _requireUserId() {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw const AuthException(
        'Your session has expired. Please sign in again.',
      );
    }
    return id;
  }

  Future<List<ConcernReport>> listOwnReports() async {
    final uid = _requireUserId();
    final rows = await _client
        .from('confidential_reports')
        .select()
        .eq('tenant_id', uid)
        .order('created_at', ascending: false);
    return rows
        .map<ConcernReport>(
          (row) => ConcernReport.fromRow(Map<String, dynamic>.from(row)),
        )
        .toList(growable: false);
  }

  Future<ConcernReport> submit({
    required String category,
    required String summary,
    String? reportTypeId,
    String? specificConcern,
  }) async {
    final uid = _requireUserId();
    final row = await _client
        .from('confidential_reports')
        .insert({
          'tenant_id': uid,
          'category': category.trim().toLowerCase().replaceAll(' ', '_'),
          'summary': summary.trim(),
          if (reportTypeId != null) 'report_type_id': reportTypeId,
          if (specificConcern != null)
            'specific_concern': specificConcern.trim(),
        })
        .select()
        .single();
    return ConcernReport.fromRow(Map<String, dynamic>.from(row));
  }

  Future<List<ConcernReport>> listForOwner() async {
    _requireUserId();
    final rows = await _client.rpc('list_confidential_reports_v2');
    return (rows as List)
        .map(
          (row) => ConcernReport.fromRow(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<ConcernReport> review({
    required String reportId,
    required String status,
    required String notes,
    ConcernReport? originalReport,
  }) async {
    _requireUserId();
    ConfidentialReviewAction.forStatus(status);
    if (notes.trim().length < 5 || notes.trim().length > 1000) {
      throw ArgumentError('Use 5 to 1000 characters of review notes.');
    }
    // Preserve configured category snapshots/specific concerns, which the
    // legacy review RPC does not include in its response. Read before writing
    // so a subsequent fetch failure cannot masquerade as a failed save.
    final original = originalReport ??
        (await listForOwner()).firstWhere((report) => report.id == reportId);
    final result = await _client.rpc(
      'owner_review_confidential_report',
      params: {
        'p_report_id': reportId,
        'p_status': status,
        'p_notes': notes.trim(),
      },
    );
    // The review RPC returns the persisted row. A second list fetch can fail
    // after a successful save or show a later, unrelated state change.
    return reviewedConfidentialReport({
      'report_type_label': original.category,
      'specific_concern': original.specificConcern,
    }, Map<String, dynamic>.from(result as Map));
  }

  Future<List<ConfidentialReportAddendum>> listAddenda(String reportId) async {
    _requireUserId();
    final rows = await _client.rpc(
      'list_confidential_report_addenda',
      params: {'p_report_id': reportId},
    );
    return (rows as List)
        .map(
          (row) => ConfidentialReportAddendum.fromRow(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(growable: false);
  }

  String createCorrectionRequestId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final random = Random.secure().nextInt(0x7fffffff).toRadixString(36);
    return '$timestamp-$random';
  }

  Future<void> addCorrection(
    String reportId,
    String body, {
    required String requestId,
  }) async {
    final uid = _requireUserId();
    final normalized = body.trim();
    final normalizedRequestId = requestId.trim();
    if (normalized.length < 5 || normalized.length > 2000) {
      throw ArgumentError('Use 5 to 2000 characters.');
    }
    if (normalizedRequestId.length < 8 || normalizedRequestId.length > 120) {
      throw ArgumentError('Invalid correction request identifier.');
    }

    // Staff deliberately read confidential records through audited RPCs, not
    // tenant-only table policies. Choose the existing reader by server role.
    final role = await _client.rpc('current_user_role');
    final reports = role == 'owner' || role == 'caretaker'
        ? await listForOwner()
        : await listOwnReports();
    final report = reports.firstWhere((item) => item.id == reportId,
        orElse: () => throw StateError('Report unavailable or access denied.'));
    if (report.isResolved) {
      throw StateError('Resolved reports cannot receive additions.');
    }

    try {
      await _client.rpc(
        'append_confidential_report_addendum',
        params: {
          'p_report_id': reportId,
          'p_body': normalized,
          'p_request_id': normalizedRequestId,
        },
      );
    } catch (error) {
      // The request may have reached the database even when the response was
      // interrupted. Verify the idempotency key before surfacing a failure so
      // retrying does not create a duplicate addendum.
      try {
        final existing = await _client
            .from('confidential_report_addenda')
            .select('id')
            .eq('author_id', uid)
            .eq('client_request_id', normalizedRequestId)
            .eq('report_id', reportId)
            .eq('body', normalized)
            .maybeSingle();
        if (existing != null) return;
      } catch (_) {
        // Preserve the original write error when verification also fails.
      }
      rethrow;
    }
  }
}

ConcernReport reviewedConfidentialReport(
        Map<String, dynamic> original, Map<String, dynamic> persisted) =>
    ConcernReport.fromRow({...original, ...persisted});
