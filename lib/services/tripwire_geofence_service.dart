import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/config/supabase_config.dart';
import 'gate_service.dart';
import 'geofence_service.dart';

/// Coordinates the native, low-power IN/OUT tripwire with authenticated sync.
///
/// Native code captures minimized transitions while Flutter is suspended. This
/// service establishes the initial baseline without logging it, then drains
/// confirmed transitions through the existing secure Supabase boundary.
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
      final session = SupabaseConfig.client.auth.currentSession;
      if (session == null) return;
      await _channel.invokeMethod<void>('register', {
        'tenantId': tenantId,
        'latitude': (row['center_latitude'] as num).toDouble(),
        'longitude': (row['center_longitude'] as num).toDouble(),
        'radiusMeters': (row['radius_meters'] as num).toDouble(),
        'initialDirection': baseline.isUnavailable ? null : baseline.direction,
        'accessToken': session.accessToken,
        'refreshToken': session.refreshToken,
        'supabaseUrl': SupabaseConfig.url,
        'publishableKey': SupabaseConfig.publishableKey,
      }).timeout(_platformTimeout);
      await syncPending();
    } on MissingPluginException {
      // Desktop and unsupported test platforms do not install native adapters.
    } catch (error) {
      debugPrint('Could not start native tripwire monitoring: $error');
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
        } catch (error) {
          debugPrint('Native tripwire event remains queued: $error');
          break;
        }
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
