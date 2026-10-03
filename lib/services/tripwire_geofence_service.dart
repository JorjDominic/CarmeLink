import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../controllers/tenant_controller.dart';
import '../core/config/supabase_config.dart';
import 'gate_service.dart';
import 'geofence_service.dart';
import 'push_notification_service.dart';

/// Coordinates the native, low-power IN/OUT tripwire with authenticated sync.
///
/// Native code captures minimized transitions while Flutter is suspended. On
/// registration it seeds native monitoring from the last server-recorded
/// direction, allowing accurate native fixes to reconcile a crossing missed
/// during an Android force-stop or another monitoring interruption.
class TripwireGeofenceService {
  TripwireGeofenceService._();

  static final TripwireGeofenceService instance = TripwireGeofenceService._();

  static const MethodChannel _channel =
      MethodChannel('carmelitas/tripwire_geofence');
  static const Duration deliveryTarget = Duration(minutes: 15);
  static const Duration _platformTimeout = Duration(seconds: 5);

  final GateService _gateService = const GateService();
  final GeofenceLocationService _locationService =
      const GeofenceLocationService();
  bool _syncing = false;

  Future<void> start(String tenantId) async {
    if (kIsWeb) return;
    try {
      final row = await SupabaseConfig.client
          .from('dorm_boundary_config')
          .select()
          .eq('is_active', true)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return;

      GeofenceLocationService.applyBoundaryConfiguration(row);
      final baseline = await _locationService.checkCurrentPresence();
      try {
        await _updateMonitoringReminder(baseline);
      } catch (error) {
        // Reminder failures must not prevent the original tripwire registration.
        debugPrint('Could not show location monitoring reminder: $error');
      }
      final serverDirection = await _loadServerDirection(tenantId);
      final session = SupabaseConfig.client.auth.currentSession;
      if (session == null) return;
      final rawPolygon = row['polygon_points'];
      final polygon = rawPolygon is List
          ? rawPolygon
              .whereType<Map>()
              .map((point) => <String, double>{
                    'lat': (point['lat'] as num).toDouble(),
                    'lng': (point['lng'] as num).toDouble(),
                  })
              .toList()
          : const <Map<String, double>>[];
      await _channel.invokeMethod<void>('register', {
        'tenantId': tenantId,
        'latitude': (row['center_latitude'] as num).toDouble(),
        'longitude': (row['center_longitude'] as num).toDouble(),
        'radiusMeters': (row['radius_meters'] as num).toDouble(),
        // Prefer durable server state. If it differs from the current physical
        // side, native code requires two accurate matching fixes before it
        // records a reconciliation transition.
        'initialDirection': serverDirection ??
            (baseline.isUnavailable ? null : baseline.direction),
        'polygon': polygon,
        'edgeBufferMeters':
            (row['edge_buffer_meters'] as num?)?.toDouble() ?? 3.0,
        'gateEnabled': row['gate_enabled'] == true,
        'gateStartLatitude': row['gate_start_latitude'],
        'gateStartLongitude': row['gate_start_longitude'],
        'gateEndLatitude': row['gate_end_latitude'],
        'gateEndLongitude': row['gate_end_longitude'],
        'gateToleranceMeters':
            (row['gate_tolerance_meters'] as num?)?.toDouble() ?? 15.0,
        'configVersion': (row['config_version'] as num?)?.toInt() ?? 1,
        'accessToken': session.accessToken,
        'refreshToken': session.refreshToken,
        'supabaseUrl': SupabaseConfig.url,
        'publishableKey': SupabaseConfig.publishableKey,
      }).timeout(_platformTimeout);
      await syncPending();
      // Native iOS may have completed the upload itself while Flutter was
      // suspended, so always reconcile the visible presence state on resume.
      await TenantController.instance.loadGateEvents(force: true);
    } on MissingPluginException {
      // Desktop and unsupported test platforms do not install native adapters.
    } catch (error) {
      debugPrint('Could not start native tripwire monitoring: $error');
    }
  }

