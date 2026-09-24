import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';

class CleaningScheduleRecord {
  const CleaningScheduleRecord({
    required this.id,
    required this.bedSpaceId,
    required this.weekday,
    required this.taskNotes,
    required this.updatedAt,
    this.bedLabel = '',
  });

  factory CleaningScheduleRecord.fromRow(
    Map<String, dynamic> row, {
    String bedLabel = '',
  }) {
    return CleaningScheduleRecord(
      id: row['id'] as String? ?? '',
      bedSpaceId: row['bed_space_id'] as String,
      weekday: (row['weekday'] as num).toInt(),
      taskNotes: row['task_notes'] as String? ?? '',
      updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
      bedLabel: bedLabel,
    );
  }

  final String id;
  final String bedSpaceId;
  final String bedLabel;
  final int weekday;
  final String taskNotes;
  final DateTime updatedAt;
}

class CleaningNoncomplianceReport {
  const CleaningNoncomplianceReport({
    required this.id,
    required this.reporterId,
    required this.reportedBedSpaceId,
    required this.reportedBedLabel,
    required this.description,
    required this.status,
    required this.staffNotes,
    required this.createdAt,
    required this.updatedAt,
    this.reporterName,
  });

  factory CleaningNoncomplianceReport.fromRow(
    Map<String, dynamic> row, {
    String? reporterName,
  }) {
    return CleaningNoncomplianceReport(
      id: row['id'] as String,
      reporterId: row['reporter_id'] as String,
      reportedBedSpaceId: row['reported_bed_space_id'] as String,
      reportedBedLabel: row['reported_bed_label'] as String,
      description: row['description'] as String,
      status: row['status'] as String,
      staffNotes: row['staff_notes'] as String? ?? '',
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
      reporterName: reporterName,
    );
  }

  final String id;
  final String reporterId;
  final String reportedBedSpaceId;
  final String reportedBedLabel;
  final String description;
  final String status;
  final String staffNotes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? reporterName;
}

class TenantCleaningContext {
  const TenantCleaningContext({
    required this.roomId,
    required this.roomNumber,
    required this.ownBedSpaceId,
    required this.ownBedLabel,
    required this.schedules,
    required this.reports,
  });

  final String roomId;
  final String roomNumber;
  final String ownBedSpaceId;
  final String ownBedLabel;
  final List<CleaningScheduleRecord> schedules;
  final List<CleaningNoncomplianceReport> reports;
}

class RoomOperationsService {
  const RoomOperationsService();

  SupabaseClient get _client => SupabaseConfig.client;

  static const String _reportColumns =
      'id, reporter_id, reported_bed_space_id, reported_bed_label, '
      'description, status, staff_notes, created_at, updated_at';

  Future<List<CleaningScheduleRecord>> listSchedulesForBeds(
    Iterable<String> bedSpaceIds,
  ) async {
    final ids = bedSpaceIds.where((id) => id.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return const [];

    final rows = await _client
        .from('cleaning_schedules')
        .select('id, bed_space_id, weekday, task_notes, updated_at')
        .inFilter('bed_space_id', ids)
        .eq('is_active', true)
        .order('weekday');

    return rows
        .map<CleaningScheduleRecord>(
          (row) => CleaningScheduleRecord.fromRow(row),
        )
        .toList(growable: false);
  }

  Future<void> setBedSchedule({
    required String bedSpaceId,
    required List<int> weekdays,
    required String taskNotes,
  }) async {
    await _client.rpc(
      'set_cleaning_schedule',
      params: {
        'p_bed_space_id': bedSpaceId,
        'p_weekdays': weekdays,
        'p_task_notes': taskNotes.trim(),
      },
    );
  }

  Future<TenantCleaningContext?> loadMyCleaningContext() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException(
        'Your session has expired. Please sign in again.',
      );
    }

    final assignment = await _client
        .from('tenant_assignments')
        .select(
          'bed_space_id, '
          'bed_spaces!inner(id, label, room_id, '
          'rooms!inner(id, room_number))',
        )
        .eq('tenant_id', userId)
        .eq('status', 'active')
        .maybeSingle();

    if (assignment == null) return null;

    final bed = assignment['bed_spaces'] as Map<String, dynamic>?;
    final room = bed?['rooms'] as Map<String, dynamic>?;
    if (bed == null || room == null) return null;

