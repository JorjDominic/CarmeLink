import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../core/utils/employee_curfew_policy.dart';

class EmployeeCurfewTenantOption {
  const EmployeeCurfewTenantOption({required this.id, required this.name});

  final String id;
  final String name;
}

class EmployeeCurfewProfileRecord {
  const EmployeeCurfewProfileRecord({
    required this.id,
    required this.tenantId,
    required this.allowedReturnMinutes,
    required this.weekdays,
    required this.effectiveFrom,
    required this.workScheduleNote,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.tenantName,
    this.effectiveUntil,
    this.approvalNote = '',
    this.approvedAt,
    this.revokedAt,
    this.revocationReason = '',
  });

  factory EmployeeCurfewProfileRecord.fromRow(
    Map<String, dynamic> row, {
    String? tenantName,
  }) {
    DateTime? nullableDateTime(String key) {
      final raw = row[key] as String?;
      return raw == null ? null : DateTime.parse(raw).toLocal();
    }

    DateTime? nullableDateOnly(String key) {
      final raw = row[key] as String?;
      return raw == null ? null : DateTime.parse(raw);
    }

    return EmployeeCurfewProfileRecord(
      id: row['id'] as String,
      tenantId: row['tenant_id'] as String,
      tenantName: tenantName,
      allowedReturnMinutes:
          employeeCurfewMinutesFromSql(row['allowed_return_time'] as String),
      weekdays: (row['weekdays'] as List<dynamic>)
          .map((value) => (value as num).toInt())
          .toList(growable: false),
      effectiveFrom: DateTime.parse(row['effective_from'] as String),
      effectiveUntil: nullableDateOnly('effective_until'),
      workScheduleNote: row['work_schedule_note'] as String,
      status: row['status'] as String,
      approvalNote: row['approval_note'] as String? ?? '',
      approvedAt: nullableDateTime('approved_at'),
      revokedAt: nullableDateTime('revoked_at'),
      revocationReason: row['revocation_reason'] as String? ?? '',
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
    );
  }