  Future<void> _updateMonitoringReminder(GeofenceCheckResult result) async {
    const reminderKey = 'tripwire_flutter_last_location_reminder_at';
    final preferences = await SharedPreferences.getInstance();
    if (!result.isUnavailable) {
      await preferences.remove(reminderKey);
      return;
    }
    if (result.failureReason != GeofenceFailureReason.locationServiceDisabled &&
        result.failureReason != GeofenceFailureReason.permissionDenied) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = preferences.getInt(reminderKey) ?? 0;
    if (now - last < const Duration(hours: 1).inMilliseconds) return;
    await preferences.setInt(reminderKey, now);
    final permissionMissing =
        result.failureReason == GeofenceFailureReason.permissionDenied;
    await PushNotificationService.instance.showLocalNotification(
      id: 1003,
      title: 'Location monitoring is off',
      body: permissionMissing
          ? 'Allow precise location all the time to restore entry and exit alerts.'
          : 'Turn on Location to restore dormitory entry and exit alerts.',
      payload: {
        'route_type': 'location_settings',
        'reason': permissionMissing
            ? 'LOCATION_PERMISSION_DENIED'
            : 'LOCATION_SERVICES_DISABLED',
      },
    );
  }

  Future<String?> _loadServerDirection(String tenantId) async {
    try {
      final row = await SupabaseConfig.client
          .from('tenant_details')
          .select('current_gate_status')
          .eq('profile_id', tenantId)
          .maybeSingle();
      final direction = row?['current_gate_status'];
      return direction == 'IN' || direction == 'OUT'
          ? direction as String
          : null;
    } catch (error) {
      debugPrint(
          'Could not load server gate status for reconciliation: $error');
      return null;
    }
  }

  Future<void> stop() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>('unregister').timeout(_platformTimeout);
    } on MissingPluginException {
      // No native adapter on this platform.
    } catch (error) {
      debugPrint('Could not stop native tripwire monitoring: $error');
    }
  }

  Future<void> syncPending() async {
    if (kIsWeb || _syncing) return;
    final activeTenant = SupabaseConfig.clientSafe?.auth.currentUser?.id;
    if (activeTenant == null) return;
    _syncing = true;
    try {
      final raw = await _channel
              .invokeListMethod<dynamic>('consumePending')
              .timeout(_platformTimeout) ??
          const <dynamic>[];
      final events = raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList()
        ..sort((a, b) =>
            (a['observed_at'] as num).compareTo(b['observed_at'] as num));

      String? lastSyncedDirection;
      for (final event in events) {
        if (event['tenant_id'] != activeTenant) continue;
        final eventId = event['event_id'] as String;
        try {
          await _gateService.recordNativeTransition(
            direction: event['direction'] as String,
            clientEventId: eventId,
            observedAt: DateTime.fromMillisecondsSinceEpoch(
              (event['observed_at'] as num).toInt(),
              isUtc: true,
            ),
          );
          await _channel.invokeMethod<void>('acknowledge', {
            'eventId': eventId,
          }).timeout(_platformTimeout);
          lastSyncedDirection = event['direction'] as String?;
        } catch (error) {
          debugPrint('Native tripwire event remains queued: $error');
          break;
        }
      }

      // After syncing background events, update TenantController so the
      // curfew/presence UI shows the correct IN/OUT state immediately.
      if (lastSyncedDirection != null) {
        TenantController.instance.applyGeofenceCrossing(lastSyncedDirection);
      }
    } on MissingPluginException {
      // No native adapter on this platform.
    } catch (error) {
      debugPrint('Could not synchronize native tripwire events: $error');
    } finally {
      _syncing = false;
    }
  }

  Future<Map<String, dynamic>> status() async {
    if (kIsWeb) return const {'registered': false, 'supported': false};
    try {
      final value = await _channel
          .invokeMapMethod<String, dynamic>('status')
          .timeout(_platformTimeout);
      return value ?? const {'registered': false};
    } catch (_) {
      return const {'registered': false, 'supported': false};
    }
  }
}
