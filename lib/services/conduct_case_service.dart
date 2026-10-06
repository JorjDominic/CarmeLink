import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../core/utils/conduct_case_policy.dart';
import 'app_notification_service.dart';

class ConductTenantOption {
  const ConductTenantOption({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
}

class ConductSourceOption {
  const ConductSourceOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.occurredAt,
  });

  final String id;
  final String title;
  final String subtitle;
  final DateTime occurredAt;
}

class ConductCaseRecord {
  const ConductCaseRecord({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.incidentAt,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.tenantId,
    this.tenantName,
    this.categoryDetail,
    this.sourceModule,
    this.sourceRecordId,
    this.sourceDetail,
    this.tenantNotifiedAt,
    this.resolutionNotes = '',
    this.terminationReviewReason = '',
  });

  factory ConductCaseRecord.fromStaffRow(
    Map<String, dynamic> row, {
    String? tenantName,
  }) {
    return ConductCaseRecord(
      id: row['id'] as String,
      tenantId: row['tenant_id'] as String,
      tenantName: tenantName,
      category: row['category'] as String,
      categoryDetail: row['category_detail'] as String?,
      title: row['title'] as String,
      description: row['description'] as String,
      incidentAt: DateTime.parse(row['incident_at'] as String).toLocal(),
      status: row['status'] as String,
      sourceModule: row['source_module'] as String? ?? 'manual',
      sourceRecordId: row['source_record_id'] as String?,
      sourceDetail: row['source_detail'] as String?,
      tenantNotifiedAt: _nullableDate(row['tenant_notified_at']),
      resolutionNotes: row['resolution_notes'] as String? ?? '',
      terminationReviewReason:
          row['termination_review_reason'] as String? ?? '',
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
    );
  }

  factory ConductCaseRecord.fromTenantRow(Map<String, dynamic> row) {
    return ConductCaseRecord(
      id: row['id'] as String,
      category: row['category'] as String,
      categoryDetail: row['category_detail'] as String?,
      title: row['title'] as String,
      description: row['description'] as String,
      incidentAt: DateTime.parse(row['incident_at'] as String).toLocal(),
      status: row['status'] as String,
      tenantNotifiedAt: _nullableDate(row['tenant_notified_at']),
      resolutionNotes: row['resolution_notes'] as String? ?? '',
      terminationReviewReason:
          row['termination_review_reason'] as String? ?? '',
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
    );
  }

  static DateTime? _nullableDate(dynamic value) {
    final raw = value as String?;
    return raw == null ? null : DateTime.parse(raw).toLocal();
  }

  final String id;
  final String? tenantId;
  final String? tenantName;
  final String category;
  final String? categoryDetail;
  final String title;
  final String description;
  final DateTime incidentAt;
  final String status;
  final String? sourceModule;
  final String? sourceRecordId;
  final String? sourceDetail;
  final DateTime? tenantNotifiedAt;
  final String resolutionNotes;
  final String terminationReviewReason;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class ConductCaseResponse {
  const ConductCaseResponse({
    required this.id,
    required this.body,
    required this.createdAt,
  });

  factory ConductCaseResponse.fromRow(Map<String, dynamic> row) {
    return ConductCaseResponse(
      id: row['id'] as String,
      body: row['body'] as String,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    );
  }

  final String id;
  final String body;
  final DateTime createdAt;
}

class ConductCaseWarning {
  const ConductCaseWarning({
    required this.id,
    required this.message,
    required this.issuedAt,
  });

  factory ConductCaseWarning.fromRow(Map<String, dynamic> row) {
    return ConductCaseWarning(
      id: row['id'] as String,
      message: row['message'] as String,
      issuedAt: DateTime.parse(row['issued_at'] as String).toLocal(),
    );
  }

  final String id;
  final String message;
  final DateTime issuedAt;
}

class ConductCaseEvent {
  const ConductCaseEvent({
    required this.id,
    required this.eventType,
    required this.actorName,
    required this.notes,
    required this.createdAt,
  });

