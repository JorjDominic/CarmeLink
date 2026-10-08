import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carmelitas_dormitory_system/services/app_notification_service.dart';

class _Creation extends AppNotificationService {
  _Creation()
      : super.withClient(SupabaseClient('http://localhost', 'fixture',
            authOptions: const AuthClientOptions(autoRefreshToken: false)));
  final payloads = <Map<String, dynamic>>[];
  @override
  Future<bool> sendNotification(
      {required String title,
      required String body,
      required String notificationType,
      String? recipientId,
      List<String>? recipientIds,
      String? recipientRole,
      String? tenantId,
      bool notifyGuardians = false,
      bool notifyTenant = false,
      String? routeType,
      String? routeId,
      Map<String, dynamic>? data}) async {
    payloads.add({
      'type': notificationType,
      'recipient': recipientId,
      'role': recipientRole,
      'tenant': tenantId,
      'guardians': notifyGuardians,
      'route': routeType,
      'id': routeId
    });
    return true;
  }
}

void main() {
  test('client notification creation preserves routes and recipient policies',
      () async {
    final service = _Creation();
    await service.notifyNewAnnouncement(
        title: 'Notice',
        body: 'Update',
        audience: 'staff',
        announcementId: 'announcement');
    await service.notifyMaintenanceSubmitted(
        reportId: 'maintenance',
        location: 'Room',
        category: 'Repair',
        description: 'Details');
    await service.notifyMaintenanceStatusChanged(
        tenantId: 'tenant',
        reportId: 'maintenance',
        category: 'Repair',
        status: 'Resolved');
    await service.notifyPaymentSubmitted(
        paymentId: 'payment',
        tenantName: 'Resident',
        amount: 100,
        referenceNumber: 'ref');
    await service.notifyPaymentReviewed(
        tenantId: 'tenant', paymentId: 'payment', approved: true, amount: 100);
    await service.notifyCurfewPassRequested(
        requestId: 'late',
        tenantId: 'tenant',
        tenantName: 'Resident',
        requestType: 'Late Return',
        curfewDate: '2026-10-09',
        requiresGuardianReview: false);
    await service.notifyCurfewPassRequested(
        requestId: 'overnight',
        tenantId: 'tenant',
        tenantName: 'Resident',
        requestType: 'Overnight Leave',
        curfewDate: '2026-10-09',
        requiresGuardianReview: true);
    await service.notifyCurfewPassStatusChanged(
        tenantId: 'tenant',
        requestId: 'late',
        requestType: 'Late Return',
        status: 'Approved');
    await service.notifyCurfewGuardianDecisionToStaff(
        tenantId: 'tenant',
        requestId: 'overnight',
        requestType: 'Overnight Leave',
        approved: true);
    await service.notifyGateCrossing(
        tenantId: 'tenant',
        tenantName: 'Resident',
        direction: 'IN',
        eventId: 'event');
    await service.notifyVisitorPassRequested(
        passId: 'visitor',
        tenantName: 'Resident',
        visitorName: 'Visitor',
        visitDate: '2026-10-09');
    await service.notifyVisitorPassStatusChanged(
        tenantId: 'tenant',
        passId: 'visitor',
        visitorName: 'Visitor',
        status: 'Approved');
    await service.notifyConductCaseFiled(
        tenantId: 'tenant',
        caseId: 'case',
        title: 'Incident',
        severity: 'Minor');
    await service.notifyConductAppealSubmitted(
        caseId: 'case', tenantName: 'Resident');
    await service.notifyConductAppealResolved(
        tenantId: 'tenant', caseId: 'case', decision: 'Accepted');
    await service.notifyInspectionCompleted(
        tenantId: 'tenant',
        inspectionId: 'inspection',
        roomName: 'Room 1',
        status: 'Completed');

    final payloads = service.payloads;
    expect(payloads.map((p) => p['route']), [
      'announcement',
      'maintenance',
      'maintenance',
      'payment',
      'payment',
      'curfew',
      'curfew',
      'curfew',
      'curfew',
      'gate_event',
      'visitor',
      'visitor',
      'conduct_case',
      'conduct_case',
      'conduct_case',
      'inspection',
    ]);
    for (final i in [0, 1, 3, 5, 6, 8, 10, 13]) {
      expect(payloads[i]['role'], 'staff', reason: 'producer $i');
    }
    for (final i in [2, 4, 7, 11, 12, 14, 15]) {
      expect(payloads[i]['recipient'], 'tenant', reason: 'producer $i');
    }
    expect(payloads[5]['guardians'], isFalse,
        reason: 'late return uses staff review');
    expect(payloads[6]['guardians'], isTrue,
        reason: 'overnight leave includes linked guardian review');
    for (final i in [4, 7, 9, 12, 14]) {
      expect(payloads[i]['guardians'], isTrue, reason: 'producer $i');
    }
    expect(payloads[15]['guardians'], isFalse,
        reason: 'inspection does not disclose report to guardians');
    expect(payloads.every((p) => (p['id'] as String).isNotEmpty), isTrue);
  });

  testWidgets(
      'concurrent inbox/shell read writes share one persistence request',
      (tester) async {
    // No configured Supabase backend in this test: persistence returns false
    // immediately, while the shared in-flight lifecycle is exercised fully.
    final service = AppNotificationService.instance;
    final one = service.tryMarkAsRead('notice');
    final two = service.tryMarkAsRead('notice');
    expect(identical(one, two), isTrue);
    expect(await one, isFalse);
    final retry = service.tryMarkAsRead('notice');
    expect(identical(one, retry), isFalse,
        reason: 'failed writes remain retryable');
    await retry;
  });
}
