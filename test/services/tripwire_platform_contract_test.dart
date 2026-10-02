import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final androidVerifier = File(
    'android/app/src/main/kotlin/com/example/carmelitas_dormitory_system/'
    'TripwireCrossingVerifier.kt',
  );
  final androidManager = File(
    'android/app/src/main/kotlin/com/example/carmelitas_dormitory_system/'
    'TripwireGeofenceManager.kt',
  );
  final androidMonitor = File(
    'android/app/src/main/kotlin/com/example/carmelitas_dormitory_system/'
    'TripwireLocationBurstService.kt',
  );
  final iosDelegate = File('ios/Runner/AppDelegate.swift');
  final dartTripwire = File('lib/services/tripwire_geofence_service.dart');

  group('native tripwire platform contract', () {
    test('Android keeps IN permissive but protects stationary OUT transitions',
        () {
      final source = androidVerifier.readAsStringSync();

      expect(source.contains('if (direction == previousDirection)'), isTrue);
      expect(source.contains('return direction'), isTrue);
      expect(source.contains('return if (crossedGate) direction else null'),
          isFalse);
      expect(source.contains('direction == "OUT"'), isTrue);
      expect(source.contains('candidateCrossesGate'), isTrue);
    });

    test('iOS keeps IN permissive but protects stationary OUT transitions', () {
      final source = iosDelegate.readAsStringSync();

      expect(
        source.contains('guard previousDirection != direction else {'),
        isTrue,
      );
      expect(source.contains('append(direction: direction)'), isTrue);
      expect(source.contains('direction != "OUT"'), isTrue);
      expect(source.contains('candidateCrossesGate'), isTrue);
    });

    test('both platforms retain accuracy freshness and edge protections', () {
      final android = androidVerifier.readAsStringSync();
      final ios = iosDelegate.readAsStringSync();

      expect(
          android.contains('location.accuracy > MAX_ACCURACY_METERS'), isTrue);
      expect(android.contains('MAX_AGE_MILLIS'), isTrue);
      expect(android.contains('MIN_EDGE_BUFFER_METERS'), isTrue);
      expect(ios.contains('location.horizontalAccuracy <= 35'), isTrue);
      expect(
          ios.contains('abs(location.timestamp.timeIntervalSinceNow) <= 120'),
          isTrue);
      expect(
          ios.contains(
              'max(defaults.double(forKey: "tripwire_edge_buffer"), 8)'),
          isTrue);
    });

    test('gate and outer regions remain background wake-up hints', () {
      final android = androidManager.readAsStringSync();
      final ios = iosDelegate.readAsStringSync();

      expect(android.contains('GATE_REGION_ID'), isTrue);
      expect(
          android.contains('wakeUpRadius = radiusMeters.coerceAtLeast(100f)'),
          isTrue);
      expect(android.contains('GEOFENCE_TRANSITION_EXIT'), isTrue);
      expect(ios.contains('gateRegionIdentifier'), isTrue);
      expect(
          ios.contains('manager.startMonitoringSignificantLocationChanges()'),
          isTrue);
      expect(ios.contains('region.notifyOnExit = true'), isTrue);
    });

    test('first fix remains a baseline and does not fabricate a crossing', () {
      final android = androidVerifier.readAsStringSync();
      final ios = iosDelegate.readAsStringSync();

      expect(android.contains('if (previousDirection == null)'), isTrue);
      expect(android.contains('return null'), isTrue);
      expect(ios.contains('if effectiveDirection() == nil'), isTrue);
      expect(
          ios.contains(
              'defaults.set(direction, forKey: confirmedDirectionKey)'),
          isTrue);
    });

    test('recovery compares against server state and requires two fixes', () {
      final androidVerifierSource = androidVerifier.readAsStringSync();
      final androidManagerSource = androidManager.readAsStringSync();
      final ios = iosDelegate.readAsStringSync();
      final dart = dartTripwire.readAsStringSync();

      expect(dart.contains("select('current_gate_status')"), isTrue);
      expect(dart.contains("direction == 'IN' || direction == 'OUT'"), isTrue);
      expect(androidVerifierSource.contains('REQUIRED_MATCHING_FIXES = 2'),
          isTrue);
      expect(androidVerifierSource.contains('MIN_CANDIDATE_FIX_SPACING_MILLIS'),
          isTrue);
      expect(androidManagerSource.contains('TripwireLocationBurstService'),
          isTrue);
      expect(ios.contains('guard candidateCount >= 2 else { return }'), isTrue);
      expect(ios.contains('sufficientlySeparated'), isTrue);
      expect(ios.contains('startLocationBurst()'), isTrue);
    });

    test('Android counts only the newest fix from a batched callback', () {
      final source = androidMonitor.readAsStringSync();

      expect(source.contains('val location = result.lastLocation ?: return'),
          isTrue);
      expect(source.contains('for (location in result.locations)'), isFalse);
    });

    test('Android monitoring persists after the task is removed', () {
      final source = androidMonitor.readAsStringSync();
      final manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

      expect(source.contains('return START_STICKY'), isTrue);
      expect(source.contains('setMinUpdateDistanceMeters(0f)'), isTrue);
      expect(source.contains('stopBurst()'), isFalse);
      expect(manifest.contains('android:stopWithTask="false"'), isTrue);
    });

    test('iOS retains continuous background polygon monitoring', () {
      final source = iosDelegate.readAsStringSync();
      final plist = File('ios/Runner/Info.plist').readAsStringSync();

      expect(source.contains('startContinuousMonitoring(highAccuracy: false)'),
          isTrue);
      expect(source.contains('manager.startUpdatingLocation()'), isTrue);
      expect(
          source.contains(
              'manager.distanceFilter = highAccuracy ? kCLDistanceFilterNone : 15'),
          isTrue);
      expect(source.contains('manager.allowsBackgroundLocationUpdates = true'),
          isTrue);
      expect(plist.contains('<string>location</string>'), isTrue);
    });

    test('both platforms use adaptive lower-power monitoring', () {
      final android = androidMonitor.readAsStringSync();
      final ios = iosDelegate.readAsStringSync();

      expect(android.contains('PRIORITY_BALANCED_POWER_ACCURACY'), isTrue);
      expect(android.contains('hasCandidateTransition()'), isTrue);
      expect(android.contains('HIGH_ACCURACY_EDGE_METERS'), isFalse);
      expect(android.contains('setMinUpdateIntervalMillis(15_000L)'), isTrue);
      expect(ios.contains('kCLLocationAccuracyNearestTenMeters'), isTrue);
      expect(ios.contains('startContinuousMonitoring(highAccuracy: true)'),
          isTrue);
      expect(ios.contains('nearBoundary'), isFalse);
      expect(android.contains('candidate_started_at'), isTrue);
      expect(ios.contains('expireCandidateIfNeeded()'), isTrue);
      expect(ios.contains('pausesLocationUpdatesAutomatically = !highAccuracy'),
          isTrue);
    });
  });
}