  factory ConductCaseEvent.fromRow(Map<String, dynamic> row) {
    return ConductCaseEvent(
      id: row['id'] as String,
      eventType: row['event_type'] as String,
      actorName: row['actor_name'] as String,
      notes: row['notes'] as String? ?? '',
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    );
  }

  final String id;
  final String eventType;
  final String actorName;
  final String notes;
  final DateTime createdAt;
}

class ConductCaseEvidence {
  const ConductCaseEvidence({
    required this.id,
    required this.originalName,
    required this.caption,
    required this.createdAt,
  });

  factory ConductCaseEvidence.fromRow(Map<String, dynamic> row) {
    return ConductCaseEvidence(
      id: row['id'] as String,
      originalName: row['original_name'] as String,
      caption: row['caption'] as String? ?? '',
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    );
  }

  final String id;
  final String originalName;
  final String caption;
  final DateTime createdAt;
}

class ConductCaseService {
  const ConductCaseService();

  SupabaseClient get _client => SupabaseConfig.client;

  static const String _staffCaseColumns =
      'id, tenant_id, category, category_detail, title, description, incident_at, status, '
      'source_module, source_record_id, source_detail, tenant_notified_at, resolution_notes, '
      'termination_review_reason, created_at, updated_at';

  Future<List<ConductTenantOption>> listTenantOptions() async {
    final rows = await _client
        .from('profiles')
        .select('id, full_name')
        .eq('role', 'tenant')
        .order('full_name');

    return rows
        .map<ConductTenantOption>(
          (row) => ConductTenantOption(
            id: row['id'] as String,
            name: (row['full_name'] as String?)?.trim().isNotEmpty == true
                ? (row['full_name'] as String).trim()
                : 'Tenant',
          ),
        )
        .toList(growable: false);
  }

  Future<List<ConductCaseRecord>> listStaffCases() async {
    final rows = await _client
        .from('conduct_cases')
        .select(_staffCaseColumns)
        .order('created_at', ascending: false);

    final tenantIds =
        rows.map<String>((row) => row['tenant_id'] as String).toSet().toList();

    final names = <String, String>{};
    if (tenantIds.isNotEmpty) {
      final profileRows = await _client
          .from('profiles')
          .select('id, full_name')
          .inFilter('id', tenantIds);
      for (final row in profileRows) {
        names[row['id'] as String] =
            (row['full_name'] as String?)?.trim().isNotEmpty == true
                ? (row['full_name'] as String).trim()
                : 'Tenant';
      }
    }

    return rows
        .map<ConductCaseRecord>(
          (row) => ConductCaseRecord.fromStaffRow(
            row,
            tenantName: names[row['tenant_id'] as String] ?? 'Tenant',
          ),
        )
        .toList(growable: false);
  }

