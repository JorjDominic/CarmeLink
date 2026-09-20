import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/controllers/tenant_controller.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';

void main() {
  final controller = TenantController.instance;

  setUp(() {
    controller.clear();
  });

  tearDown(() {
    controller.clear();
  });

  group('TenantController Unit Tests', () {
    test('clear resets room, maintenance, payment, curfew, and gate states',
        () {
      controller.setCurrentGateStatusForTesting('OUT');
      controller.setGateEventsForTesting([
        GateEvent(
          id: 'ge-1',
          person: 'Tenant',
          direction: 'OUT',
          time: DateTime.now(),
          verification: 'GPS Geofence',
          status: 'Verified',
        ),
      ]);

      expect(controller.gateEvents, isNotEmpty);
      expect(controller.isOutside, isTrue);

      controller.clear();

      expect(controller.room, isNull);
      expect(controller.roomLoading, isFalse);
      expect(controller.roomError, isNull);
      expect(controller.roomLoadedOnce, isFalse);

      expect(controller.maintenance, isEmpty);
      expect(controller.maintenanceLoading, isFalse);
      expect(controller.maintenanceError, isNull);
      expect(controller.maintenanceLoadedOnce, isFalse);

      expect(controller.paymentsLoading, isFalse);
      expect(controller.paymentsError, isNull);
      expect(controller.paymentsLoadedOnce, isFalse);

      expect(controller.curfewRequests, isEmpty);
      expect(controller.curfewLoading, isFalse);
      expect(controller.curfewError, isNull);
      expect(controller.curfewLoadedOnce, isFalse);

      expect(controller.gateEvents, isEmpty);
      expect(controller.gateLoading, isFalse);
      expect(controller.gateError, isNull);
      expect(controller.gateLoadedOnce, isFalse);
      expect(controller.currentGateStatus, 'UNAVAILABLE');
      expect(controller.lastGateEventAt, isNull);
      expect(controller.checkingPresence, isFalse);
      expect(controller.isInside, isFalse);
      expect(controller.isUnavailable, isTrue);
    });

    test('loadGateEvents handles unauthenticated / offline mode gracefully',
        () async {
      await controller.loadGateEvents();
      expect(controller.gateEvents, isEmpty);
      expect(controller.gateLoadedOnce, isTrue);
      expect(controller.gateLoading, isFalse);
      expect(controller.gateError, isNull);
    });

    test('cancelCurfewRequest falls back to local status update when offline',
        () async {
      await controller.cancelCurfewRequest('non-existent');
      expect(controller.curfewRequests, isEmpty);
    });

    test('gate status getters correctly distinguish IN, OUT, and UNAVAILABLE',
        () {
      controller.setCurrentGateStatusForTesting('IN');
      expect(controller.isInside, isTrue);
      expect(controller.isOutside, isFalse);
      expect(controller.isUnavailable, isFalse);

      controller.setCurrentGateStatusForTesting('OUT');
      expect(controller.isInside, isFalse);
      expect(controller.isOutside, isTrue);
      expect(controller.isUnavailable, isFalse);

      controller.setCurrentGateStatusForTesting('UNAVAILABLE');
      expect(controller.isInside, isFalse);
      expect(controller.isOutside, isFalse);
      expect(controller.isUnavailable, isTrue);
    });
  });
}
