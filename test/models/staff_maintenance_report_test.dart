import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/controllers/owner_controller.dart';
import 'package:carmelitas_dormitory_system/services/staff_maintenance_service.dart';

void main() {
  group('StaffMaintenanceReport Model', () {
    final now = DateTime(2026, 9, 14, 10, 0);
    final resolved = DateTime(2026, 9, 14, 16, 0);

    test('const constructor sets all properties correctly', () {
      final report = StaffMaintenanceReport(
        id: 'smr-001',
        tenantName: 'Juan Dela Cruz',
        category: 'Plumbing',
        description: 'Faucet leaking constantly',
        location: 'Room 204',
        urgency: 'high',
        status: 'pending',
        notes: 'Initial check needed',
        updatedAt: '2026-09-14T10:00:00Z',
        createdAt: now,
        photoPath: 'photos/smr-001.jpg',
        resolvedAt: resolved,
      );

      expect(report.id, 'smr-001');
      expect(report.tenantName, 'Juan Dela Cruz');
      expect(report.category, 'Plumbing');
      expect(report.description, 'Faucet leaking constantly');
      expect(report.location, 'Room 204');
      expect(report.urgency, 'high');
      expect(report.status, 'pending');
      expect(report.notes, 'Initial check needed');
      expect(report.updatedAt, '2026-09-14T10:00:00Z');
      expect(report.createdAt, now);
      expect(report.photoPath, 'photos/smr-001.jpg');
      expect(report.resolvedAt, resolved);
    });

    test('fromRow parses database rows accurately and safely', () {
      final row = {
        'id': 'row-123',
        'tenant': {'full_name': 'Maria Santos'},
        'category': 'Electrical',
        'description': 'Outlet sparked when plugging laptop',
        'location': 'Room 102',
        'urgency': 'high',
        'status': 'in_progress',
        'photo_path': 'evidence/spark.png',
        'staff_notes': 'Electrician assigned: Mang Ben',
        'updated_at': '2026-09-14T11:00:00.000Z',
        'created_at': '2026-09-14T09:00:00.000Z',
        'resolved_at': null,
      };

      final parsed = StaffMaintenanceReport.fromRow(row);
      expect(parsed.id, 'row-123');
      expect(parsed.tenantName, 'Maria Santos');
      expect(parsed.category, 'Electrical');
      expect(parsed.description, 'Outlet sparked when plugging laptop');
      expect(parsed.location, 'Room 102');
      expect(parsed.urgency, 'high');
      expect(parsed.status, 'in_progress');
      expect(parsed.photoPath, 'evidence/spark.png');
      expect(parsed.notes, 'Electrician assigned: Mang Ben');
      expect(parsed.resolvedAt, isNull);
      expect(parsed.isInProgress, isTrue);
      expect(parsed.isOpen, isTrue);
    });

    test('fromRow handles null or missing optional fields gracefully', () {
      final minimalRow = {
        'id': 'min-001',
        'category': 'Furniture',
        'description': 'Desk leg loose',
        'location': 'Lounge',
        'urgency': 'low',
        'status': 'pending',
        'photo_path': null,
        'staff_notes': null,
        'updated_at': null,
        'created_at': '2026-09-14T08:00:00.000Z',
        'resolved_at': null,
      };

      final parsed = StaffMaintenanceReport.fromRow(minimalRow);
      expect(parsed.tenantName, 'Tenant unavailable');
      expect(parsed.notes, '');
      expect(parsed.photoPath, isNull);
      expect(parsed.isPending, isTrue);
      expect(parsed.isLowUrgency, isTrue);
    });

    test('status and urgency getters work across all lifecycle states', () {
      final base = StaffMaintenanceReport(
        id: 'test',
        tenantName: 'Test',
        category: 'Test',
        description: 'Test',
        location: 'Test',
        urgency: 'high',
        status: 'pending',
        notes: '',
        updatedAt: '',
        createdAt: now,
      );

      expect(base.isOpen, isTrue);
      expect(base.isPending, isTrue);
      expect(base.isHighUrgency, isTrue);

      final assigned = base.copyWith(status: 'assigned', urgency: 'medium');
      expect(assigned.isOpen, isTrue);
      expect(assigned.isAssigned, isTrue);
      expect(assigned.isMediumUrgency, isTrue);

      final inProgress = base.copyWith(status: 'in_progress', urgency: 'low');
      expect(inProgress.isOpen, isTrue);
      expect(inProgress.isInProgress, isTrue);
      expect(inProgress.isLowUrgency, isTrue);

      final resolved = base.copyWith(status: 'resolved');
      expect(resolved.isOpen, isFalse);
      expect(resolved.isResolved, isTrue);

      final cancelled = base.copyWith(status: 'cancelled');
      expect(cancelled.isOpen, isFalse);
      expect(cancelled.isCancelled, isTrue);
    });

    test('copyWith updates specified fields and preserves untouched fields', () {
      final original = StaffMaintenanceReport(
        id: 'orig-1',
        tenantName: 'Alex',
        category: 'Carpentry',
        description: 'Cabinet door unhinged',
        location: 'Room 301',
        urgency: 'medium',
        status: 'pending',
        notes: 'Needs screws',
        updatedAt: 'v1',
        createdAt: now,
      );

      final modified = original.copyWith(
        status: 'resolved',
        notes: 'Door rehinged and tightened',
        resolvedAt: resolved,
      );

      expect(modified.id, original.id);
      expect(modified.tenantName, original.tenantName);
      expect(modified.category, original.category);
      expect(modified.location, original.location);
      expect(modified.status, 'resolved');
      expect(modified.notes, 'Door rehinged and tightened');
      expect(modified.resolvedAt, resolved);
      expect(modified.isResolved, isTrue);
    });
  });

  group('OwnerController Staff Maintenance State', () {
    final controller = OwnerController.instance;

    setUp(() {
      controller.clear();
    });

    tearDown(() {
      controller.clear();
    });

    test('initial state and clear resets maintenance properties', () {
      expect(controller.staffMaintenanceReports, isEmpty);
      expect(controller.maintenanceLoading, isFalse);
      expect(controller.maintenanceError, isNull);
      expect(controller.maintenanceLoadedOnce, isFalse);
      expect(controller.highPriorityMaintenance, 0);
      expect(controller.inProgressMaintenanceCount, 0);
      expect(controller.resolvedMaintenanceCount, 0);
    });

    test('setStaffMaintenanceForTesting updates counts and reports correctly', () {
      final reports = [
        StaffMaintenanceReport(
          id: 'r1',
          tenantName: 'Tenant A',
          category: 'Plumbing',
          description: 'Sink overflow',
          location: 'Room 201',
          urgency: 'high',
          status: 'pending',
          notes: '',
          updatedAt: '1',
          createdAt: DateTime(2026, 9, 14, 8, 0),
        ),
        StaffMaintenanceReport(
          id: 'r2',
          tenantName: 'Tenant B',
          category: 'Electrical',
          description: 'Dim lights',
          location: 'Room 202',
          urgency: 'medium',
          status: 'in_progress',
          notes: 'Working on wiring',
          updatedAt: '2',
          createdAt: DateTime(2026, 9, 14, 8, 30),
        ),
        StaffMaintenanceReport(
          id: 'r3',
          tenantName: 'Tenant C',
          category: 'AC',
          description: 'Filter cleaned',
          location: 'Room 203',
          urgency: 'low',
          status: 'resolved',
          notes: 'All good',
          updatedAt: '3',
          createdAt: DateTime(2026, 9, 14, 9, 0),
          resolvedAt: DateTime(2026, 9, 14, 11, 0),
        ),
      ];

      controller.setStaffMaintenanceForTesting(reports);

      expect(controller.staffMaintenanceReports.length, 3);
      expect(controller.maintenanceLoadedOnce, isTrue);
      expect(controller.openMaintenance, 2); // r1 (pending) and r2 (in_progress)
      expect(controller.highPriorityMaintenance, 1); // r1 is high & open
      expect(controller.inProgressMaintenanceCount, 1); // r2 is in_progress
      expect(controller.resolvedMaintenanceCount, 1); // r3 is resolved
    });
  });
}

