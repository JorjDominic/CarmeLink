import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';

import '../controllers/tenant_controller.dart';
import '../core/config/supabase_config.dart';
import 'geofence_service.dart';

/// Owns the single adaptive geofence timer for the signed-in tenant.
class GeofenceScheduler with WidgetsBindingObserver {
  GeofenceScheduler._();
  static final GeofenceScheduler instance = GeofenceScheduler._();

  Timer? _timer;
  StreamSubscription<Position>? _positionSubscription;
  String? _tenantId;
  bool _running = false;
  DateTime? _lastMovementCheck;

  bool get isRunning => _running;

  Future<void> start(String tenantId) async {
    if (_running && _tenantId == tenantId) return;
    stop();
    _running = true;
    _tenantId = tenantId;
    WidgetsBinding.instance.addObserver(this);
    await _refreshBoundary();
    try {
      await _startBackgroundLocationUpdates();
    } catch (_) {
      // The foreground timer and resume hook remain available.
    }
    _schedule(const Duration(seconds: 2));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    unawaited(_positionSubscription?.cancel());
    _positionSubscription = null;
    _tenantId = null;
    if (_running) WidgetsBinding.instance.removeObserver(this);
    _running = false;
  }

  void _schedule(Duration delay) {
    _timer?.cancel();
    if (!_running) return;
    _timer = Timer(delay, _run);
  }

  Future<void> _run() async {
    if (!_running ||
        SupabaseConfig.clientSafe?.auth.currentUser?.id != _tenantId) {
      stop();
      return;
    }
    final controller = TenantController.instance;
    final intensity = GeofenceLocationService.determineIntensity(
      currentGateStatus: controller.currentGateStatus,
    );
    try {
      await controller.performGeofenceCheckIn(
        checkpointType:
            GeofenceLocationService.checkpointTypeFromIntensity(intensity),
      );
      _schedule(GeofenceLocationService.intervalForIntensity(intensity));
    } catch (_) {
      _schedule(const Duration(minutes: 5));
    }
  }

  Future<void> _refreshBoundary() async {
    try {
      final row = await SupabaseConfig.client
          .from('dorm_boundary_config')
          .select()
          .eq('is_active', true)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row != null) {
        GeofenceLocationService.applyBoundaryConfiguration(row);
      }
    } catch (_) {
      // The compiled production boundary remains the safe offline fallback.
    }
  }

  Future<void> _startBackgroundLocationUpdates() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    // Android background access and iOS Always access are separate grants.
    // A second request upgrades when the OS permits an in-app prompt; otherwise
    // the settings shortcut in the permissions UI remains available.
    if (permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    late final LocationSettings settings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        intervalDuration: const Duration(minutes: 1),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'CarmeLink perimeter monitoring',
          notificationText: 'Location is used for dormitory safety checks.',
          enableWakeLock: true,
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      settings = AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    } else {
      settings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );
    }

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen((_) {
      // Coordinates never leave Geolocator's event and are not persisted here.
      final now = DateTime.now();
      if (_lastMovementCheck != null &&
          now.difference(_lastMovementCheck!) < const Duration(minutes: 1)) {
        return;
      }
      _lastMovementCheck = now;
      _schedule(Duration.zero);
    }, onError: (_) {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_running) return;
    if (state == AppLifecycleState.resumed) {
      _schedule(Duration.zero);
      unawaited(_refreshBoundary());
    }
  }
}
