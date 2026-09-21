import 'dart:async';

import 'package:flutter/widgets.dart';

import 'tripwire_geofence_service.dart';

/// Owns native tripwire registration for the signed-in tenant.
class GeofenceScheduler with WidgetsBindingObserver {
  GeofenceScheduler._();
  static final GeofenceScheduler instance = GeofenceScheduler._();

  String? _tenantId;
  bool _running = false;

  bool get isRunning => _running;

  Future<void> start(String tenantId) async {
    if (_running && _tenantId == tenantId) return;
    if (_running) {
      WidgetsBinding.instance.removeObserver(this);
      _running = false;
      _tenantId = null;
      await TripwireGeofenceService.instance.stop();
    }
    _running = true;
    _tenantId = tenantId;
    WidgetsBinding.instance.addObserver(this);
    await TripwireGeofenceService.instance.start(tenantId);
  }

  void stop() {
    unawaited(TripwireGeofenceService.instance.stop());
    _tenantId = null;
    if (_running) WidgetsBinding.instance.removeObserver(this);
    _running = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_running) return;
    if (state == AppLifecycleState.resumed) {
      final tenantId = _tenantId;
      if (tenantId != null) {
        unawaited(TripwireGeofenceService.instance.start(tenantId));
      }
    }
  }
}
