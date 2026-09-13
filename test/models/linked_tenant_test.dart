import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/controllers/guardian_controller.dart';

void main() {
  group('LinkedTenant Model', () {
    test('instantiates with all fields correctly', () {
      const tenant = LinkedTenant(
        linkId: 'link-1',
        tenantId: 'tenant-123',
        name: 'Anna Dela Cruz',
        phone: '+63 917 123 4567',
        email: 'anna@carmelita.test',
        relationship: 'Mother',
        isPrimary: true,
        schoolName: 'University of Santo Tomas',
        courseOrProgram: 'BS Architecture',
        yearLevel: 3,
        emergencyContactName: 'Maria Dela Cruz',
        emergencyContactPhone: '+63 917 999 8888',
        residencyStatus: 'active',
      );

      expect(tenant.linkId, 'link-1');
      expect(tenant.tenantId, 'tenant-123');
      expect(tenant.name, 'Anna Dela Cruz');
      expect(tenant.phone, '+63 917 123 4567');
      expect(tenant.relationship, 'Mother');
      expect(tenant.isPrimary, true);
      expect(tenant.schoolName, 'University of Santo Tomas');
      expect(tenant.courseOrProgram, 'BS Architecture');
      expect(tenant.yearLevel, 3);
      expect(
        tenant.educationSummary,
        'BS Architecture • Year 3 • University of Santo Tomas',
      );
    });

    test('educationSummary formats partial information gracefully', () {
      const tenantNoEducation = LinkedTenant(
        linkId: 'link-2',
        tenantId: 'tenant-456',
        name: 'John Doe',
        phone: '',
        relationship: 'Guardian',
      );
      expect(tenantNoEducation.educationSummary, 'Not specified');

      const tenantCourseOnly = LinkedTenant(
        linkId: 'link-3',
        tenantId: 'tenant-789',
        name: 'Jane Doe',
        phone: '',
        relationship: 'Father',
        courseOrProgram: 'BS Computer Science',
      );
      expect(tenantCourseOnly.educationSummary, 'BS Computer Science');
    });
  });

  group('GuardianController', () {
    final controller = GuardianController.instance;

    setUp(() {
      controller.clear();
    });

    test('initial state when unlinked/cleared', () {
      expect(controller.linkedTenants, isEmpty);
      expect(controller.selectedTenant, isNull);
      expect(controller.hasLinkedTenant, false);
      expect(controller.room, isNull);
      expect(controller.payments, isEmpty);
      expect(controller.outstandingTotal, 0.0);
    });

    test('clear resets all state properly', () {
      controller.clear();
      expect(controller.loading, false);
      expect(controller.loadedOnce, false);
      expect(controller.selectedTenant, isNull);
      expect(controller.room, isNull);
      expect(controller.payments, isEmpty);
    });
  });
}

