import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

export 'package:geolocator/geolocator.dart' show LocationPermission;

/// Immutable geographic coordinate representing a point on the earth's surface.
class LatLngPoint {
  const LatLngPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  double get lat => latitude;
  double get lng => longitude;

  Map<String, double> toJson() => {
        'lat': latitude,
        'lng': longitude,
      };

  factory LatLngPoint.fromJson(Map<String, dynamic> json) => LatLngPoint(
        (json['lat'] as num).toDouble(),
        (json['lng'] as num).toDouble(),
      );

  @override
  String toString() => 'LatLngPoint($latitude, $longitude)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LatLngPoint &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

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

  /// Production 4-point polygon boundary captured from on-site measurements
  /// at Carmelita Dormitory (Brgy. Concepcion, Baliwag, Bulacan).
  static const List<LatLngPoint> productionDormitoryPolygon = [
    LatLngPoint(14.949435124962447, 120.88489213696135), // Point 1 (East / NE)
    LatLngPoint(14.949251893796628, 120.88482211758398), // Point 2 (South / SE)
    LatLngPoint(14.949350151678374, 120.88452020740704), // Point 3 (West / SW)
    LatLngPoint(14.949547385390431, 120.88454200910613), // Point 4 (North / NW)
  ];

  /// Boundary evaluation mode: true for polygon (default), false for circular fallback.
  static bool usePolygonBoundary = true;
  static double? _remoteCenterLatitude;
  static double? _remoteCenterLongitude;
  static List<LatLngPoint>? _remotePolygon;
  static double? _remoteRadiusMeters;
  static double _remoteEdgeBufferMeters = debounceBufferMeters;

  static double get activeCenterLatitude =>
      _remoteCenterLatitude ?? carmelitaLatitude;

  static double get activeCenterLongitude =>
      _remoteCenterLongitude ?? carmelitaLongitude;

  // In-memory test override fields (strictly volatile, never written to DB or storage)
  static List<LatLngPoint>? _testPolygonOverride;
  static double? _testRadiusOverride;
  static bool _useTestOverride = false;

  static bool get hasActiveTestOverride => _useTestOverride;
  static List<LatLngPoint>? get testPolygonOverride => _testPolygonOverride;
  static double? get testRadiusOverride => _testRadiusOverride;

  static void setTestPolygonOverride(List<LatLngPoint> points) {
    _testPolygonOverride = List.unmodifiable(points);
    _useTestOverride = true;
  }

  static void setTestRadiusOverride(double radiusMeters) {
    _testRadiusOverride = radiusMeters;
    _useTestOverride = true;
  }

  static void resetTestOverride() {
    _testPolygonOverride = null;
    _testRadiusOverride = null;
    _useTestOverride = false;
  }

  static List<LatLngPoint> get activePolygon =>
      (_useTestOverride && _testPolygonOverride != null)
          ? _testPolygonOverride!
          : (_remotePolygon ?? productionDormitoryPolygon);

  static double get activeEdgeBufferMeters => _remoteEdgeBufferMeters;

