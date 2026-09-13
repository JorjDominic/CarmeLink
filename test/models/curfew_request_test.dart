import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/controllers/tenant_controller.dart';

void main() {
  group('CurfewRequest Model', () {
    final now = DateTime(2026, 9, 13, 22, 0);
    final departure = DateTime(2026, 9, 14, 18, 0);
    final expectedReturn = DateTime(2026, 9, 15, 6, 0);

    test('fromJson and toJson round-trip with all fields', () {
      final json = {
        'id': 'cr-001',
        'tenant_id': 'tenant-abc',
        'destination': 'Batangas City',
        'reason': 'Family reunion',
        'departure_time': departure.toIso8601String(),
        'expected_return_time': expectedReturn.toIso8601String(),
        'status': 'pending_guardian',
        'guardian_id': null,
        'guardian_notes': null,
        'guardian_decided_at': null,
        'staff_id': null,
        'staff_notes': null,
        'staff_decided_at': null,
        'actual_return_time': null,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final req = CurfewRequest.fromJson(json);

      expect(req.id, 'cr-001');
      expect(req.tenantId, 'tenant-abc');
      expect(req.destination, 'Batangas City');
      expect(req.reason, 'Family reunion');
      expect(req.departureTime, departure);
      expect(req.expectedReturnTime, expectedReturn);
      expect(req.status, 'pending_guardian');
      expect(req.guardianId, isNull);
      expect(req.guardianNotes, isNull);
      expect(req.guardianDecidedAt, isNull);
      expect(req.staffId, isNull);
      expect(req.staffNotes, isNull);
      expect(req.staffDecidedAt, isNull);
      expect(req.actualReturnTime, isNull);
      expect(req.createdAt, now);
      expect(req.updatedAt, now);

      final exported = req.toJson();
      expect(exported['id'], 'cr-001');
      expect(exported['tenant_id'], 'tenant-abc');
      expect(exported['destination'], 'Batangas City');
      expect(exported['reason'], 'Family reunion');
      expect(exported['status'], 'pending_guardian');
    });

    test('status getters and permissions work as expected', () {
      final pendingGuardian = CurfewRequest(
        id: 'cr-1',
        tenantId: 't-1',
        destination: 'Home',
        reason: 'Weekend visit',
        departureTime: departure,
        expectedReturnTime: expectedReturn,
        status: 'pending_guardian',
        createdAt: now,
      );

      expect(pendingGuardian.isPending, isTrue);
      expect(pendingGuardian.isApproved, isFalse);
      expect(pendingGuardian.isRejected, isFalse);
      expect(pendingGuardian.isCancelled, isFalse);
      expect(pendingGuardian.canCancel, isTrue);
      expect(pendingGuardian.canReviewGuardian, isTrue);
      expect(pendingGuardian.canReviewStaff, isFalse);
      expect(pendingGuardian.statusLabel, 'Awaiting Guardian');

      final pendingStaff = pendingGuardian.copyWith(status: 'pending_staff');
      expect(pendingStaff.isPending, isTrue);
      expect(pendingStaff.canCancel, isTrue);
      expect(pendingStaff.canReviewGuardian, isFalse);
      expect(pendingStaff.canReviewStaff, isTrue);
      expect(pendingStaff.statusLabel, 'Awaiting Staff');

      final approved = pendingGuardian.copyWith(status: 'approved');
      expect(approved.isPending, isFalse);
      expect(approved.isApproved, isTrue);
      expect(approved.canCancel, isFalse);
      expect(approved.statusLabel, 'Approved');

      final rejected = pendingGuardian.copyWith(status: 'rejected');
      expect(rejected.isPending, isFalse);
      expect(rejected.isRejected, isTrue);
      expect(rejected.canCancel, isFalse);
      expect(rejected.statusLabel, 'Rejected');

      final cancelled = pendingGuardian.copyWith(status: 'cancelled');
      expect(cancelled.isPending, isFalse);
      expect(cancelled.isCancelled, isTrue);
      expect(cancelled.canCancel, isFalse);
      expect(cancelled.statusLabel, 'Cancelled');
    });

    test('requestType getters and labels work as expected', () {
      final lateReq = CurfewRequest(
        id: 'cr-lr',
        tenantId: 't-1',
        destination: 'Library',
        reason: 'Group study',
        departureTime: departure,
        expectedReturnTime: expectedReturn,
        status: 'pending_staff',
        requestType: 'late_return',
      );

      expect(lateReq.isLateReturn, isTrue);
      expect(lateReq.isOvernightLeave, isFalse);
      expect(lateReq.requestTypeLabel, 'Late Return');

      final overnightReq = lateReq.copyWith(
        requestType: 'overnight_leave',
        status: 'pending_guardian',
      );

      expect(overnightReq.isLateReturn, isFalse);
      expect(overnightReq.isOvernightLeave, isTrue);
      expect(overnightReq.requestTypeLabel, 'Overnight Leave');
    });

    test('copyWith updates specified fields correctly', () {
      final base = CurfewRequest(
        id: 'cr-1',
        tenantId: 't-1',
        destination: 'Library',
        reason: 'Study',
        departureTime: departure,
        expectedReturnTime: expectedReturn,
        status: 'pending_guardian',
        createdAt: now,
      );

      final updated = base.copyWith(
        status: 'pending_staff',
        guardianNotes: 'Permitted by mom',
        guardianDecidedAt: now,
      );

      expect(updated.id, 'cr-1');
      expect(updated.destination, 'Library');
      expect(updated.status, 'pending_staff');
      expect(updated.guardianNotes, 'Permitted by mom');
      expect(updated.guardianDecidedAt, now);
      expect(base.status, 'pending_guardian');
    });
  });

  group('TenantController Curfew State', () {
    final controller = TenantController.instance;

    setUp(() {
      controller.clear();
    });

    test('initial state and clear resets curfew properties', () {
      expect(controller.curfewRequests, isEmpty);
      expect(controller.curfewLoading, isFalse);
      expect(controller.curfewError, isNull);
      expect(controller.curfewLoadedOnce, isFalse);
      expect(controller.activeCurfewRequest, isNull);
    });
  });
}

