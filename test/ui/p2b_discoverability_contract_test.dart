import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UI P2B discoverability contract', () {
    test('tenant dashboard exposes Phase 3 to 4 resident tools', () {
      final source =
          File('lib/views/tenant/tenant_pages.dart').readAsStringSync();

      expect(source.contains("'Resident tools'"), isTrue);
      expect(source.contains("label: 'Cleaning'"), isTrue);
      expect(source.contains('TenantCleaningSchedulePage()'), isTrue);
      expect(source.contains("label: 'Inspections'"), isTrue);
      expect(source.contains('TenantRoomInspectionsPage()'), isTrue);
      expect(source.contains("label: 'Conduct & appeals'"), isTrue);
      expect(source.contains('TenantConductCasesPage()'), isTrue);
      expect(source.contains("label: 'Work curfew'"), isTrue);
    });

    test('guardian quick access prioritizes core linked-tenant tasks', () {
      final source =
          File('lib/views/guardian/guardian_pages.dart').readAsStringSync();

      expect(source.contains("label: 'Tenant info'"), isTrue);
      expect(source.contains("label: 'Payments'"), isTrue);
      expect(source.contains("label: 'Curfew'"), isTrue);
      expect(source.contains("label: 'Messages'"), isTrue);
    });

    test('staff operations surfaces expose current Phase 3 to 5 modules', () {
      final source =
          File('lib/views/owner/owner_pages.dart').readAsStringSync();

      expect(source.contains("'Cleaning schedules'"), isTrue);
      expect(source.contains("'Room inspections'"), isTrue);
      expect(source.contains("'Conduct & cases'"), isTrue);
      expect(source.contains("'Security & retention'"), isTrue);
      expect(source.contains('EmployeeCurfewProfilesPage()'), isTrue);
      expect(source.contains('VisitorManagementPage()'), isTrue);
    });

    test('web staff destinations expose direct staff tools', () {
      final source = File(
        'lib/web/dashboard/staff_web_portal_shell.dart',
      ).readAsStringSync();

      expect(source.contains("label: 'Cleaning'"), isTrue);
      expect(source.contains("label: 'Inspections'"), isTrue);
      expect(source.contains("label: 'Visitors'"), isTrue);
      expect(source.contains("label: 'Conduct & cases'"), isTrue);
      expect(source.contains("label: 'Employee curfew'"), isTrue);
      expect(source.contains("label: 'Security & retention'"), isTrue);
    });
  });
}
