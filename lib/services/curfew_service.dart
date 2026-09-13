import '../core/config/supabase_config.dart';
import '../models/models.dart';

class CurfewService {
  const CurfewService();

  static const String _columns =
      'id, tenant_id, destination, reason, departure_time, expected_return_time, '
      'status, request_type, guardian_id, guardian_decision, guardian_remarks, guardian_decided_at, '
      'staff_id, staff_decision, staff_notes, staff_decided_at, created_at, updated_at';

  static const String columnsWithTenant =
      '$_columns, tenant:profiles!curfew_requests_tenant_id_fkey(full_name)';

  /// Lists all curfew requests submitted by the current authenticated tenant.
  Future<List<CurfewRequest>> listOwnRequests() async {
    final client = SupabaseConfig.clientSafe;
    if (client == null) return const [];

    final tenantId = client.auth.currentUser?.id;
    if (tenantId == null) return const [];

    try {
      final rows = await client
          .from('curfew_requests')
          .select(_columns)
          .eq('tenant_id', tenantId)
          .order('departure_time', ascending: false);

      return rows
          .map<CurfewRequest>((row) => CurfewRequest.fromJson(row))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// Submits a new curfew exception request as a tenant.
  Future<CurfewRequest> submitRequest({
    required String destination,
    required String reason,
    required DateTime departureTime,
    required DateTime expectedReturnTime,
    String requestType = 'late_return',
  }) async {
    final client = SupabaseConfig.clientSafe;
    if (client == null) {
      throw Exception('Database client not available');
    }

    final tenantId = client.auth.currentUser?.id;
    if (tenantId == null) {
      throw Exception('Authentication required to submit curfew exception');
    }

    final initialStatus = requestType == 'overnight_leave'
        ? 'pending_guardian'
        : 'pending_staff';

    final row = await client
        .from('curfew_requests')
        .insert({
          'tenant_id': tenantId,
          'destination': destination.trim(),
          'reason': reason.trim(),
          'departure_time': departureTime.toUtc().toIso8601String(),
          'expected_return_time': expectedReturnTime.toUtc().toIso8601String(),
          'request_type': requestType,
          'status': initialStatus,
        })
        .select(_columns)
        .single();

    return CurfewRequest.fromJson(row);
  }

  /// Cancels an existing pending curfew request.
  Future<CurfewRequest> cancelRequest(String requestId) async {
    final client = SupabaseConfig.clientSafe;
    if (client == null) {
      throw Exception('Database client not available');
    }

    final row = await client
        .from('curfew_requests')
        .update({'status': 'cancelled'})
        .eq('id', requestId)
        .select(_columns)
        .single();

    return CurfewRequest.fromJson(row);
  }

  /// Lists all curfew requests across the dormitory for staff (owner/caretaker).
  Future<List<CurfewRequest>> listStaffRequests() async {
    final client = SupabaseConfig.clientSafe;
    if (client == null) return const [];

    try {
      final rows = await client
          .from('curfew_requests')
          .select(columnsWithTenant)
          .order('departure_time', ascending: false);

      return rows
          .map<CurfewRequest>((row) => CurfewRequest.fromJson(row))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// Staff decision on a curfew request (approve or reject with optional notes).
  Future<CurfewRequest> decideStaffRequest({
    required String requestId,
    required bool approve,
    String? notes,
  }) async {
    final client = SupabaseConfig.clientSafe;
    if (client == null) {
      throw Exception('Database client not available');
    }

    final decision = approve ? 'approved' : 'rejected';
    final payload = <String, dynamic>{
      'staff_decision': decision,
      if (notes != null && notes.trim().isNotEmpty) 'staff_notes': notes.trim(),
    };

    final row = await client
        .from('curfew_requests')
        .update(payload)
        .eq('id', requestId)
        .select(columnsWithTenant)
        .single();

    return CurfewRequest.fromJson(row);
  }

  /// Lists curfew requests for the guardian's linked resident(s).
  Future<List<CurfewRequest>> listGuardianRequests({String? tenantId}) async {
    final client = SupabaseConfig.clientSafe;
    if (client == null) return const [];

    try {
      var query = client
          .from('curfew_requests')
          .select(columnsWithTenant);

      if (tenantId != null && tenantId.trim().isNotEmpty) {
        query = query.eq('tenant_id', tenantId.trim());
      }

      final rows = await query.order('departure_time', ascending: false);

      return rows
          .map<CurfewRequest>((row) => CurfewRequest.fromJson(row))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// Guardian decision on an overnight leave request (endorse/approve or decline/reject with remarks).
  Future<CurfewRequest> decideGuardianRequest({
    required String requestId,
    required bool approve,
    String? remarks,
  }) async {
    final client = SupabaseConfig.clientSafe;
    if (client == null) {
      throw Exception('Database client not available');
    }

    final decision = approve ? 'approved' : 'rejected';
    final payload = <String, dynamic>{
      'guardian_decision': decision,
      if (remarks != null && remarks.trim().isNotEmpty)
        'guardian_remarks': remarks.trim(),
    };

    final row = await client
        .from('curfew_requests')
        .update(payload)
        .eq('id', requestId)
        .select(columnsWithTenant)
        .single();

    return CurfewRequest.fromJson(row);
  }
}

