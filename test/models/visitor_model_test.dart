import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/controllers/owner_controller.dart';
import 'package:carmelitas_dormitory_system/controllers/tenant_controller.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';

void main() {
  group('VisitorRequest', () {
    test('parses live request fields and tenant join', () {
      final request = VisitorRequest.fromRow({
        'id': 'request-1',
        'tenant_id': 'tenant-1',
        'tenant': {'full_name': 'Anna Dela Cruz'},
        'visitor_name': 'Maria Dela Cruz',
        'relationship': 'Mother',
        'purpose': 'Family visit',
        'schedule': '2026-09-20T06:00:00Z',
        'status': 'approved',
        'review_note': 'Approved for the afternoon.',
        'decided_by': 'staff-1',
        'decided_at': '2026-09-19T03:00:00Z',
        'arrived_at': null,
        'departed_at': null,
        'created_at': '2026-09-19T02:00:00Z',
      });

      expect(request.tenantName, 'Anna Dela Cruz');
      expect(request.visitorName, 'Maria Dela Cruz');
      expect(request.purpose, 'Family visit');
      expect(request.isApproved, isTrue);
      expect(request.statusLabel, 'Approved');
      expect(request.decidedAt, isNotNull);
    });

    test('recognizes every lifecycle state', () {
      VisitorRequest item(String status) => VisitorRequest(
            id: status,
            visitorName: 'Visitor',
            relationship: 'Friend',
            purpose: 'Visit',
            schedule: DateTime(2026, 9, 20),
            status: status,
          );

      expect(item('pending').isPending, isTrue);
      expect(item('rejected').isRejected, isTrue);
      expect(item('cancelled').isCancelled, isTrue);
      expect(item('arrived').hasArrived, isTrue);
      expect(item('completed').isCompleted, isTrue);
    });
  });

  test('VisitorEvent parses actor and audit details', () {
    final event = VisitorEvent.fromRow({
      'id': 'event-1',
      'request_id': 'request-1',
      'event_type': 'arrived',
      'actor_id': 'staff-1',
      'actor': {'full_name': 'Dormitory Staff'},
      'note': 'Identity confirmed.',
      'occurred_at': '2026-09-20T06:03:00Z',
    });

    expect(event.eventLabel, 'Arrived');
    expect(event.actorName, 'Dormitory Staff');
    expect(event.note, 'Identity confirmed.');
  });

  test('controllers expose live visitor state without MockData fallback', () {
    final request = VisitorRequest(
      id: 'request-1',
      visitorName: 'Maria Dela Cruz',
      relationship: 'Mother',
      purpose: 'Family visit',
      schedule: DateTime(2026, 9, 20),
      status: 'pending',
    );

    TenantController.instance.setVisitorsForTesting([request]);
    OwnerController.instance.setVisitorsForTesting([request]);

    expect(TenantController.instance.visitors, [request]);
    expect(OwnerController.instance.visitors, [request]);
    expect(OwnerController.instance.pendingVisitors, 1);

    TenantController.instance.clear();
    OwnerController.instance.clear();
    expect(TenantController.instance.visitors, isEmpty);
    expect(OwnerController.instance.visitors, isEmpty);
  });
}
