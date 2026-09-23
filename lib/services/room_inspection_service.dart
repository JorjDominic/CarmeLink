import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';

class RoomInspectionRecord {
  const RoomInspectionRecord({
    required this.id,
    required this.roomId,
    required this.inspectionType,
    required this.status,
    required this.scheduledAt,
    required this.noticeText,
    required this.updatedAt,
    this.parentInspectionId,
    this.noticePublishedAt,
    this.summary = '',
    this.startedAt,
    this.completedAt,
    this.cancellationReason = '',
  });

  factory RoomInspectionRecord.fromRow(Map<String, dynamic> row) {
    DateTime? date(String key) {
      final raw = row[key] as String?;
      return raw == null ? null : DateTime.parse(raw).toLocal();
    }

    return RoomInspectionRecord(
      id: row['id'] as String,
      roomId: row['room_id'] as String,
      inspectionType: row['inspection_type'] as String,
      parentInspectionId: row['parent_inspection_id'] as String?,
      status: row['status'] as String,
      scheduledAt: DateTime.parse(row['scheduled_at'] as String).toLocal(),
      noticeText: row['notice_text'] as String? ?? '',
      noticePublishedAt: date('notice_published_at'),
      summary: row['summary'] as String? ?? '',
      startedAt: date('started_at'),
      completedAt: date('completed_at'),
      cancellationReason: row['cancellation_reason'] as String? ?? '',
      updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
    );
  }

  final String id;
  final String roomId;
  final String inspectionType;
  final String? parentInspectionId;
  final String status;
  final DateTime scheduledAt;
  final String noticeText;
  final DateTime? noticePublishedAt;
  final String summary;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String cancellationReason;
  final DateTime updatedAt;
}

class RoomInspectionFinding {
  const RoomInspectionFinding({
    required this.id,
    required this.inspectionId,
    required this.category,
    required this.locationLabel,
    required this.severity,
    required this.description,
    required this.correctiveAction,
    required this.status,
    required this.updatedAt,
    this.actionDueAt,
    this.correctedAt,
    this.evidenceCount = 0,
  });

  factory RoomInspectionFinding.fromRow(
    Map<String, dynamic> row, {
    int evidenceCount = 0,
  }) {
    DateTime? date(String key) {
      final raw = row[key] as String?;
      return raw == null ? null : DateTime.parse(raw).toLocal();
    }

    return RoomInspectionFinding(
      id: row['id'] as String,
      inspectionId: row['inspection_id'] as String,
      category: row['category'] as String,
      locationLabel: row['location_label'] as String,
      severity: row['severity'] as String,
      description: row['description'] as String,
      correctiveAction: row['corrective_action'] as String? ?? '',
      actionDueAt: date('action_due_at'),
      status: row['status'] as String,
      correctedAt: date('corrected_at'),
      updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
      evidenceCount: evidenceCount,
    );
  }

  final String id;
  final String inspectionId;
  final String category;
  final String locationLabel;
  final String severity;
  final String description;
  final String correctiveAction;
  final DateTime? actionDueAt;
  final String status;
  final DateTime? correctedAt;
  final DateTime updatedAt;
  final int evidenceCount;
}

class RoomInspectionService {
  const RoomInspectionService();

  SupabaseClient get _client => SupabaseConfig.client;

  static const String _inspectionColumns =
      'id, room_id, inspection_type, parent_inspection_id, status, '
      'scheduled_at, notice_text, notice_published_at, summary, started_at, '
      'completed_at, cancellation_reason, updated_at';

  static const String _findingColumns =
      'id, inspection_id, category, location_label, severity, description, '
      'corrective_action, action_due_at, status, corrected_at, updated_at';

  Future<List<RoomInspectionRecord>> listRoomInspections(
    String roomId,
  ) async {
    final rows = await _client
        .from('room_inspections')
        .select(_inspectionColumns)
        .eq('room_id', roomId)
        .order('scheduled_at', ascending: false);

    return rows
        .map<RoomInspectionRecord>(RoomInspectionRecord.fromRow)
        .toList(growable: false);
  }

  Future<List<RoomInspectionRecord>> listMyRoomInspections() async {
    final rows = await _client
        .from('room_inspections')
        .select(_inspectionColumns)
        .order('scheduled_at', ascending: false);

    return rows
        .map<RoomInspectionRecord>(RoomInspectionRecord.fromRow)
        .toList(growable: false);
  }

  Future<List<RoomInspectionFinding>> listFindings(
    String inspectionId, {
    bool includeEvidenceCount = false,
  }) async {
    final rows = await _client
        .from('room_inspection_findings')
        .select(_findingColumns)
        .eq('inspection_id', inspectionId)
        .order('created_at');

    final evidenceCounts = <String, int>{};
    if (includeEvidenceCount) {
      final evidenceRows = await _client
          .from('room_inspection_evidence')
          .select('finding_id')
          .eq('inspection_id', inspectionId);

      for (final row in evidenceRows) {
        final id = row['finding_id'] as String?;
        if (id != null) {
          evidenceCounts[id] = (evidenceCounts[id] ?? 0) + 1;
        }
      }
    }

    return rows
        .map<RoomInspectionFinding>(
          (row) => RoomInspectionFinding.fromRow(
            row,
            evidenceCount: evidenceCounts[row['id'] as String] ?? 0,
          ),
        )
        .toList(growable: false);
  }

