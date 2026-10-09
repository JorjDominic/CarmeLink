import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dynamic choices are alphabetized with catch-all Other last', () {
    final service = File(
      'lib/services/dormitory_configuration_service.dart',
    ).readAsStringSync();
    final page = File(
      'lib/views/owner/dormitory_configuration_page.dart',
    ).readAsStringSync();

    expect(service, contains('compareOptions'));
    expect(service, contains('a.isCatchAll ? 1 : -1'));
    expect(service, contains('sortLabels'));
    expect(page, isNot(contains("labelText: 'Display order'")));
    expect(page, isNot(contains('Active • order')));
    expect(
        page, contains('Choices are sorted alphabetically. Other stays last.'));
  });

  test('owner management lists use bounded numbered pagination', () {
    final pagination = File(
      'lib/core/widgets/numbered_pagination.dart',
    ).readAsStringSync();
    final configuration = File(
      'lib/views/owner/dormitory_configuration_page.dart',
    ).readAsStringSync();
    final floors = File(
      'lib/views/owner/floor_management_page.dart',
    ).readAsStringSync();
    final rooms = File(
      'lib/views/owner/room_monitoring_page.dart',
    ).readAsStringSync();

    expect(pagination, contains('class NumberedPaginationBar'));
    expect(pagination, contains('...pages.map(pageButton)'));
    expect(configuration, contains('NumberedPaginationBar('));
    expect(floors, contains('NumberedPaginationBar('));
    expect(rooms, contains('NumberedPaginationBar('));
    expect(configuration, contains('static const _pageSize = 6'));
    expect(floors, contains('static const _pageSize = 6'));
  });

  test('room management exposes a labeled floor management button', () {
    final rooms = File(
      'lib/views/owner/room_monitoring_page.dart',
    ).readAsStringSync();

    expect(rooms, contains("label: const Text('Manage floors')"));
    expect(rooms, contains('OutlinedButton.icon('));
    expect(rooms, contains('compactActions && owner'));
  });

  test('maintenance catch-all choices require specific stored text', () {
    final tenant = File(
      'lib/views/tenant/tenant_pages.dart',
    ).readAsStringSync();
    final service = File(
      'lib/services/maintenance_service.dart',
    ).readAsStringSync();
    final model = File('lib/models/models.dart').readAsStringSync();
    final migration = File(
      'supabase/migrations/202610070013_final_choice_standardization.sql',
    ).readAsStringSync();

    expect(tenant, contains("labelText: 'Please specify the issue category'"));
    expect(tenant, contains("labelText: 'Please specify the area / location'"));
    expect(service, contains("'specific_category'"));
    expect(service, contains("'specific_location'"));
    expect(model, contains('String get displayCategory'));
    expect(model, contains('String get displayLocation'));
    expect(migration, contains('specific_category'));
    expect(migration, contains('specific_location'));
    expect(migration, contains('Please specify the maintenance category'));
    expect(migration, contains('Please specify the maintenance location'));
  });

  test('literal Other reason asks for specific rejection details', () {
    final owner = File(
      'lib/views/owner/owner_pages.dart',
    ).readAsStringSync();

    expect(owner, contains('_requiresSpecificReason'));
    expect(owner, contains("labelText: _requiresSpecificReason"));
    expect(owner, contains("'Please specify reason'"));
    expect(owner, contains("'Please specify the rejection reason.'"));
  });

  test('descriptive concern types mapped to other do not behave as catch-all',
      () {
    final tenant = File(
      'lib/views/tenant/tenant_pages.dart',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/202610070013_final_choice_standardization.sql',
    ).readAsStringSync();

    expect(tenant, contains('selectedType?.isCatchAll == true'));
    expect(migration, contains('is_catch_all_dormitory_option'));
    expect(migration, contains('v_report_type_is_other'));
    expect(
      migration,
      isNot(contains("if v_option.category_code = 'other'")),
    );
  });
}
