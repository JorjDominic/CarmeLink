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
    test('Android accepts a verified polygon side change without gate proof',
        () {
      final source = androidVerifier.readAsStringSync();

      expect(source.contains('if (direction == previousDirection)'), isTrue);
      expect(source.contains('return direction'), isTrue);
      expect(source.contains('return if (crossedGate) direction else null'),
          isFalse);
      expect(source.contains('segmentDistanceMeters('), isFalse);
    });

    test('iOS accepts a verified polygon side change without gate proof', () {
      final source = iosDelegate.readAsStringSync();

      expect(
        source.contains('guard previousDirection != direction else {'),
        isTrue,
      );
      expect(source.contains('append(direction: direction)'), isTrue);
      expect(source.contains('guard movementCrossesGate('), isFalse);
      expect(source.contains('private func movementCrossesGate('), isFalse);
    });

    test('both platforms retain accuracy freshness and edge protections', () {
      final android = androidVerifier.readAsStringSync();
      final ios = iosDelegate.readAsStringSync();

      expect(
          android.contains('location.accuracy > MAX_ACCURACY_METERS'), isTrue);
      expect(android.contains('MAX_AGE_MILLIS'), isTrue);
      expect(android.contains('edgeDistance <= edgeBuffer'), isTrue);
      expect(ios.contains('location.horizontalAccuracy <= 35'), isTrue);
      expect(
          ios.contains('abs(location.timestamp.timeIntervalSinceNow) <= 120'),
          isTrue);
      expect(ios.contains('edgeDistance <= defaults.double'), isTrue);
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
      expect(androidManagerSource.contains('TripwireLocationBurstService'),
          isTrue);
      expect(ios.contains('guard candidateCount >= 2 else { return }'), isTrue);
      expect(ios.contains('startLocationBurst()'), isTrue);
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

      expect(source.contains('startContinuousMonitoring()'), isTrue);
      expect(source.contains('manager.startUpdatingLocation()'), isTrue);
      expect(source.contains('manager.distanceFilter = kCLDistanceFilterNone'),
          isTrue);
      expect(source.contains('manager.allowsBackgroundLocationUpdates = true'),
          isTrue);
      expect(plist.contains('<string>location</string>'), isTrue);
    });
  });
}
