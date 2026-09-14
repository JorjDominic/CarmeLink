import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/controllers/tenant_controller.dart';

void main() {
  group('MaintenanceReport Model', () {
    final now = DateTime(2026, 9, 14, 10, 0);
    final resolved = DateTime(2026, 9, 14, 15, 30);

    test('constructor sets all properties including staffNotes and resolvedAt', () {
      final report = MaintenanceReport(
        id: 'mr-001',
        category: 'Plumbing',
        description: 'Leaking pipe under sink',
        location: 'Room 204',
        urgency: 'High',
        status: 'Pending',
        createdAt: now,
        photoPath: 'tenants/mr-001/photo.jpg',
        notes: 'Initial note',
        staffNotes: 'Plumber dispatched',
        resolvedAt: resolved,
      );

      expect(report.id, 'mr-001');
      expect(report.category, 'Plumbing');
      expect(report.description, 'Leaking pipe under sink');
      expect(report.location, 'Room 204');
      expect(report.urgency, 'High');
      expect(report.status, 'Pending');
      expect(report.createdAt, now);
      expect(report.photoPath, 'tenants/mr-001/photo.jpg');
      expect(report.notes, 'Initial note');
      expect(report.staffNotes, 'Plumber dispatched');
      expect(report.resolvedAt, resolved);
    });

    test('status getters and canEdit/canCancel permissions', () {
      final pending = MaintenanceReport(
        id: 'mr-p',
        category: 'Electrical',
        description: 'Flickering fluorescent bulb',
        location: 'Room 101',
        urgency: 'Medium',
        status: 'Pending',
        createdAt: now,
      );

      expect(pending.isPending, isTrue);
      expect(pending.isAssigned, isFalse);
      expect(pending.isInProgress, isFalse);
      expect(pending.isResolved, isFalse);
      expect(pending.isCancelled, isFalse);
      expect(pending.canEdit, isTrue);
      expect(pending.canCancel, isTrue);

      final assigned = pending.copyWith(status: 'Assigned');
      expect(assigned.isPending, isFalse);
      expect(assigned.isAssigned, isTrue);
      expect(assigned.isInProgress, isFalse);
      expect(assigned.canEdit, isFalse);
      expect(assigned.canCancel, isFalse);

      final inProgress = pending.copyWith(status: 'In Progress');
      expect(inProgress.isPending, isFalse);
      expect(inProgress.isInProgress, isTrue);
      expect(inProgress.canEdit, isFalse);
      expect(inProgress.canCancel, isFalse);

      final resolvedReport = pending.copyWith(
        status: 'Resolved',
        resolvedAt: resolved,
        staffNotes: 'Replaced ballast and bulb',
      );
      expect(resolvedReport.isPending, isFalse);
      expect(resolvedReport.isResolved, isTrue);
      expect(resolvedReport.canEdit, isFalse);
      expect(resolvedReport.canCancel, isFalse);
      expect(resolvedReport.staffNotes, 'Replaced ballast and bulb');
      expect(resolvedReport.resolvedAt, resolved);

      final cancelledReport = pending.copyWith(status: 'Cancelled');
      expect(cancelledReport.isPending, isFalse);
      expect(cancelledReport.isCancelled, isTrue);
      expect(cancelledReport.canEdit, isFalse);
      expect(cancelledReport.canCancel, isFalse);
    });

    test('copyWith updates specified fields and preserves untouched fields', () {
      final original = MaintenanceReport(
        id: 'mr-copy',
        category: 'Furniture',
        description: 'Broken chair armrest',
        location: 'Study lounge',
        urgency: 'Low',
        status: 'Pending',
        createdAt: now,
        photoPath: 'path/to/armrest.png',
      );

      final modified = original.copyWith(
        urgency: 'Medium',
        staffNotes: 'Ordering spare parts',
      );

      expect(modified.id, original.id);
      expect(modified.category, original.category);
      expect(modified.description, original.description);
      expect(modified.location, original.location);
      expect(modified.urgency, 'Medium');
      expect(modified.status, original.status);
      expect(modified.photoPath, original.photoPath);
      expect(modified.staffNotes, 'Ordering spare parts');
    });

    test('equality and hashCode are based on id', () {
      final rep1 = MaintenanceReport(
        id: 'mr-same',
        category: 'Plumbing',
        description: 'Desc 1',
        location: 'Room A',
        urgency: 'Low',
        status: 'Pending',
        createdAt: now,
      );

      final rep2 = MaintenanceReport(
        id: 'mr-same',
        category: 'Electrical',
        description: 'Desc 2',
        location: 'Room B',
        urgency: 'High',
        status: 'Resolved',
        createdAt: now,
      );

      expect(rep1, equals(rep2));
      expect(rep1.hashCode, equals(rep2.hashCode));
    });
  });

  group('TenantController Maintenance State', () {
    final controller = TenantController.instance;

    setUp(() {
      controller.clear();
    });

    test('initial state and clear resets maintenance properties', () {
      expect(controller.maintenance, isEmpty);
      expect(controller.maintenanceLoading, isFalse);
      expect(controller.maintenanceError, isNull);
      expect(controller.maintenanceLoadedOnce, isFalse);
    });
  });
}

