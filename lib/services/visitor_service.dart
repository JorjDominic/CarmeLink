import '../core/config/supabase_config.dart';
import '../models/models.dart';

class VisitorService {
  const VisitorService();

  static const _columns =
      'id, tenant_id, visitor_name, relationship, purpose, schedule, status, '
      'review_note, decided_by, decided_at, arrived_at, departed_at, created_at, updated_at';
  static const _staffColumns =
      '$_columns, tenant:profiles!visitor_requests_tenant_id_fkey(full_name)';
  static const _eventColumns =
      'id, request_id, event_type, actor_id, note, occurred_at, '
      'actor:profiles!visitor_events_actor_id_fkey(full_name)';

  Future<List<VisitorRequest>> listOwnRequests() async {
    final client = SupabaseConfig.clientSafe;
    final tenantId = client?.auth.currentUser?.id;
    if (client == null || tenantId == null) return const [];

    final rows = await client
        .from('visitor_requests')
        .select(_columns)
        .eq('tenant_id', tenantId)
        .order('schedule', ascending: false);
    return rows
        .map<VisitorRequest>((row) => VisitorRequest.fromRow(row))
        .toList(growable: false);
  }

  Future<List<VisitorRequest>> listStaffRequests() async {
    final client = SupabaseConfig.clientSafe;
    if (client == null) return const [];

    final rows = await client
        .from('visitor_requests')
        .select(_staffColumns)
        .order('schedule', ascending: false);
    return rows
        .map<VisitorRequest>((row) => VisitorRequest.fromRow(row))
        .toList(growable: false);
  }

  Future<VisitorRequest> submit({
    required String visitorName,
    required String relationship,
    required String purpose,
    required DateTime schedule,
  }) async {
    final client = SupabaseConfig.clientSafe;
    final tenantId = client?.auth.currentUser?.id;
    if (client == null || tenantId == null) {
      throw Exception('Authentication is required to submit a visitor request');
    }

    final row = await client
        .from('visitor_requests')
        .insert({
          'tenant_id': tenantId,
          'visitor_name': visitorName.trim(),
          'relationship': relationship.trim(),
          'purpose': purpose.trim(),
          'schedule': schedule.toUtc().toIso8601String(),
          'status': 'pending',
        })
        .select(_columns)
        .single();
    return VisitorRequest.fromRow(row);
  }

  Future<VisitorRequest> updatePending({
    required String requestId,
    required String visitorName,
    required String relationship,
    required String purpose,
    required DateTime schedule,
  }) async {
    final client = SupabaseConfig.clientSafe;
    if (client == null) throw Exception('Database client not available');
    final row = await client
        .from('visitor_requests')
        .update({
          'visitor_name': visitorName.trim(),
          'relationship': relationship.trim(),
          'purpose': purpose.trim(),
          'schedule': schedule.toUtc().toIso8601String(),
        })
        .eq('id', requestId)
        .eq('status', 'pending')
        .select(_columns)
        .single();
    return VisitorRequest.fromRow(row);
  }

  Future<VisitorRequest> transition({
    required String requestId,
    required String action,
    String? note,
  }) async {
    final client = SupabaseConfig.clientSafe;
    if (client == null) throw Exception('Database client not available');
    final value = await client.rpc('transition_visitor_request', params: {
      'p_request_id': requestId,
      'p_action': action,
      'p_note': note?.trim(),
    });
    return VisitorRequest.fromRow(Map<String, dynamic>.from(value as Map));
  }

  Future<List<VisitorEvent>> listEvents(String requestId) async {
    final client = SupabaseConfig.clientSafe;
    if (client == null) return const [];
    final rows = await client
        .from('visitor_events')
        .select(_eventColumns)
        .eq('request_id', requestId)
        .order('occurred_at', ascending: false);
    return rows
        .map<VisitorEvent>((row) => VisitorEvent.fromRow(row))
        .toList(growable: false);
  }
}