  final String id;
  final String tenantId;
  final String? tenantName;
  final int allowedReturnMinutes;
  final List<int> weekdays;
  final DateTime effectiveFrom;
  final DateTime? effectiveUntil;
  final String workScheduleNote;
  final String status;
  final String approvalNote;
  final DateTime? approvedAt;
  final DateTime? revokedAt;
  final String revocationReason;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class EmployeeCurfewProfileEvent {
  const EmployeeCurfewProfileEvent({
    required this.id,
    required this.eventType,
    required this.actorName,
    required this.notes,
    required this.createdAt,
  });

  factory EmployeeCurfewProfileEvent.fromRow(Map<String, dynamic> row) {
    return EmployeeCurfewProfileEvent(
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

class EmployeeCurfewProfileService {
  const EmployeeCurfewProfileService();

  SupabaseClient get _client => SupabaseConfig.client;

  static const _columns =
      'id, tenant_id, allowed_return_time, weekdays, effective_from, '
      'effective_until, work_schedule_note, status, approval_note, '
      'approved_at, revoked_at, revocation_reason, created_at, updated_at';

  Future<List<EmployeeCurfewTenantOption>> listTenantOptions() async {
    final rows = await _client
        .from('profiles')
        .select('id, full_name')
        .eq('role', 'tenant')
        .order('full_name');

    return rows
        .map<EmployeeCurfewTenantOption>(
          (row) => EmployeeCurfewTenantOption(
            id: row['id'] as String,
            name: (row['full_name'] as String?)?.trim().isNotEmpty == true
                ? (row['full_name'] as String).trim()
                : 'Tenant',
          ),
        )
        .toList(growable: false);
  }

  Future<List<EmployeeCurfewProfileRecord>> listStaffProfiles() async {
    final rows = await _client
        .from('employee_curfew_profiles')
        .select(_columns)
        .order('created_at', ascending: false);

    final tenantIds = rows
        .map<String>((row) => row['tenant_id'] as String)
        .toSet()
        .toList(growable: false);

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
        .map<EmployeeCurfewProfileRecord>(
          (row) => EmployeeCurfewProfileRecord.fromRow(
            row,
            tenantName: names[row['tenant_id'] as String] ?? 'Tenant',
          ),
        )
        .toList(growable: false);
  }

  Future<List<EmployeeCurfewProfileRecord>> listMyApprovedProfiles() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const [];

    final rows = await _client
        .from('employee_curfew_profiles')
        .select(_columns)
        .eq('tenant_id', uid)
        .eq('status', 'approved')
        .order('effective_from', ascending: false);

    return rows
        .map<EmployeeCurfewProfileRecord>(
          EmployeeCurfewProfileRecord.fromRow,
        )
        .toList(growable: false);
  }

  Future<String> createProfile({
    required String tenantId,
    required int allowedReturnMinutes,
    required List<int> weekdays,
    required DateTime effectiveFrom,
    DateTime? effectiveUntil,
    required String workScheduleNote,
  }) async {
    final result = await _client.rpc(
      'create_employee_curfew_profile',
      params: {
        'p_tenant_id': tenantId,
        'p_allowed_return_time': employeeCurfewTimeSql(allowedReturnMinutes),
        'p_weekdays': weekdays,
        'p_effective_from': _dateSql(effectiveFrom),
        'p_effective_until':
            effectiveUntil == null ? null : _dateSql(effectiveUntil),
        'p_work_schedule_note': workScheduleNote.trim(),
      },
    );
    return result as String;
  }

  Future<void> updateProfile({
    required EmployeeCurfewProfileRecord profile,
    required int allowedReturnMinutes,
    required List<int> weekdays,
    required DateTime effectiveFrom,
    DateTime? effectiveUntil,
    required String workScheduleNote,
  }) async {
    await _client.rpc(
      'update_employee_curfew_profile',
      params: {
        'p_profile_id': profile.id,
        'p_expected_updated_at': profile.updatedAt.toUtc().toIso8601String(),
        'p_allowed_return_time': employeeCurfewTimeSql(allowedReturnMinutes),
        'p_weekdays': weekdays,
        'p_effective_from': _dateSql(effectiveFrom),
        'p_effective_until':
            effectiveUntil == null ? null : _dateSql(effectiveUntil),
        'p_work_schedule_note': workScheduleNote.trim(),
      },
    );
  }

  Future<void> approveProfile({
    required EmployeeCurfewProfileRecord profile,
    required String note,
  }) async {
    await _client.rpc(
      'approve_employee_curfew_profile',
      params: {
        'p_profile_id': profile.id,
        'p_expected_updated_at': profile.updatedAt.toUtc().toIso8601String(),
        'p_approval_note': note.trim(),
      },
    );
  }

  Future<void> revokeProfile({
    required EmployeeCurfewProfileRecord profile,
    required String reason,
  }) async {
    await _client.rpc(
      'revoke_employee_curfew_profile',
      params: {
        'p_profile_id': profile.id,
        'p_expected_updated_at': profile.updatedAt.toUtc().toIso8601String(),
        'p_reason': reason.trim(),
      },
    );
  }

  Future<List<EmployeeCurfewProfileEvent>> listEvents(
    String profileId,
  ) async {
    final rows = await _client
        .from('employee_curfew_profile_events')
        .select('id, event_type, actor_name, notes, created_at')
        .eq('profile_id', profileId)
        .order('created_at');

    return rows
        .map<EmployeeCurfewProfileEvent>(
          EmployeeCurfewProfileEvent.fromRow,
        )
        .toList(growable: false);
  }

  Future<EmployeeCurfewProfileRecord?> resolveMyEffectiveProfile({
    DateTime? at,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;

    final result = await _client.rpc(
      'resolve_employee_curfew_profile',
      params: {
        'p_tenant_id': uid,
        'p_at': (at ?? DateTime.now()).toUtc().toIso8601String(),
      },
    );

    final rows = result is List ? result : const <dynamic>[];
    if (rows.isEmpty) return null;

    final resolved = Map<String, dynamic>.from(rows.first as Map);
    final profiles = await listMyApprovedProfiles();

    for (final profile in profiles) {
      if (profile.id == resolved['profile_id']) return profile;
    }
    return null;
  }

  static String _dateSql(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

String employeeCurfewProfileError(Object error) {
  final message =
      error is PostgrestException ? error.message : error.toString();

  if (message.contains('changed. Refresh')) {
    return 'This employee curfew profile changed. Refresh before continuing.';
  }
  if (message.contains('Only owners and caretakers')) {
    return 'Only authorized dormitory staff can manage employee curfew profiles.';
  }
  if (message.contains('overlapping approved')) {
    return 'This tenant already has an approved employee curfew profile for an overlapping date range.';
  }
  if (message.contains('Only draft')) {
    return 'Only draft employee curfew profiles can be edited or approved.';
  }
  if (message.contains('already-ended')) {
    return 'An already-ended profile cannot be approved.';
  }
  if (message.contains('not available to your account')) {
    return 'This employee curfew profile is not available to your account.';
  }

  return 'Unable to update employee curfew profiles. Check your connection and try again.';
}
