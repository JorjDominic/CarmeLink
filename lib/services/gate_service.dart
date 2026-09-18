import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../models/models.dart';

/// Backend service interfacing with the public.gate_events table
/// and secure SECURITY DEFINER RPCs.
///
/// Strictly maintains data minimization: zero coordinate or raw distance
/// data is transmitted or requested.
class GateService {
  const GateService();

  static List<GateEvent>? _cache;
  static DateTime? _lastFetch;

  static List<GateEvent>? get cachedGateEvents => _cache;

  static void invalidateCache() {
    _cache = null;
    _lastFetch = null;
  }

  SupabaseClient get _client => SupabaseConfig.client;

  /// Loads recent gate events chronologically descending.
  ///
  /// If [tenantId] is specified, filters records for that specific tenant.
  Future<List<GateEvent>> loadGateEvents({
    String? tenantId,
    int limit = 50,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _cache != null &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < const Duration(seconds: 15)) {
      if (tenantId != null) {
        return _cache!.where((e) => e.tenantId == tenantId).toList();
      }
      return _cache!;
    }

    try {
      var query = _client.from('gate_events').select('''
        id, tenant_id, direction, verification_method, status, checkpoint_type, checked_at, notes, created_by,
        profiles!tenant_id(full_name),
        creator:profiles!created_by(full_name)
      ''');

      if (tenantId != null) {
        query = query.eq('tenant_id', tenantId);
      }

      final rows = await query
          .order('checked_at', ascending: false)
          .limit(limit);

      final list = (rows as List)
          .map((row) => GateEvent.fromRow(row as Map<String, dynamic>))
          .toList();

      if (tenantId == null) {
        _cache = list;
        _lastFetch = DateTime.now();
      }

      return list;
    } catch (e) {
      // Real data mode: return empty list on connection/table error
      return const [];
    }
  }

  /// Records an on-device evaluated GPS Geofence check via the security definer RPC.
  ///
  /// Zero coordinates or distance values are passed.
  Future<void> recordGeofenceCheckIn({
    String? direction,
    required String status,
    required String checkpointType,
  }) async {
    invalidateCache();

    await _client.rpc('record_tenant_geofence_check', params: {
      'p_direction': direction,
      'p_status': status,
      'p_checkpoint_type': checkpointType,
    });
  }

  /// Records a direct staff-observed entry/exit to resolve UNAVAILABLE gaps.
  Future<void> recordStaffManualLog({
    required String tenantId,
    required String direction,
    required String notes,
    String? tenantName,
  }) async {
    invalidateCache();

    await _client.rpc('record_staff_manual_log', params: {
      'p_tenant_id': tenantId,
      'p_direction': direction,
      'p_notes': notes.trim(),
    });
  }
}

