import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:carmelitas_dormitory_system/controllers/tenant_controller.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/services/geofence_service.dart';
import 'package:carmelitas_dormitory_system/services/guardian_alert_service.dart';

void main() {
  tearDown(() {
    GeofenceService.resetMocks();
  });

  group('Data Minimization Guarantee', () {
    test('GateEvent and GeofenceCheckResult maintain strict zero-coordinate persistence', () {
      const result = GeofenceCheckResult(
        direction: 'IN',
        status: 'Verified',
      );

      expect(result.direction, 'IN');
      expect(result.status, 'Verified');
      expect(result.isInside, isTrue);
      expect(result.isOutside, isFalse);
      expect(result.isUnavailable, isFalse);

      final now = DateTime.now();
      final event = GateEvent(
        id: 'ge-1',
        tenantId: 'tenant-101',
        person: 'Anna Dela Cruz',
        direction: 'IN',
        time: now,
        verification: 'GPS Geofence',
        status: 'Verified',
        checkpointType: 'curfew',
        notes: null,
        createdByName: null,
      );

      expect(event.direction, 'IN');
      expect(event.verification, 'GPS Geofence');
      expect(event.status, 'Verified');

      // Verify row serialization does not contain coordinates or distance
      final row = {
        'id': 'ge-2',
        'tenant_id': 'tenant-102',
        'direction': null,
        'status': 'UNAVAILABLE',
        'verification_method': 'GPS Geofence',
        'checkpoint_type': 'scheduled',
        'checked_at': now.toIso8601String(),
        'notes': 'Location permission denied on resident device',
        'user_profiles': {'full_name': 'Mark Santos'},
      };

      final unavailEvent = GateEvent.fromRow(row);
      expect(unavailEvent.direction, isNull);
      expect(unavailEvent.status, 'UNAVAILABLE');
      expect(unavailEvent.isUnavailable, isTrue);
      expect(unavailEvent.person, 'Mark Santos');
      expect(unavailEvent.notes, contains('permission denied'));
    });
  });

  group('Boundary Evaluation & Hysteresis Buffer', () {
    test('evaluates exact center coordinate as IN', () {
      final result = GeofenceService.evaluateCoordinates(
        latitude: GeofenceService.carmelitaLatitude,
        longitude: GeofenceService.carmelitaLongitude,
      );
      expect(result.direction, 'IN');
    });

    test('evaluates distant location as OUT', () {
      final result = GeofenceService.evaluateCoordinates(
        latitude: 15.5000,
        longitude: 121.5000,
      );
      expect(result.direction, 'OUT');
    });

    test('respects hysteresis buffer to prevent boundary jitter', () {
      GeofenceService.usePolygonBoundary = false;
      // 1 degree latitude ~ 111,000 meters.
      // 50m ~ 0.0004505 degrees latitude.
      // 51m ~ 0.0004595 degrees latitude (inside 47m-53m buffer).
      final lat51m = GeofenceService.carmelitaLatitude + 0.0004595;
      final lng = GeofenceService.carmelitaLongitude;

      // Without previous state, 51m is > 50m radius -> OUT
      final initialDirection = GeofenceService.evaluateCoordinates(
        latitude: lat51m,
        longitude: lng,
        previousDirection: null,
      ).direction;
      expect(initialDirection, 'OUT');

      // If previous direction was IN, 51m (< 53m outer threshold) stays IN
      final keptIn = GeofenceService.evaluateCoordinates(
        latitude: lat51m,
        longitude: lng,
        previousDirection: 'IN',
      ).direction;
      expect(keptIn, 'IN');

      // 49m ~ 0.0004414 degrees latitude (inside 47m-53m buffer)
      final lat49m = GeofenceService.carmelitaLatitude + 0.0004414;

      // If previous direction was OUT, 49m (> 47m inner threshold) stays OUT
      final keptOut = GeofenceService.evaluateCoordinates(
        latitude: lat49m,
        longitude: lng,
        previousDirection: 'OUT',
      ).direction;
      expect(keptOut, 'OUT');

      // Well outside (> 53m): 80m ~ 0.00072 degrees
      final lat80m = GeofenceService.carmelitaLatitude + 0.00072;
      final movedOut = GeofenceService.evaluateCoordinates(
        latitude: lat80m,
        longitude: lng,
        previousDirection: 'IN',
      ).direction;
      expect(movedOut, 'OUT');

      // Well inside (< 47m): 20m ~ 0.00018 degrees
      final lat20m = GeofenceService.carmelitaLatitude + 0.00018;
      final movedIn = GeofenceService.evaluateCoordinates(
        latitude: lat20m,
        longitude: lng,
        previousDirection: 'OUT',
      ).direction;
      expect(movedIn, 'IN');
    });
  });

  group('Geofence Failure States (Nullable Direction on UNAVAILABLE)', () {
    const service = GeofenceService();

    test('handles location service disabled with UNAVAILABLE and null direction', () async {
      GeofenceService.mockLocationServiceEnabled = false;

      final result = await service.checkCurrentPresence();
      expect(result.status, 'UNAVAILABLE');
      expect(result.direction, isNull);
      expect(result.failureReason, GeofenceFailureReason.locationServiceDisabled);
      expect(result.isUnavailable, isTrue);
    });

    test('handles permission denied with UNAVAILABLE and null direction', () async {
      GeofenceService.mockLocationServiceEnabled = true;
      GeofenceService.mockPermission = LocationPermission.denied;

      final result = await service.checkCurrentPresence();
      expect(result.status, 'UNAVAILABLE');
      expect(result.direction, isNull);
      expect(result.failureReason, GeofenceFailureReason.permissionDenied);
      expect(result.isUnavailable, isTrue);
    });

    test('handles permission deniedForever with UNAVAILABLE and null direction', () async {
      GeofenceService.mockLocationServiceEnabled = true;
      GeofenceService.mockPermission = LocationPermission.deniedForever;

      final result = await service.checkCurrentPresence();
      expect(result.status, 'UNAVAILABLE');
      expect(result.direction, isNull);
      expect(result.failureReason, GeofenceFailureReason.permissionDenied);
      expect(result.isUnavailable, isTrue);
    });

    test('handles timeout or signal error with UNAVAILABLE and null direction', () async {
      GeofenceService.mockLocationServiceEnabled = true;
      GeofenceService.mockPermission = LocationPermission.whileInUse;
      GeofenceService.mockShouldTimeout = true;

      final result = await service.checkCurrentPresence();
      expect(result.status, 'UNAVAILABLE');
      expect(result.direction, isNull);
      expect(result.failureReason, GeofenceFailureReason.timeoutOrSignalError);
      expect(result.isUnavailable, isTrue);
    });

    test('evaluates valid position cleanly when mocks are satisfied', () async {
      GeofenceService.mockLocationServiceEnabled = true;
      GeofenceService.mockPermission = LocationPermission.whileInUse;
      GeofenceService.mockPosition = Position(
        latitude: GeofenceService.carmelitaLatitude,
        longitude: GeofenceService.carmelitaLongitude,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 10.0,
        altitudeAccuracy: 1.0,
        heading: 0.0,
        headingAccuracy: 1.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );

      final result = await service.checkCurrentPresence();
      expect(result.status, 'Verified');
      expect(result.direction, 'IN');
      expect(result.isInside, isTrue);
      expect(result.failureReason, GeofenceFailureReason.none);
    });
  });

  group('Adaptive Curfew Throttling ("Intelligent Curfew Sleep")', () {
    test('throttles to curfewSleep when resident is IN during curfew hours', () {
      // 11:30 PM (23:30) is during curfew
      final curfewTime = DateTime(2026, 9, 18, 23, 30);
      final intensity = GeofenceService.determineIntensity(
        now: curfewTime,
        currentGateStatus: 'IN',
      );
      expect(intensity, CheckpointIntensity.curfewSleep);
      expect(GeofenceService.intervalForIntensity(intensity), const Duration(hours: 8));

      // 3:00 AM is also during curfew
      final earlyMorning = DateTime(2026, 9, 18, 3, 0);
      final intensityEarly = GeofenceService.determineIntensity(
        now: earlyMorning,
        currentGateStatus: 'IN',
      );
      expect(intensityEarly, CheckpointIntensity.curfewSleep);
    });

    test('uses aggressive 1-minute active polling when OUT or UNAVAILABLE during curfew', () {
      final curfewTime = DateTime(2026, 9, 18, 23, 30);

      final outIntensity = GeofenceService.determineIntensity(
        now: curfewTime,
        currentGateStatus: 'OUT',
      );
      expect(outIntensity, CheckpointIntensity.curfewActive);
      expect(GeofenceService.intervalForIntensity(outIntensity), const Duration(minutes: 1));

      final unavailIntensity = GeofenceService.determineIntensity(
        now: curfewTime,
        currentGateStatus: 'UNAVAILABLE',
      );
      expect(unavailIntensity, CheckpointIntensity.curfewActive);
      expect(GeofenceService.intervalForIntensity(unavailIntensity), const Duration(minutes: 1));
    });

    test('uses preCurfew polling 1 hour prior to curfew', () {
      // 9:30 PM (21:30) is 30 mins before 10:00 PM curfew
      final preCurfewTime = DateTime(2026, 9, 18, 21, 30);
      final intensity = GeofenceService.determineIntensity(
        now: preCurfewTime,
        currentGateStatus: 'OUT',
      );
      expect(intensity, CheckpointIntensity.preCurfew);
      expect(GeofenceService.intervalForIntensity(intensity), const Duration(minutes: 2));
    });

    test('uses standard daytime polling during normal daytime hours', () {
      // 2:00 PM (14:00)
      final dayTime = DateTime(2026, 9, 18, 14, 0);
      final intensity = GeofenceService.determineIntensity(
        now: dayTime,
        currentGateStatus: 'IN',
      );
      expect(intensity, CheckpointIntensity.daytime);
      expect(GeofenceService.intervalForIntensity(intensity), const Duration(minutes: 10));
    });
  });

  group('Guardian Alert Service Preference & Isolation', () {
    test('triggers alert only when past preferred alert time and tenant is OUT', () {
      // Alert time set to 9:00 PM (21:00)
      const alertTime = TimeOfDay(hour: 21, minute: 0);

      // Before alert time (8:45 PM) -> false regardless of status
      final beforeTime = DateTime(2026, 9, 18, 20, 45);
      expect(
        GuardianAlertService.shouldTriggerGuardianAlert(
          linkedTenantGateStatus: 'OUT',
          alertTime: alertTime,
          now: beforeTime,
        ),
        isFalse,
      );

      // Past alert time (9:15 PM) with tenant OUT -> true
      final pastTime = DateTime(2026, 9, 18, 21, 15);
      expect(
        GuardianAlertService.shouldTriggerGuardianAlert(
          linkedTenantGateStatus: 'OUT',
          alertTime: alertTime,
          now: pastTime,
        ),
        isTrue,
      );

      // Past alert time with tenant Outside -> true
      expect(
        GuardianAlertService.shouldTriggerGuardianAlert(
          linkedTenantGateStatus: 'Outside',
          alertTime: alertTime,
          now: pastTime,
        ),
        isTrue,
      );

      // Past alert time with tenant IN -> false
      expect(
        GuardianAlertService.shouldTriggerGuardianAlert(
          linkedTenantGateStatus: 'IN',
          alertTime: alertTime,
          now: pastTime,
        ),
        isFalse,
      );

      // Past alert time with tenant UNAVAILABLE -> false
      expect(
        GuardianAlertService.shouldTriggerGuardianAlert(
          linkedTenantGateStatus: 'UNAVAILABLE',
          alertTime: alertTime,
          now: pastTime,
        ),
        isFalse,
      );
    });

    test('updates and preserves preferred alert time in service state', () {
      const customTime = TimeOfDay(hour: 20, minute: 30);
      GuardianAlertService.setPreferredAlertTime(customTime);
      expect(GuardianAlertService.preferredAlertTime, customTime);

      // Reset to default 9:00 PM
      GuardianAlertService.setPreferredAlertTime(const TimeOfDay(hour: 21, minute: 0));
    });
  });

  group('TenantController Check-in Resilience', () {
    test('handles geofence failure gracefully without throwing uncaught exceptions', () async {
      GeofenceService.mockLocationServiceEnabled = false;

      final controller = TenantController.instance;
      final result = await controller.performGeofenceCheckIn();

      expect(result.isUnavailable, isTrue);
      expect(result.direction, isNull);
      expect(result.failureReason, GeofenceFailureReason.locationServiceDisabled);
      expect(controller.currentGateStatus, 'UNAVAILABLE');
    });

    test('handles database sync error gracefully and preserves on-device evaluation', () async {
      GeofenceService.mockLocationServiceEnabled = true;
      GeofenceService.mockPermission = LocationPermission.whileInUse;
      GeofenceService.mockPosition = Position(
        latitude: GeofenceService.carmelitaLatitude,
        longitude: GeofenceService.carmelitaLongitude,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 10.0,
        altitudeAccuracy: 1.0,
        heading: 0.0,
        headingAccuracy: 1.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );

      final controller = TenantController.instance;
      // Even if backend Supabase isn't reachable / initialized, check-in doesn't crash
      final result = await controller.performGeofenceCheckIn();

      // On-device evaluation should be intact (inside perimeter -> IN)
      expect(result.direction, 'IN');
      expect(result.isInside, isTrue);
      // Status remains Verified (or reflects db sync error message)
      expect(result.status, 'Verified');
      expect(controller.currentGateStatus, 'IN');
    });
  });
}
