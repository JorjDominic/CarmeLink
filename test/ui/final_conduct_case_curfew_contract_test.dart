import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('staff tenant picker supports name, floor, room, and bounded paging',
      () {
    final picker = source('lib/core/widgets/staff_tenant_picker.dart');
    expect(picker, contains("labelText: 'Search tenant'"));
    expect(picker, contains("labelText: 'Floor'"));
    expect(picker, contains("labelText: 'Room'"));
    expect(picker, contains('NumberedPaginationBar('));
    expect(picker, contains('No tenants match the current filters.'));
  });

  test('conduct creation uses smart tenant and meaningful Other fields', () {
    final dialog = source('lib/views/shared/conduct_case_create_dialog.dart');
    expect(dialog, contains('StaffTenantPickerField('));
    expect(dialog, contains("labelText: 'Please specify category'"));
    expect(dialog, contains("labelText: 'Please specify source'"));
    expect(dialog, contains('Link supporting record (optional)'));
    expect(dialog, isNot(contains('Source record ID')));
    expect(dialog, contains('SearchableDropdownFormField<String>('));
    expect(dialog, contains('Select a tenant before creating the case.'));
  });

  test('conduct source linking is scoped to the selected tenant', () {
    final service = source('lib/services/conduct_case_service.dart');
    final migration = source(
      'supabase/migrations/202610070014_conduct_case_smart_creation.sql',
    );
    expect(service, contains('listSourceOptions({'));
    expect(service, contains(".eq('tenant_id', tenantId)"));
    expect(service, contains(".eq('reported_bed_space_id', bedSpaceId)"));
    expect(
      migration,
      contains('Selected source record does not belong to the selected tenant'),
    );
    expect(migration, contains('category_detail'));
    expect(migration, contains('source_detail'));
  });

  test('curfew notification target never relies on an empty filtered list', () {
    final page = source('lib/views/shared/staff_curfew_requests_page.dart');
    final service = source('lib/services/curfew_service.dart');
    final destination =
        source('lib/views/shared/notification_destination.dart');
    expect(page, contains("NotificationTarget.recordIdOf(context, 'curfew')"));
    expect(page, contains('_loadTarget('));
    expect(page, contains('Curfew request unavailable'));
    expect(page, contains('View all curfew requests'));
    expect(service, contains('getStaffRequestById'));
    expect(
      destination,
      contains("'curfew' => StaffCurfewRequestsPage(initialRequestId: id)"),
    );
  });

  test('tenant work curfew reuses the same smart tenant picker', () {
    final page = source(
      'lib/views/shared/employee_curfew_profile_pages.dart',
    );
    expect(page, contains('StaffTenantPickerField('));
    expect(page, contains("title: 'Tenant work curfew'"));
    expect(page,
        contains('Select a tenant before saving the work curfew profile.'));
    expect(
      page,
      contains("labelText: 'Tenant with approved work schedule'"),
    );
  });
}