  /// Applies the active server-owned boundary without retaining tenant location.
  static void applyBoundaryConfiguration(Map<String, dynamic> row) {
    usePolygonBoundary = row['boundary_mode'] != 'circle';
    final centerLat = row['center_latitude'];
    if (centerLat is num) _remoteCenterLatitude = centerLat.toDouble();
    final centerLng = row['center_longitude'];
    if (centerLng is num) _remoteCenterLongitude = centerLng.toDouble();
    final radius = row['radius_meters'];
    if (radius is num && radius > 0) _remoteRadiusMeters = radius.toDouble();
    final buffer = row['edge_buffer_meters'];
    if (buffer is num && buffer >= 0) {
      _remoteEdgeBufferMeters = buffer.toDouble();
    }
    final rawPoints = row['polygon_points'];
    if (rawPoints is List) {
      final points = <LatLngPoint>[];
      for (final value in rawPoints) {
        if (value is Map && value['lat'] is num && value['lng'] is num) {
          points.add(LatLngPoint(
            (value['lat'] as num).toDouble(),
            (value['lng'] as num).toDouble(),
          ));
        }
      }
      if (points.length >= 3) _remotePolygon = List.unmodifiable(points);
    }
  }

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
    usePolygonBoundary = true;
    resetTestOverride();
    _remotePolygon = null;
    _remoteRadiusMeters = null;
    _remoteEdgeBufferMeters = debounceBufferMeters;
  }

  /// Point-in-polygon ray casting algorithm (even-odd rule).
  ///
  /// Casts a horizontal ray along positive longitude from ([lat], [lng]) and counts
  /// intersections with polygon segments. An odd count means the point is inside.
  static bool isPointInPolygon(
    double lat,
    double lng,
    List<LatLngPoint> polygon,
  ) {
    if (polygon.length < 3) return false;
    bool inside = false;
    int j = polygon.length - 1;
    for (int i = 0; i < polygon.length; i++) {
      final pi = polygon[i];
      final pj = polygon[j];
      final yi = pi.latitude;
      final xi = pi.longitude;
      final yj = pj.latitude;
      final xj = pj.longitude;

      if (((yi > lat) != (yj > lat)) &&
          (lng < (xj - xi) * (lat - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }

  /// Calculates the shortest distance in meters from ([lat], [lng]) to the perimeter
  /// of the specified [polygon].
  static double distanceToPolygonEdgeMeters(
    double lat,
    double lng,
    List<LatLngPoint> polygon,
  ) {
    if (polygon.isEmpty) return double.infinity;
    if (polygon.length == 1) {
      return Geolocator.distanceBetween(
        lat,
        lng,
        polygon.first.latitude,
        polygon.first.longitude,
      );
    }

    double minDistance = double.infinity;
    final latRad = lat * math.pi / 180.0;
    final cosLat = math.cos(latRad);

    for (int i = 0; i < polygon.length; i++) {
      final a = polygon[i];
      final b = polygon[(i + 1) % polygon.length];

      // Convert lat/lng to approximate locally scaled coordinates relative to 'a'
      final dx = (b.longitude - a.longitude) * cosLat;
      final dy = b.latitude - a.latitude;
      final px = (lng - a.longitude) * cosLat;
      final py = lat - a.latitude;

      final lenSq = dx * dx + dy * dy;
      final double t =
          lenSq == 0 ? 0.0 : ((px * dx + py * dy) / lenSq).clamp(0.0, 1.0);

      final closestLat = a.latitude + t * (b.latitude - a.latitude);
      final closestLng = a.longitude + t * (b.longitude - a.longitude);

      final dist = Geolocator.distanceBetween(lat, lng, closestLat, closestLng);
      if (dist < minDistance) {
        minDistance = dist;
      }
    }

    return minDistance;
  }

  /// Isolated boundary check supporting both polygon and circular models,
  /// with edge buffer hysteresis to eliminate boundary flapping.
  ///
  /// Clean signature:
  /// `bool isWithinDormBoundary(double lat, double lng)`
  /// Optional parameters allow supplying [previousDirection], a [customPolygon],
  /// or a custom [edgeBufferMeters] (defaults to [debounceBufferMeters] = 3.0m).
  static bool isWithinDormBoundary(
    double lat,
    double lng, {
    String? previousDirection,
    List<LatLngPoint>? customPolygon,
    double? edgeBufferMeters,
  }) {
    final effectiveBuffer = edgeBufferMeters ?? activeEdgeBufferMeters;
    if (usePolygonBoundary) {
      final poly = customPolygon ?? activePolygon;
      final inside = isPointInPolygon(lat, lng, poly);
      final distToEdge = distanceToPolygonEdgeMeters(lat, lng, poly);

      if (effectiveBuffer > 0 && distToEdge <= effectiveBuffer) {
        if (previousDirection == 'IN') {
          return true;
        } else if (previousDirection == 'OUT') {
          return false;
        }
      }
      return inside;
    } else {
      // Legacy circular boundary check with hysteresis
      final radius = (_useTestOverride && _testRadiusOverride != null)
          ? _testRadiusOverride!
          : (_remoteRadiusMeters ?? geofenceRadiusMeters);
      final distance = Geolocator.distanceBetween(
        lat,
        lng,
        activeCenterLatitude,
        activeCenterLongitude,
      );

      if (previousDirection == 'IN') {
        return distance <= (radius + effectiveBuffer);
      } else if (previousDirection == 'OUT') {
        return distance <= (radius - effectiveBuffer);
      } else {
        return distance <= radius;
      }
    }
  }

  /// Evaluates whether a coordinate is within the dormitory boundary.
  ///
  /// Evaluates presence entirely in function scope and discards the raw
  /// coordinates immediately upon return to uphold zero-coordinate persistence.
  static GeofenceCheckResult evaluateCoordinates({
    required double latitude,
    required double longitude,
    String? previousDirection,
  }) {
    final isInside = isWithinDormBoundary(
      latitude,
      longitude,
      previousDirection: previousDirection,
    );

    return GeofenceCheckResult(
      direction: isInside ? 'IN' : 'OUT',
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
      final age = DateTime.now().difference(position.timestamp);
      if (position.isMocked) {
        return const GeofenceCheckResult(
          direction: null,
          status: 'UNAVAILABLE',
          failureReason: GeofenceFailureReason.timeoutOrSignalError,
          errorMessage: 'Mocked device locations cannot verify presence.',
        );
      }
      if (position.accuracy > 35 || age > const Duration(minutes: 2)) {
        return const GeofenceCheckResult(
          direction: null,
          status: 'UNAVAILABLE',
          failureReason: GeofenceFailureReason.timeoutOrSignalError,
          errorMessage: 'Location fix is stale or not accurate enough.',
        );
      }
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
    final isCurfewHours = (hour >= 23 || hour < 6);
    final isPreCurfewHours = (hour >= 21 && hour < 23);

    if (isCurfewHours) {
      final isInside =
          currentGateStatus == 'IN' || currentGateStatus == 'Inside';
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

    if (hour >= 23 || hour < 6) {
      return const Duration(minutes: 5);
    }
    if (hour >= 21 && hour < 23) {
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

  /// Returns true when background ("Always" / "Allow all the time") location
  /// permission is granted. The native Android geofence BroadcastReceiver and
  /// iOS region-monitoring delegate require this permission level to fire while
  /// CarmeLink is suspended or killed.
  static Future<bool> hasBackgroundPermission() async {
    if (kIsWeb) return false;
    try {
      final status = await Permission.locationAlways.status;
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Requests background location ("Allow all the time" on Android,
  /// "Always" on iOS). Must be called after foreground ("While In Use")
  /// permission is already granted — the OS rejects background requests
  /// made before foreground permission exists.
  ///
  /// Returns `true` when the OS grants the permission, `false` otherwise.
  /// If the permission has been permanently denied the caller should direct
  /// the user to [openAppSettings] so they can change it manually.
  static Future<bool> requestBackgroundPermission() async {
    if (kIsWeb) return false;
    try {
      // Ensure foreground permission is already in place.
      var foreground = await Geolocator.checkPermission();
      if (foreground == LocationPermission.denied) {
        foreground = await Geolocator.requestPermission();
      }
      if (foreground == LocationPermission.denied ||
          foreground == LocationPermission.deniedForever) {
        return false;
      }

      final status = await Permission.locationAlways.request();
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }
}

typedef GeofenceService = GeofenceLocationService;
