import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';

import '../services/gate_service.dart';
import 'geofence_service.dart';
import 'tripwire_geofence_service.dart';

/// Owns native tripwire registration and foreground position monitoring for
/// the signed-in tenant.
///
/// ## Automatic crossing detection
///
/// Two complementary mechanisms ensure crossings are recorded without any
/// manual action:
///
/// 1. **Native background tripwire** ([TripwireGeofenceService]) — Google Play
///    Services / Core Location reports transitions while the app is suspended.
///    Requires "Allow all the time" / "Always" background location permission.
///
/// 2. **Foreground position stream** — while CarmeLink is in the foreground a
///    `Geolocator.getPositionStream` with a 10-metre distance filter monitors
///    movement continuously and records a gate transition whenever the on-device
///    polygon evaluation flips from IN to OUT or vice-versa.  This path works
///    even when the user has only granted "While in use" / "When in use"
///    permission and provides immediate detection without waiting for the
///    native OS trigger.
class GeofenceScheduler with WidgetsBindingObserver {
  GeofenceScheduler._();
  static final GeofenceScheduler instance = GeofenceScheduler._();

  String? _tenantId;
  bool _running = false;

  // Foreground stream state
  StreamSubscription<Position>? _positionSub;
  String? _lastKnownDirection; // 'IN' or 'OUT', null = not established
  bool _processingTransition = false;

  bool get isRunning => _running;

  Future<void> start(String tenantId) async {
    if (_running && _tenantId == tenantId) return;
    if (_running) {
      WidgetsBinding.instance.removeObserver(this);
      _running = false;
      _tenantId = null;
      await TripwireGeofenceService.instance.stop();
      _stopPositionStream();
    }
    _running = true;
    _tenantId = tenantId;
    WidgetsBinding.instance.addObserver(this);
    await TripwireGeofenceService.instance.start(tenantId);
    _startPositionStream();
  }

  void stop() {
    unawaited(TripwireGeofenceService.instance.stop());
    _stopPositionStream();
    _tenantId = null;
    if (_running) WidgetsBinding.instance.removeObserver(this);
    _running = false;
    _lastKnownDirection = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_running) return;
    final tenantId = _tenantId;
    if (tenantId == null) return;

    if (state == AppLifecycleState.resumed) {
      // Re-register native monitoring and sync any events captured while
      // the app was suspended.
      unawaited(TripwireGeofenceService.instance.start(tenantId));
      // Re-attach the foreground stream now that we are back in the foreground.
      _startPositionStream();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Stop the foreground stream — the native tripwire takes over.
      _stopPositionStream();
    }
  }

  // ─── Foreground position stream ────────────────────────────────────────────

  void _startPositionStream() {
    if (kIsWeb) return;
    if (_positionSub != null) return; // already running

    try {
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          // Only wake up when the device has moved at least 10 metres to
          // avoid hammering the polygon evaluator while the user is still.
          distanceFilter: 10,
        ),
      ).listen(
        _onPosition,
        onError: (Object error) {
          // Permission revoked or GPS disabled mid-session — stop gracefully.
          debugPrint('[GeofenceScheduler] Position stream error: $error');
          _stopPositionStream();
        },
        cancelOnError: false,
      );
    } catch (error) {
      debugPrint('[GeofenceScheduler] Could not start position stream: $error');
    }
  }

  void _stopPositionStream() {
    _positionSub?.cancel();
    _positionSub = null;
  }

  /// Called each time the device moves ≥ 10 metres while in the foreground.
  void _onPosition(Position position) {
    if (!_running || _processingTransition) return;

    // Quality gate — reject stale or inaccurate fixes.
    final age = DateTime.now().difference(position.timestamp);
    if (position.isMocked ||
        position.accuracy > 35 ||
        age > const Duration(minutes: 2)) {
      return;
    }

    final isInside = GeofenceLocationService.isWithinDormBoundary(
      position.latitude,
      position.longitude,
      previousDirection: _lastKnownDirection,
    );
    final newDirection = isInside ? 'IN' : 'OUT';

    if (_lastKnownDirection == null) {
      // Establish baseline without recording a transition.
      _lastKnownDirection = newDirection;
      return;
    }

    if (newDirection == _lastKnownDirection) return; // No crossing detected.

    // Direction changed — record the transition.
    _lastKnownDirection = newDirection;
    _processingTransition = true;
    _recordForegroundTransition(newDirection).then((_) {
      _processingTransition = false;
    }).catchError((Object error) {
      _processingTransition = false;
      debugPrint('[GeofenceScheduler] Foreground transition error: $error');
    });
  }

  Future<void> _recordForegroundTransition(String direction) async {
    final tenantId = _tenantId;
    if (tenantId == null) return;
    try {
      await const GateService().recordNativeTransition(
        direction: direction,
        clientEventId: _uniqueId(),
        observedAt: DateTime.now().toUtc(),
      );
      debugPrint('[GeofenceScheduler] Foreground crossing recorded: $direction');
    } catch (error) {
      debugPrint('[GeofenceScheduler] Could not record crossing: $error');
      rethrow;
    }
  }

  String _uniqueId() {
    // UUID v4-style using Dart's random — no crypto dependency needed.
    final rng = DateTime.now().microsecondsSinceEpoch;
    return 'fg-${rng.toRadixString(16)}';
  }
}
