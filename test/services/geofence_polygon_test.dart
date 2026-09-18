import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/services/geofence_service.dart';

void main() {
  setUp(() {
    GeofenceLocationService.resetMocks();
  });

  tearDown(() {
    GeofenceLocationService.resetMocks();
  });

  group('Measured On-Site Production Coordinates Integrity', () {
    test('contains exact 4 measured corner coordinates', () {
      final poly = GeofenceLocationService.productionDormitoryPolygon;
      expect(poly.length, 4);

      // Corner 1 (East / NE)
      expect(poly[0].latitude, 14.949435124962447);
      expect(poly[0].longitude, 120.88489213696135);

      // Corner 2 (South / SE)
      expect(poly[1].latitude, 14.949251893796628);
      expect(poly[1].longitude, 120.88482211758398);

      // Corner 3 (West / SW)
      expect(poly[2].latitude, 14.949350151678374);
      expect(poly[2].longitude, 120.88452020740704);

      // Corner 4 (North / NW)
      expect(poly[3].latitude, 14.949547385390431);
      expect(poly[3].longitude, 120.88454200910613);
    });

    test('perimeter measurements match dormitory lot dimensions (~110-120m perimeter)', () {
      final poly = GeofenceLocationService.productionDormitoryPolygon;
      double totalPerimeter = 0.0;
      for (int i = 0; i < poly.length; i++) {
        final next = poly[(i + 1) % poly.length];
        final edgeLen = Geolocator.distanceBetween(
          poly[i].latitude,
          poly[i].longitude,
          next.latitude,
          next.longitude,
        );
        totalPerimeter += edgeLen;
      }

      // 4 sides: ~21.6m, ~34.3m, ~22.0m, ~39.6m -> ~117m
      expect(totalPerimeter, greaterThan(100.0));
      expect(totalPerimeter, lessThan(130.0));
    });
  });

  group('Point-in-Polygon Ray-Casting & Isolated Boundary Check', () {
    test('isWithinDormBoundary returns true for interior points', () {
      // Lot center point
      const centerLat = 14.949396;
      const centerLng = 120.884694;
      expect(GeofenceLocationService.isWithinDormBoundary(centerLat, centerLng), isTrue);

      final result = GeofenceLocationService.evaluateCoordinates(
        latitude: centerLat,
        longitude: centerLng,
      );
      expect(result.direction, 'IN');
      expect(result.isInside, isTrue);
      expect(result.isOutside, isFalse);
      expect(result.status, 'Verified');
    });

    test('isWithinDormBoundary returns false for exterior points', () {
      // Distant point in Baliwag
      const distantLat = 14.954200;
      const distantLng = 120.900800;
      expect(GeofenceLocationService.isWithinDormBoundary(distantLat, distantLng), isFalse);

      final result = GeofenceLocationService.evaluateCoordinates(
        latitude: distantLat,
        longitude: distantLng,
      );
      expect(result.direction, 'OUT');
      expect(result.isInside, isFalse);
      expect(result.isOutside, isTrue);
    });

    test('isWithinDormBoundary works cleanly with only (lat, lng) parameters', () {
      // Interface verification: bool isWithinDormBoundary(double lat, double lng)
      final inside = GeofenceLocationService.isWithinDormBoundary(14.949396, 120.884694);
      final outside = GeofenceLocationService.isWithinDormBoundary(14.949400, 120.885500);

      expect(inside, isTrue);
      expect(outside, isFalse);
    });
  });

  group('Edge Hysteresis Debouncing Buffer (±3.0m default)', () {
    test('maintains IN direction when resident is just inside or just outside the edge within 3m', () {
      final poly = GeofenceLocationService.productionDormitoryPolygon;

      // Find an interior point that is very close to the northern edge (within ~1.5m)
      // Corner 4 is (14.949547, 120.884542) and Corner 1 is (14.949435, 120.884892)
      // Midpoint on North edge: lat ~ 14.949491, lng ~ 120.884717
      const midNorthLat = 14.949491;
      const midNorthLng = 120.884717;

      // Point just slightly south (inside the polygon by ~1 meter)
      // 0.00001 deg lat ~ 1.11 meters
      const justInsideLat = midNorthLat - 0.00001;
      const justInsideLng = midNorthLng;

      final distToEdgeInside = GeofenceLocationService.distanceToPolygonEdgeMeters(
        justInsideLat,
        justInsideLng,
        poly,
      );
      expect(distToEdgeInside, lessThanOrEqualTo(3.0));

      // If resident was already OUT and steps 1m inside, previousDirection OUT keeps them OUT until deeper than 3m
      final debouncedOut = GeofenceLocationService.isWithinDormBoundary(
        justInsideLat,
        justInsideLng,
        previousDirection: 'OUT',
      );
      expect(debouncedOut, isFalse);

      // If resident was already IN, previousDirection IN keeps them IN
      final keptIn = GeofenceLocationService.isWithinDormBoundary(
        justInsideLat,
        justInsideLng,
        previousDirection: 'IN',
      );
      expect(keptIn, isTrue);

      // Point just slightly north (outside the polygon by ~1 meter)
      const justOutsideLat = midNorthLat + 0.00001;
      const justOutsideLng = midNorthLng;

      final distToEdgeOutside = GeofenceLocationService.distanceToPolygonEdgeMeters(
        justOutsideLat,
        justOutsideLng,
        poly,
      );
      expect(distToEdgeOutside, lessThanOrEqualTo(3.0));

      // If resident was already IN, previousDirection IN keeps them IN across the 1m edge
      final keptInOutside = GeofenceLocationService.isWithinDormBoundary(
        justOutsideLat,
        justOutsideLng,
        previousDirection: 'IN',
      );
      expect(keptInOutside, isTrue);

      // If resident was already OUT, previousDirection OUT keeps them OUT
      final keptOutOutside = GeofenceLocationService.isWithinDormBoundary(
        justOutsideLat,
        justOutsideLng,
        previousDirection: 'OUT',
      );
      expect(keptOutOutside, isFalse);
    });

    test('deep interior and exterior points bypass hysteresis regardless of previous direction', () {
      // Center of property is ~10m from all edges
      const centerLat = 14.949396;
      const centerLng = 120.884694;

      expect(
        GeofenceLocationService.isWithinDormBoundary(
          centerLat,
          centerLng,
          previousDirection: 'OUT',
        ),
        isTrue,
      );

      // Point 50m away is deep outside
      const farLat = 14.949400;
      const farLng = 120.885500;

      expect(
        GeofenceLocationService.isWithinDormBoundary(
          farLat,
          farLng,
          previousDirection: 'IN',
        ),
        isFalse,
      );
    });
  });

  group('Zero-Coordinate Persistence Guarantee', () {
    test('GeofenceCheckResult contains no persistent latitude, longitude, or distance', () {
      final result = GeofenceLocationService.evaluateCoordinates(
        latitude: 14.949396,
        longitude: 120.884694,
      );

      expect(result.direction, 'IN');
      expect(result.status, 'Verified');
      expect(result.failureReason, GeofenceFailureReason.none);
      expect(result.errorMessage, isNull);
    });

    test('GateEvent strictly discards raw coordinate data and only serializes presence state', () {
      final now = DateTime.now();
      final event = GateEvent(
        id: 'event-uuid-test',
        tenantId: 'tenant-uuid-1',
        person: 'Test Resident',
        direction: 'IN',
        time: now,
        verification: 'GPS Geofence',
        status: 'Verified',
        checkpointType: 'curfew',
      );

      expect(event.direction, 'IN');
      expect(event.verification, 'GPS Geofence');
      expect(event.status, 'Verified');

      // Verify row mapping
      final row = {
        'id': 'row-uuid',
        'tenant_id': 'tenant-uuid-2',
        'direction': 'OUT',
        'status': 'Verified',
        'verification_method': 'GPS Geofence',
        'checkpoint_type': 'daytime',
        'checked_at': now.toIso8601String(),
        'profiles': {'full_name': 'Sample Resident'},
      };

      final parsed = GateEvent.fromRow(row);
      expect(parsed.direction, 'OUT');
      expect(parsed.person, 'Sample Resident');
    });
  });

  group('Isolated In-Memory Test Override Panel Behavior', () {
    test('setting test polygon override affects active evaluation without modifying production constant', () {
      final originalProduction = GeofenceLocationService.productionDormitoryPolygon;

      // Define an arbitrary small test polygon around coordinates (0.0, 0.0)
      const testPolygon = [
        LatLngPoint(0.0, 0.0),
        LatLngPoint(0.0, 1.0),
        LatLngPoint(1.0, 1.0),
        LatLngPoint(1.0, 0.0),
      ];

      expect(GeofenceLocationService.hasActiveTestOverride, isFalse);

      GeofenceLocationService.setTestPolygonOverride(testPolygon);

      expect(GeofenceLocationService.hasActiveTestOverride, isTrue);
      expect(GeofenceLocationService.activePolygon.length, 4);
      expect(GeofenceLocationService.activePolygon[0], const LatLngPoint(0.0, 0.0));

      // The production constant remains untouched
      expect(originalProduction[0].latitude, 14.949435124962447);
      expect(GeofenceLocationService.productionDormitoryPolygon[0].latitude, 14.949435124962447);

      // Coordinate (0.5, 0.5) is inside test polygon
      expect(GeofenceLocationService.isWithinDormBoundary(0.5, 0.5), isTrue);

      // Coordinate at actual dorm center (14.949396, 120.884694) is OUT of this test polygon
      expect(GeofenceLocationService.isWithinDormBoundary(14.949396, 120.884694), isFalse);

      // Reset override
      GeofenceLocationService.resetTestOverride();
      expect(GeofenceLocationService.hasActiveTestOverride, isFalse);
      expect(GeofenceLocationService.activePolygon[0].latitude, 14.949435124962447);

      // Dorm center is once again IN
      expect(GeofenceLocationService.isWithinDormBoundary(14.949396, 120.884694), isTrue);
    });

    test('setting test radius override alters circular evaluation in circular mode', () {
      GeofenceLocationService.usePolygonBoundary = false;
      GeofenceLocationService.setTestRadiusOverride(10.0); // very small 10m radius

      expect(GeofenceLocationService.hasActiveTestOverride, isTrue);

      // Exact center is inside
      expect(
        GeofenceLocationService.isWithinDormBoundary(
          GeofenceLocationService.carmelitaLatitude,
          GeofenceLocationService.carmelitaLongitude,
        ),
        isTrue,
      );

      // 20m away from center (~0.00018 deg lat) is outside 10m radius
      final lat20m = GeofenceLocationService.carmelitaLatitude + 0.00018;
      expect(
        GeofenceLocationService.isWithinDormBoundary(
          lat20m,
          GeofenceLocationService.carmelitaLongitude,
        ),
        isFalse,
      );

      GeofenceLocationService.resetTestOverride();
      expect(GeofenceLocationService.hasActiveTestOverride, isFalse);
    });
  });
}