  Future<String> createInspection({
    required String roomId,
    required String inspectionType,
    required DateTime scheduledAt,
    required String noticeText,
    String? parentInspectionId,
  }) async {
    final result = await _client.rpc(
      'create_room_inspection',
      params: {
        'p_room_id': roomId,
        'p_inspection_type': inspectionType,
        'p_scheduled_at': scheduledAt.toUtc().toIso8601String(),
        'p_notice_text': noticeText.trim(),
        'p_parent_inspection_id': parentInspectionId,
      },
    );
    return result as String;
  }

  Future<void> startInspection(RoomInspectionRecord inspection) async {
    await _client.rpc(
      'start_room_inspection',
      params: {
        'p_inspection_id': inspection.id,
        'p_expected_updated_at': inspection.updatedAt.toUtc().toIso8601String(),
      },
    );
  }

  Future<String> addFinding({
    required RoomInspectionRecord inspection,
    required String category,
    required String locationLabel,
    required String severity,
    required String description,
    required String correctiveAction,
    DateTime? actionDueAt,
  }) async {
    final result = await _client.rpc(
      'add_room_inspection_finding',
      params: {
        'p_inspection_id': inspection.id,
        'p_category': category,
        'p_location_label': locationLabel.trim(),
        'p_severity': severity,
        'p_description': description.trim(),
        'p_corrective_action': correctiveAction.trim(),
        'p_action_due_at': actionDueAt?.toUtc().toIso8601String(),
      },
    );
    return result as String;
  }

  Future<void> updateFinding({
    required RoomInspectionFinding finding,
    required String status,
    required String correctiveAction,
    DateTime? actionDueAt,
  }) async {
    await _client.rpc(
      'update_room_inspection_finding',
      params: {
        'p_finding_id': finding.id,
        'p_expected_updated_at': finding.updatedAt.toUtc().toIso8601String(),
        'p_status': status,
        'p_corrective_action': correctiveAction.trim(),
        'p_action_due_at': actionDueAt?.toUtc().toIso8601String(),
      },
    );
  }

  Future<void> completeInspection({
    required RoomInspectionRecord inspection,
    required String summary,
  }) async {
    await _client.rpc(
      'complete_room_inspection',
      params: {
        'p_inspection_id': inspection.id,
        'p_expected_updated_at': inspection.updatedAt.toUtc().toIso8601String(),
        'p_summary': summary.trim(),
      },
    );
  }

  Future<void> cancelInspection({
    required RoomInspectionRecord inspection,
    required String reason,
  }) async {
    await _client.rpc(
      'cancel_room_inspection',
      params: {
        'p_inspection_id': inspection.id,
        'p_expected_updated_at': inspection.updatedAt.toUtc().toIso8601String(),
        'p_reason': reason.trim(),
      },
    );
  }

  Future<void> uploadEvidence({
    required String inspectionId,
    required String findingId,
    required String originalName,
    required String contentType,
    required Uint8List bytes,
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
    final path =
        '$inspectionId/$findingId/${DateTime.now().microsecondsSinceEpoch}_'
        '${safeName.isEmpty ? 'evidence.$extension' : safeName}';

    await _client.storage.from('room_inspection_evidence').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: false,
          ),
        );

    try {
      await _client.rpc(
        'register_room_inspection_evidence',
        params: {
          'p_inspection_id': inspectionId,
          'p_finding_id': findingId,
          'p_storage_path': path,
          'p_original_name': originalName,
          'p_content_type': contentType,
          'p_size_bytes': bytes.length,
        },
      );
    } catch (_) {
      await _client.storage.from('room_inspection_evidence').remove([path]);
      rethrow;
    }
  }
}

String roomInspectionError(Object error) {
  final message =
      error is PostgrestException ? error.message : error.toString();

  if (message.contains('three days written notice')) {
    return 'Monthly inspections require at least three days written notice.';
  }
  if (message.contains('changed. Refresh')) {
    return 'This record changed. Refresh before continuing.';
  }
  if (message.contains('Only owners and caretakers')) {
    return 'Only authorized dormitory staff can perform this action.';
  }
  if (message.contains('before the scheduled time')) {
    return 'This inspection cannot start before its scheduled time.';
  }
  if (message.contains('completed parent inspection')) {
    return 'A follow-up requires a completed parent inspection.';
  }
  if (message.contains('10 MB')) {
    return 'Evidence images must be 10 MB or smaller.';
  }
  if (message.contains('Unsupported evidence')) {
    return 'Use a JPG, PNG, or WebP evidence image.';
  }
  if (error is StorageException) {
    return 'Unable to upload inspection evidence. Check your connection and try again.';
  }

  return 'Unable to update room inspections. Check your connection and try again.';
}
