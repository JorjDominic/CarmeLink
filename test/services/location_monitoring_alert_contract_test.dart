import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('monitoring incidents store health without raw coordinates', () {
    final sql = File(
      'supabase/migrations/202610020001_location_monitoring_incidents.sql',
    ).readAsStringSync();
    expect(sql, contains('location_monitoring_incidents'));
    expect(sql, contains('set_my_location_monitoring_health'));
    expect(sql, contains('recovered_at'));
    expect(sql, isNot(contains('latitude')));
    expect(sql, isNot(contains('longitude')));
  });

  test('tenant alerts are immediate and delayed escalation is scheduled', () {
    final android = File(
      'android/app/src/main/kotlin/com/example/carmelitas_dormitory_system/'
      'TripwireLocationBurstService.kt',
    ).readAsStringSync();
    final ios = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final flutter =
        File('lib/services/tripwire_geofence_service.dart').readAsStringSync();
    final processor = File(
      'supabase/functions/process-location-monitoring-alerts/index.ts',
    ).readAsStringSync();
    expect(android, contains('Location monitoring is off'));
    expect(android, contains('ACTION_LOCATION_SOURCE_SETTINGS'));
    expect(ios, contains('carmelink_location_monitoring_off_repeat'));
    expect(android, contains('remove("last_location_reminder_at")'));
    expect(ios,
        contains('removeObject(forKey: "tripwire_last_location_reminder_at")'));
    expect(flutter, contains('_updateMonitoringReminder(baseline)'));
    expect(flutter, contains("title: 'Location monitoring is off'"));
    expect(processor, contains('30 * 60 * 1000'));
    expect(processor, contains(".is('recovered_at', null)"));
  });
}
