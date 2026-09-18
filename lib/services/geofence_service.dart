import 'dart:async';
import 'package:geolocator/geolocator.dart';

export 'package:geolocator/geolocator.dart' show LocationPermission;

enum GeofenceFailureReason {
  none,
  permissionDenied,
  locationServiceDisabled,
  timeoutOrSignalError,
}

enum CheckpointIntensity {
  daytime,
  preCurfew,
  curfewActive,
  curfewSleep,
}

/// The result of an on-device geofence evaluation.
///
/// Strictly adheres to data-minimization rules: raw latitude, longitude,
/// and exact distance are discarded from memory immediately after computation.
/// Only the resulting boolean/enum state reaches callers or network payloads.
class GeofenceCheckResult {
  const GeofenceCheckResult({
    this.direction,
    required this.status,
    this.failureReason = GeofenceFailureReason.none,
    this.errorMessage,
  });

  /// 'IN', 'OUT', or null if [status] is 'UNAVAILABLE'.
  final String? direction;

  /// 'Verified' or 'UNAVAILABLE'.
  final String status;

  final GeofenceFailureReason failureReason;
  final String? errorMessage;

  bool get isInside => direction == 'IN';
  bool get isOutside => direction == 'OUT';
  bool get isUnavailable => status == 'UNAVAILABLE';
}

/// Service handling on-device GPS geofence checks, boundary hysteresis,
/// adaptive curfew scheduling, and failure state classification.
class GeofenceLocationService {
  const GeofenceLocationService();

  // Dormitory perimeter center (Brgy. Concepcion, Baliwag, Bulacan)
  static const double carmelitaLatitude = 14.949402;
  static const double carmelitaLongitude = 120.884676;

  // Boundary thresholds
  static const double geofenceRadiusMeters = 50.0;
  static const double debounceBufferMeters = 3.0;
  static const double innerBoundaryMeters =
      geofenceRadiusMeters - debounceBufferMeters; // 47.0m
  static const double outerBoundaryMeters =
      geofenceRadiusMeters + debounceBufferMeters; // 53.0m

  // Mock hooks for headless unit and widget testing
  static Position? mockPosition;
  static bool? mockLocationServiceEnabled;
  static LocationPermission? mockPermission;
  static bool mockShouldTimeout = false;

  static void resetMocks() {
    mockPosition = null;
    mockLocationServiceEnabled = null;
    mockPermission = null;
    mockShouldTimeout = false;
  }

  /// Evaluates whether a coordinate is within the 50m dormitory boundary
  /// using hysteresis/debounce logic.
  ///
  /// Evaluates distance entirely in function scope and discards the raw
  /// distance immediately upon return to uphold data minimization.
  static GeofenceCheckResult evaluateCoordinates({
    required double latitude,
    required double longitude,
    String? previousDirection,
  }) {
    final distance = Geolocator.distanceBetween(
      latitude,
      longitude,
      carmelitaLatitude,
      carmelitaLongitude,
    );

    String resolvedDirection;
    if (previousDirection == 'IN') {
      resolvedDirection = distance > outerBoundaryMeters ? 'OUT' : 'IN';
    } else if (previousDirection == 'OUT') {
      resolvedDirection = distance <= innerBoundaryMeters ? 'IN' : 'OUT';
    } else {
      resolvedDirection = distance <= geofenceRadiusMeters ? 'IN' : 'OUT';
    }

    return GeofenceCheckResult(
      direction: resolvedDirection,
      status: 'Verified',
    );
  }

  /// Checks the current device position and evaluates geofence presence.
  ///
  /// Catches the 3 failure states and records status: UNAVAILABLE with direction: null.
  Future<GeofenceCheckResult> checkCurrentPresence({
    String? previousDirection,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      // 1. Check Location Services Enabled
      final serviceEnabled = mockLocationServiceEnabled ??
          await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const GeofenceCheckResult(
          direction: null,
          status: 'UNAVAILABLE',
          failureReason: GeofenceFailureReason.locationServiceDisabled,
          errorMessage: 'Location services are disabled on this device.',
        );
      }

      // 2. Check & Request Permissions
      var permission = mockPermission ?? await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = mockPermission ?? await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return const GeofenceCheckResult(
            direction: null,
            status: 'UNAVAILABLE',
            failureReason: GeofenceFailureReason.permissionDenied,
            errorMessage: 'Location permission was denied by the user.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return const GeofenceCheckResult(
          direction: null,
          status: 'UNAVAILABLE',
          failureReason: GeofenceFailureReason.permissionDenied,
          errorMessage:
              'Location permissions are permanently denied. Please enable them in system settings.',
        );
      }