    final raw = await _client.rpc('get_my_room_cleaning_schedule');
    final rawSchedules = raw is List ? raw : const <dynamic>[];

    final schedules = rawSchedules.map((item) {
      final row = Map<String, dynamic>.from(item as Map);
      return CleaningScheduleRecord(
        id: '',
        bedSpaceId: row['bed_space_id'] as String,
        bedLabel: row['bed_label'] as String? ?? 'Bed',
        weekday: (row['weekday'] as num).toInt(),
        taskNotes: row['task_notes'] as String? ?? '',
        updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
      );
    }).toList(growable: false);

    return TenantCleaningContext(
      roomId: room['id'] as String,
      roomNumber: room['room_number'] as String,
      ownBedSpaceId: bed['id'] as String,
      ownBedLabel: bed['label'] as String,
      schedules: schedules,
      reports: await listMyReports(),
    );
  }

  Future<List<CleaningNoncomplianceReport>> listMyReports() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];

    final rows = await _client
        .from('cleaning_noncompliance_reports')
        .select(_reportColumns)
        .eq('reporter_id', userId)
        .order('created_at', ascending: false);

    return rows
        .map<CleaningNoncomplianceReport>(
          (row) => CleaningNoncomplianceReport.fromRow(row),
        )
        .toList(growable: false);
  }

  Future<void> submitCleaningReport({
    required String reportedBedSpaceId,
    required String description,
  }) async {
    await _client.rpc(
      'submit_cleaning_noncompliance_report',
      params: {
        'p_reported_bed_space_id': reportedBedSpaceId,
        'p_description': description.trim(),
      },
    );
  }

  Future<List<CleaningNoncomplianceReport>> listReportsForBeds(
    Iterable<String> bedSpaceIds,
  ) async {
    final ids = bedSpaceIds.where((id) => id.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return const [];

    final rows = await _client
        .from('cleaning_noncompliance_reports')
        .select(_reportColumns)
        .inFilter('reported_bed_space_id', ids)
        .order('created_at', ascending: false);

    final reporterIds = rows
        .map<String>((row) => row['reporter_id'] as String)
        .toSet()
        .toList();

    final names = <String, String>{};
    if (reporterIds.isNotEmpty) {
      final profileRows = await _client
          .from('profiles')
          .select('id, full_name')
          .inFilter('id', reporterIds);

      for (final row in profileRows) {
        names[row['id'] as String] = row['full_name'] as String? ?? 'Tenant';
      }
    }

    return rows
        .map<CleaningNoncomplianceReport>(
          (row) => CleaningNoncomplianceReport.fromRow(
            row,
            reporterName: names[row['reporter_id'] as String] ?? 'Tenant',
          ),
        )
        .toList(growable: false);
  }

  Future<void> updateCleaningReport({
    required CleaningNoncomplianceReport report,
    required String status,
    required String staffNotes,
  }) async {
    await _client.rpc(
      'update_cleaning_noncompliance_report',
      params: {
        'p_report_id': report.id,
        'p_expected_updated_at': report.updatedAt.toUtc().toIso8601String(),
        'p_status': status,
        'p_staff_notes': staffNotes.trim(),
      },
    );
  }
}

String roomOperationsError(Object error) {
  final message =
      error is PostgrestException ? error.message : error.toString();

  if (message.contains('changed. Reload')) {
    return 'This record changed. Refresh and try again.';
  }
  if (message.contains('Only owners and caretakers')) {
    return 'Only authorized dormitory staff can perform that action.';
  }
  if (message.contains('Only tenants')) {
    return 'This action is available only to an assigned tenant.';
  }
  if (message.contains('active room assignment')) {
    return 'An active room assignment is required.';
  }
  if (message.contains('only within your assigned room')) {
    return 'You can report only cleaning duties in your assigned room.';
  }
  if (message.contains('no active cleaning duty')) {
    return 'That bed does not currently have a cleaning duty to report.';
  }
  if (message.contains('500 characters')) {
    return 'Cleaning instructions must be 500 characters or fewer.';
  }
  if (message.contains('1500 characters')) {
    return 'Report details must be between 5 and 1500 characters.';
  }
  if (message.contains('resolution notes') ||
      message.contains('dismissal reason')) {
    return 'Add staff notes before closing this report.';
  }
  return 'Unable to update room operations. Check your connection and try again.';
}
