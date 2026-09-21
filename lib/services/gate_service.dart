import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
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
  static const _pendingKey = 'pending_geofence_events_v1';

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

      final rows =
          await query.order('checked_at', ascending: false).limit(limit);

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

    await flushPendingGeofenceChecks();

    await _sendGeofenceCheck(
      direction: direction,
      status: status,
      checkpointType: checkpointType,
    );
  }

  Future<void> _sendGeofenceCheck({
    String? direction,
    required String status,
    required String checkpointType,
  }) async {
    await _client.rpc('record_tenant_geofence_check', params: {
      'p_direction': direction,
      'p_status': status,
      'p_checkpoint_type': checkpointType,
    });
  }

  /// Synchronizes one native tripwire transition captured while Flutter may
  /// have been suspended. The event ID makes retries idempotent and
  /// [observedAt] preserves detection time when upload is delayed.
  Future<void> recordNativeTransition({
    required String direction,
    required String clientEventId,
    required DateTime observedAt,
  }) async {
    if (direction != 'IN' && direction != 'OUT') {
      throw ArgumentError.value(direction, 'direction', 'Must be IN or OUT');
    }
    invalidateCache();
    await _client.rpc('record_tenant_geofence_transition', params: {
      'p_direction': direction,
      'p_observed_at': observedAt.toUtc().toIso8601String(),
      'p_client_event_id': clientEventId,
    });
  }

  /// Persists only minimized presence state for bounded offline recovery.
  Future<void> queueGeofenceCheck({
    String? direction,
    required String status,
    required String checkpointType,
  }) async {
    final tenantId = SupabaseConfig.clientSafe?.auth.currentUser?.id;
    if (tenantId == null) return;
    final preferences = await SharedPreferences.getInstance();
    final queue = preferences.getStringList(_pendingKey) ?? <String>[];
    queue.add(jsonEncode({
      'tenant_id': tenantId,
      'direction': direction,
      'status': status,
      'checkpoint_type': checkpointType,
      'queued_at': DateTime.now().toUtc().toIso8601String(),
    }));
    // Bound storage and retries to the most recent 24 minimized events.
    await preferences.setStringList(
      _pendingKey,
      queue.length <= 24 ? queue : queue.sublist(queue.length - 24),
    );
  }

  Future<void> flushPendingGeofenceChecks() async {
    final tenantId = SupabaseConfig.clientSafe?.auth.currentUser?.id;
    if (tenantId == null) return;
    final preferences = await SharedPreferences.getInstance();
    final queue = preferences.getStringList(_pendingKey) ?? <String>[];
    if (queue.isEmpty) return;
    final remaining = <String>[];
    for (final encoded in queue) {
      try {
        final event = jsonDecode(encoded) as Map<String, dynamic>;
        if (event['tenant_id'] != tenantId) continue;
        final queuedAt = DateTime.tryParse(event['queued_at'] as String? ?? '');
        if (queuedAt == null ||
            DateTime.now().toUtc().difference(queuedAt) >
                const Duration(hours: 24)) {
          continue;
        }
        await _sendGeofenceCheck(
          direction: event['direction'] as String?,
          status: event['status'] as String,
          checkpointType: event['checkpoint_type'] as String,
        );
      } catch (_) {
        remaining.add(encoded);
      }
    }
    await preferences.setStringList(_pendingKey, remaining);
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