  Future<List<ConductCaseRecord>> listMyCases() async {
    final result = await _client.rpc('get_my_conduct_cases');
    final rows = result is List ? result : const <dynamic>[];
    return rows
        .map<ConductCaseRecord>(
          (row) => ConductCaseRecord.fromTenantRow(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<List<ConductSourceOption>> listSourceOptions({
    required String tenantId,
    required String sourceModule,
  }) async {
    List<ConductSourceOption> finish(List<ConductSourceOption> values) {
      values.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
      return values.length <= 30 ? values : values.sublist(0, 30);
    }

    DateTime parseDate(dynamic value) =>
        DateTime.tryParse(value?.toString() ?? '')?.toLocal() ?? DateTime.now();

    String humanize(dynamic value) {
      final raw = value?.toString().trim() ?? '';
      if (raw.isEmpty) return 'Record';
      final words = raw.replaceAll('_', ' ').split(RegExp(r'\s+'));
      return words
          .map((word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}')
          .join(' ');
    }

    switch (sourceModule) {
      case 'confidential_report':
        final rows = await _client
            .from('confidential_reports')
            .select('id, category, summary, status, created_at')
            .eq('tenant_id', tenantId)
            .order('created_at', ascending: false)
            .limit(30);
        return finish(rows.map<ConductSourceOption>((row) {
          final summary = row['summary']?.toString().trim() ?? '';
          return ConductSourceOption(
            id: row['id'] as String,
            title: 'Confidential report • ${humanize(row['category'])}',
            subtitle: summary.isEmpty ? humanize(row['status']) : summary,
            occurredAt: parseDate(row['created_at']),
          );
        }).toList());
      case 'maintenance':
        final rows = await _client
            .from('maintenance_reports')
            .select('id, category, location, description, status, created_at')
            .eq('tenant_id', tenantId)
            .order('created_at', ascending: false)
            .limit(30);
        return finish(rows.map<ConductSourceOption>((row) {
          final location = row['location']?.toString().trim() ?? '';
          final description = row['description']?.toString().trim() ?? '';
          return ConductSourceOption(
            id: row['id'] as String,
            title: '${humanize(row['category'])} • ${humanize(row['status'])}',
            subtitle: [location, description]
                .where((value) => value.isNotEmpty)
                .join(' • '),
            occurredAt: parseDate(row['created_at']),
          );
        }).toList());
      case 'visitor':
        final rows = await _client
            .from('visitor_requests')
            .select('id, visitor_name, purpose, status, schedule, created_at')
            .eq('tenant_id', tenantId)
            .order('schedule', ascending: false)
            .limit(30);
        return finish(rows.map<ConductSourceOption>((row) {
          return ConductSourceOption(
            id: row['id'] as String,
            title:
                '${row['visitor_name'] ?? 'Visitor'} • ${humanize(row['status'])}',
            subtitle: row['purpose']?.toString().trim() ?? '',
            occurredAt: parseDate(row['schedule'] ?? row['created_at']),
          );
        }).toList());
      case 'curfew':
        final rows = await _client
            .from('curfew_requests')
            .select(
              'id, request_type, destination, reason, status, departure_time, created_at',
            )
            .eq('tenant_id', tenantId)
            .order('departure_time', ascending: false)
            .limit(30);
        return finish(rows.map<ConductSourceOption>((row) {
          final destination = row['destination']?.toString().trim() ?? '';
          final reason = row['reason']?.toString().trim() ?? '';
          return ConductSourceOption(
            id: row['id'] as String,
            title:
                '${humanize(row['request_type'])} • ${humanize(row['status'])}',
            subtitle: [destination, reason]
                .where((value) => value.isNotEmpty)
                .join(' • '),
            occurredAt: parseDate(row['departure_time'] ?? row['created_at']),
          );
        }).toList());
      case 'cleaning_report':
        final assignment = await _client
            .from('tenant_assignments')
            .select('bed_space_id')
            .eq('tenant_id', tenantId)
            .eq('status', 'active')
            .maybeSingle();
        final bedSpaceId = assignment?['bed_space_id']?.toString();
        if (bedSpaceId == null || bedSpaceId.isEmpty) return const [];
        final rows = await _client
            .from('cleaning_noncompliance_reports')
            .select(
              'id, reported_bed_label, description, status, created_at',
            )
            .eq('reported_bed_space_id', bedSpaceId)
            .order('created_at', ascending: false)
            .limit(30);
        return finish(rows.map<ConductSourceOption>((row) {
          return ConductSourceOption(
            id: row['id'] as String,
            title: 'Cleaning report • ${humanize(row['status'])}',
            subtitle:
                '${row['reported_bed_label'] ?? 'Bed'} • ${row['description'] ?? ''}',
            occurredAt: parseDate(row['created_at']),
          );
        }).toList());
      case 'room_inspection':
        final assignment = await _client
            .from('tenant_assignments')
            .select('bed_spaces!inner(room_id)')
            .eq('tenant_id', tenantId)
            .eq('status', 'active')
            .maybeSingle();
        final bed = assignment?['bed_spaces'] as Map<String, dynamic>?;
        final roomId = bed?['room_id']?.toString();
        if (roomId == null || roomId.isEmpty) return const [];
        final rows = await _client
            .from('room_inspections')
            .select('id, inspection_type, status, scheduled_at, summary')
            .eq('room_id', roomId)
            .order('scheduled_at', ascending: false)
            .limit(30);
        return finish(rows.map<ConductSourceOption>((row) {
          final summary = row['summary']?.toString().trim() ?? '';
          return ConductSourceOption(
            id: row['id'] as String,
            title:
                '${humanize(row['inspection_type'])} inspection • ${humanize(row['status'])}',
            subtitle: summary.isEmpty ? 'Room inspection record' : summary,
            occurredAt: parseDate(row['scheduled_at']),
          );
        }).toList());
      default:
        return const [];
    }
  }

  Future<String> createCase({
    required String tenantId,
    required String category,
    String? categoryDetail,
    required String title,
    required String description,
    required DateTime incidentAt,
    required String sourceModule,
    String? sourceRecordId,
    String? sourceDetail,
  }) async {
    final result = await _client.rpc(
      'create_conduct_case',
      params: {
        'p_tenant_id': tenantId,
        'p_category': category,
        'p_category_detail': categoryDetail?.trim(),
        'p_title': title.trim(),
        'p_description': description.trim(),
        'p_incident_at': incidentAt.toUtc().toIso8601String(),
        'p_source_module': sourceModule,
        'p_source_record_id': sourceRecordId?.trim(),
        'p_source_detail': sourceDetail?.trim(),
      },
    );
    return result as String;
  }

  Future<void> publishCase(ConductCaseRecord record) async {
    await _client.rpc(
      'publish_conduct_case',
      params: {
        'p_case_id': record.id,
        'p_expected_updated_at': record.updatedAt.toUtc().toIso8601String(),
      },
    );

    final tenantId = record.tenantId;
    if (tenantId != null && tenantId.isNotEmpty) {
      unawaited(AppNotificationService.instance.notifyConductCaseFiled(
        tenantId: tenantId,
        caseId: record.id,
        title: record.title,
        severity: conductCategoryDisplayLabel(
          record.category,
          record.categoryDetail,
        ),
      ));
    }
  }

  Future<void> submitResponse({
    required String caseId,
    required String body,
  }) async {
    await _client.rpc(
      'submit_conduct_case_response',
      params: {
        'p_case_id': caseId,
        'p_body': body.trim(),
      },
    );
  }

  Future<void> issueWarning({
    required ConductCaseRecord record,
    required String message,
  }) async {
    await _client.rpc(
      'issue_conduct_case_warning',
      params: {
        'p_case_id': record.id,
        'p_expected_updated_at': record.updatedAt.toUtc().toIso8601String(),
        'p_message': message.trim(),
      },
    );

    final tenantId = record.tenantId;
    if (tenantId != null && tenantId.isNotEmpty) {
      unawaited(AppNotificationService.instance.notifyConductCaseFiled(
        tenantId: tenantId,
        caseId: record.id,
        title: 'Formal Warning Issued',
        severity: 'Warning',
      ));
    }
  }

  Future<void> setReviewStatus({
    required ConductCaseRecord record,
    required String status,
    required String notes,
  }) async {
    await _client.rpc(
      'set_conduct_case_review_status',
      params: {
        'p_case_id': record.id,
        'p_expected_updated_at': record.updatedAt.toUtc().toIso8601String(),
        'p_status': status,
        'p_notes': notes.trim(),
      },
    );
  }

  Future<void> recommendTerminationReview({
    required ConductCaseRecord record,
    required String reason,
  }) async {
    await _client.rpc(
      'recommend_conduct_termination_review',
      params: {
        'p_case_id': record.id,
        'p_expected_updated_at': record.updatedAt.toUtc().toIso8601String(),
        'p_reason': reason.trim(),
      },
    );
  }

  Future<List<ConductCaseResponse>> listStaffResponses(String caseId) async {
    final rows = await _client
        .from('conduct_case_responses')
        .select('id, body, created_at')
        .eq('case_id', caseId)
        .order('created_at');

    return rows
        .map<ConductCaseResponse>(ConductCaseResponse.fromRow)
        .toList(growable: false);
  }

  Future<List<ConductCaseResponse>> listMyResponses(String caseId) async {
    final result = await _client.rpc(
      'get_my_conduct_case_responses',
      params: {'p_case_id': caseId},
    );
    final rows = result is List ? result : const <dynamic>[];
    return rows
        .map<ConductCaseResponse>(
          (row) => ConductCaseResponse.fromRow(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<List<ConductCaseWarning>> listStaffWarnings(String caseId) async {
    final rows = await _client
        .from('conduct_case_warnings')
        .select('id, message, issued_at')
        .eq('case_id', caseId)
        .order('issued_at', ascending: false);

    return rows
        .map<ConductCaseWarning>(ConductCaseWarning.fromRow)
        .toList(growable: false);
  }

  Future<List<ConductCaseWarning>> listMyWarnings(String caseId) async {
    final result = await _client.rpc(
      'get_my_conduct_case_warnings',
      params: {'p_case_id': caseId},
    );
    final rows = result is List ? result : const <dynamic>[];
    return rows
        .map<ConductCaseWarning>(
          (row) => ConductCaseWarning.fromRow(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<List<ConductCaseEvent>> listEvents(String caseId) async {
    final rows = await _client
        .from('conduct_case_events')
        .select('id, event_type, actor_name, notes, created_at')
        .eq('case_id', caseId)
        .order('created_at');

    return rows
        .map<ConductCaseEvent>(ConductCaseEvent.fromRow)
        .toList(growable: false);
  }

  Future<List<ConductCaseEvidence>> listEvidence(String caseId) async {
    final rows = await _client
        .from('conduct_case_evidence')
        .select('id, original_name, caption, created_at')
        .eq('case_id', caseId)
        .order('created_at', ascending: false);

    return rows
        .map<ConductCaseEvidence>(ConductCaseEvidence.fromRow)
        .toList(growable: false);
  }

  Future<void> uploadEvidence({
    required String caseId,
    required String originalName,
    required String contentType,
    required Uint8List bytes,
    required String caption,
  }) async {
    if (bytes.isEmpty) {
      throw ArgumentError('Evidence image cannot be empty.');
    }
    if (bytes.length > 10 * 1024 * 1024) {
      throw ArgumentError('Evidence image must be 10 MB or smaller.');
    }

    final extension = switch (contentType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    final safeName = originalName
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final path = '$caseId/${DateTime.now().microsecondsSinceEpoch}_'
        '${safeName.isEmpty ? 'evidence.$extension' : safeName}';

    await _client.storage.from('conduct_case_evidence').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: false,
          ),
        );

    try {
      await _client.rpc(
        'register_conduct_case_evidence',
        params: {
          'p_case_id': caseId,
          'p_storage_path': path,
          'p_original_name': originalName,
          'p_content_type': contentType,
          'p_size_bytes': bytes.length,
          'p_caption': caption.trim(),
        },
      );
    } catch (_) {
      await _client.storage.from('conduct_case_evidence').remove([path]);
      rethrow;
    }
  }
}

String conductCaseError(Object error) {
  final message =
      error is PostgrestException ? error.message : error.toString();

  if (message.contains('changed. Refresh')) {
    return 'This case changed. Refresh before continuing.';
  }
  if (message.contains('Only owners and caretakers')) {
    return 'Only authorized dormitory staff can perform this action.';
  }
  if (message.contains('not available to your account')) {
    return 'This conduct case is not available to your account.';
  }
  if (message.contains('Please specify the conduct case category')) {
    return 'Please specify the conduct case category.';
  }
  if (message.contains('Please specify the conduct case source')) {
    return 'Please specify the conduct case source.';
  }
  if (message.contains('does not belong to the selected tenant')) {
    return 'That linked record does not belong to the selected tenant. Choose another record or remove the link.';
  }
  if (message.contains('Responses are closed')) {
    return 'Responses are closed for this conduct case.';
  }
  if (message.contains('cannot be issued')) {
    return 'A warning cannot be issued in the current case state.';
  }
  if (message.contains('Termination review cannot')) {
    return 'Termination review cannot be recommended in the current case state.';
  }
  if (message.contains('10 MB')) {
    return 'Evidence images must be 10 MB or smaller.';
  }
  if (message.contains('Unsupported evidence')) {
    return 'Use a JPG, PNG, or WebP evidence image.';
  }
  if (error is StorageException) {
    return 'Unable to upload conduct evidence. Check your connection and try again.';
  }

  return 'Unable to update Conduct & Cases. Check your connection and try again.';
}
