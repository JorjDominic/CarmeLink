import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 5 cleaning management UI contract', () {
    test('staff web cleaning destination opens automatic rotation management',
        () {
      final source = File(
        'lib/web/dashboard/staff_web_portal_shell.dart',
      ).readAsStringSync();

      expect(
        source.contains("label: 'Cleaning schedules & reports'"),
        isTrue,
      );
      expect(
        source.contains('page: CleaningScheduleManagementPage()'),
        isTrue,
      );
      expect(
        source
            .contains('Automatic rotation, overrides and missed-duty reports'),
        isTrue,
      );
    });

    test(
        'management page documents rotation and keeps manual editing available',
        () {
      final source = File(
        'lib/views/shared/cleaning_schedule_management_page.dart',
      ).readAsStringSync();

      expect(source.contains('Monday-to-Sunday round-robin order'), isTrue);
      expect(source.contains("title: 'Cleaning schedules & reports'"), isTrue);
      expect(source.contains('Vacant beds are removed automatically'), isTrue);
      expect(source.contains('manual override'), isTrue);
      expect(source.contains('regenerateRoom(room.id)'), isTrue);
      expect(source.contains('StaffRoomCleaningPage('), isTrue);
      expect(source.contains("'Review & edit'"), isTrue);
    });

    test(
        'management page stays live through room, assignment and schedule changes',
        () {
      final source = File(
        'lib/views/shared/cleaning_schedule_management_page.dart',
      ).readAsStringSync();

      for (final table in [
        'rooms',
        'bed_spaces',
        'tenant_assignments',
        'cleaning_schedules',
      ]) {
        expect(source.contains("'$table'"), isTrue, reason: table);
      }
      expect(source.contains("'phase5-cleaning-management'"), isTrue);
    });
  });
}
