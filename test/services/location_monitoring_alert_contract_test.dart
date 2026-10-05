import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const native =
      'android/app/src/main/kotlin/com/example/carmelitas_dormitory_system/';

  test('health observer cannot request GPS or record presence transitions', () {
    final observer =
        File('${native}LocationMonitoringHealth.kt').readAsStringSync();
    expect(observer, contains('LOCATION_SERVICES_DISABLED'));
    expect(observer, contains('ACTION_LOCATION_SOURCE_SETTINGS'));
    expect(observer, contains('cancelUniqueWork(CHECK_WORK)'));
    expect(observer, isNot(contains('requestLocationUpdates')));
    expect(observer, isNot(contains('getCurrentLocation')));
    expect(observer, isNot(contains('appendEvent')));
    expect(observer, isNot(contains('TripwireCrossingVerifier.accept')));
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('.LocationMonitoringHealthReceiver'));
    expect(manifest, contains('android.location.PROVIDERS_CHANGED'));
    final burst =
        File('${native}TripwireLocationBurstService.kt').readAsStringSync();
    expect(burst, contains('MAX_DURATION_MILLIS = 120_000L'));
    expect(burst, contains('stopBurst()'));
    expect(burst, isNot(contains('LocationMonitoringHealth')));
    expect(burst, isNot(contains('START_STICKY')));
  });

  test('health backend stores no coordinates and escalates unresolved outages',
      () {
    final sql = File(
            'supabase/migrations/202610020001_location_monitoring_incidents.sql')
        .readAsStringSync();
    expect(sql, contains('set_my_location_monitoring_health'));
    expect(sql, contains('recovered_at'));
    expect(sql, isNot(contains('latitude')));
    expect(sql, isNot(contains('longitude')));
    final processor =
        File('supabase/functions/process-location-monitoring-alerts/handler.ts')
            .readAsStringSync();
    expect(processor, contains('30 * 60 * 1000'));
    expect(processor, contains(".is('recovered_at', null)"));
    expect(processor, contains('guardian_tenant_links'));
    final ios = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    expect(ios, contains('carmelink_location_monitoring_off_repeat'));
    expect(ios, isNot(contains('startContinuousMonitoring')));
  });
}