      // 3. Acquire GPS Position
      if (mockShouldTimeout) {
        return const GeofenceCheckResult(
          direction: null,
          status: 'UNAVAILABLE',
          failureReason: GeofenceFailureReason.timeoutOrSignalError,
          errorMessage: 'GPS acquisition timed out. No satellite fix.',
        );
      }

      Position position;
      try {
        if (mockPosition != null) {
          position = mockPosition!;
        } else {
          position = await Geolocator.getCurrentPosition(
            locationSettings: LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: timeout,
            ),
          );
        }
      } catch (e) {
        return GeofenceCheckResult(
          direction: null,
          status: 'UNAVAILABLE',
          failureReason: GeofenceFailureReason.timeoutOrSignalError,
          errorMessage: 'Unable to acquire GPS signal: $e',
        );
      }

      // 4. Pure On-Device Evaluation (Coordinates strictly discarded after this line)
      return evaluateCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
        previousDirection: previousDirection,
      );
    } catch (e) {
      return GeofenceCheckResult(
        direction: null,
        status: 'UNAVAILABLE',
        failureReason: GeofenceFailureReason.timeoutOrSignalError,
        errorMessage: 'Location check failed: $e',
      );
    }
  }

  /// Calculates the variable-frequency checkpoint intensity curve.
  ///
  /// Prevents 8-hour overnight battery drain by putting polling into
  /// [CheckpointIntensity.curfewSleep] once a resident is confirmed IN.
  static CheckpointIntensity determineIntensity({
    DateTime? now,
    String? currentGateStatus,
  }) {
    final time = now ?? DateTime.now();
    final hour = time.hour;
    final isCurfewHours = (hour >= 22 || hour < 6);
    final isPreCurfewHours = (hour >= 20 && hour < 22);

    if (isCurfewHours) {
      final isInside = currentGateStatus == 'IN' || currentGateStatus == 'Inside';
      if (isInside) {
        return CheckpointIntensity.curfewSleep;
      }
      return CheckpointIntensity.curfewActive;
    }

    if (isPreCurfewHours) {
      return CheckpointIntensity.preCurfew;
    }

    return CheckpointIntensity.daytime;
  }

  /// Returns the recommended polling interval based on the current intensity.
  static Duration intervalForIntensity(CheckpointIntensity intensity) {
    switch (intensity) {
      case CheckpointIntensity.daytime:
        return const Duration(minutes: 10);
      case CheckpointIntensity.preCurfew:
        return const Duration(minutes: 2);
      case CheckpointIntensity.curfewActive:
        return const Duration(minutes: 1);
      case CheckpointIntensity.curfewSleep:
        return const Duration(hours: 8); // Dormant sleep mode
    }
  }

  /// Maps the intensity level to the database checkpoint_type string.
  static String checkpointTypeFromIntensity(CheckpointIntensity intensity) {
    switch (intensity) {
      case CheckpointIntensity.daytime:
        return 'daytime';
      case CheckpointIntensity.preCurfew:
        return 'pre_curfew';
      case CheckpointIntensity.curfewActive:
      case CheckpointIntensity.curfewSleep:
        return 'curfew';
    }
  }

  /// Returns reminder interval when location services are turned off,
  /// intensifying as curfew approaches.
  static Duration locationOffReminderInterval({DateTime? now}) {
    final time = now ?? DateTime.now();
    final hour = time.hour;

    if (hour >= 22 || hour < 6) {
      return const Duration(minutes: 5);
    }
    if (hour >= 20 && hour < 22) {
      return const Duration(minutes: 15);
    }
    return const Duration(minutes: 45);
  }

  /// Opens the native device app settings screen so the user can grant permissions.
  static Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }

  /// Opens the native device location settings screen so the user can enable GPS.
  static Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (_) {
      return false;
    }
  }

  /// Checks current OS location permission status.
  static Future<LocationPermission> checkPermission() async {
    try {
      return await Geolocator.checkPermission();
    } catch (_) {
      return LocationPermission.denied;
    }
  }

  /// Explicitly requests location permission from the OS runtime.
  static Future<LocationPermission> requestPermission() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      return perm;
    } catch (_) {
      return LocationPermission.denied;
    }
  }
}

typedef GeofenceService = GeofenceLocationService;
