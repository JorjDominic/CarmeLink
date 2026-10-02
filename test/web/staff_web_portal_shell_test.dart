import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/views/owner/owner_pages.dart';
import 'package:carmelitas_dormitory_system/web/dashboard/staff_web_portal_shell.dart';
import 'package:carmelitas_dormitory_system/web/dashboard/staff_overview_page.dart';
import 'package:carmelitas_dormitory_system/views/shared/cleaning_schedule_management_page.dart';

void main() {
  test('owner uses grouped live management destinations', () {
    final main = StaffWebDestinations.primary(UserRole.owner);
    final extra = StaffWebDestinations.desktopTools(UserRole.owner);
    expect(main.map((e) => e.label),
        ['Dashboard', 'Residents', 'Operations', 'Profile']);
    expect(main.first.page, isA<StaffOverviewPage>());
    expect(extra, isNotEmpty);
    expect(
        extra.map((e) => e.webGroup).whereType<String>().toSet(),
        containsAll([
          'Facilities',
          'Access & Safety',
          'Billing & Records',
          'Communication',
          'Administration',
        ]));
    final cleaning =
        extra.singleWhere((e) => e.label == 'Cleaning schedules & reports');
    expect(cleaning.page, isA<CleaningScheduleManagementPage>());
    expect(extra.map((e) => e.label), contains('Contracts'));
    expect(extra.map((e) => e.label), contains('Guardian links'));
    expect(extra.map((e) => e.label), contains('Analytics'));
    expect(extra.map((e) => e.label), contains('Rooms & inspections'));
    expect(extra.map((e) => e.label), isNot(contains('Room inspections')));
  });

  test('caretaker sees operational groups without owner-only destinations', () {
    final main = StaffWebDestinations.primary(UserRole.caretaker);
    final extra = StaffWebDestinations.desktopTools(UserRole.caretaker);
    expect(main.map((e) => e.label),
        ['Dashboard', 'Residents', 'Operations', 'Profile']);
    expect(extra, isNotEmpty);
    final labels = extra.map((e) => e.label).toList();
    expect(labels, isNot(contains('Maintenance')));
    final cleaning =
        extra.singleWhere((e) => e.label == 'Cleaning schedules & reports');
    expect(cleaning.page, isA<CleaningScheduleManagementPage>());
    expect(labels, contains('Presence & Curfew'));
    expect(labels, contains('Payment verification'));
    expect(labels, contains('Rooms & inspections'));
    expect(labels, isNot(contains('Room inspections')));
    final reports = extra.singleWhere((e) => e.label == 'Report management');
    expect(reports.page, isA<MaintenanceManagementPage>());
    expect(labels, isNot(contains('Contracts')));
    expect(labels, isNot(contains('Guardian links')));
    expect(labels, isNot(contains('Income & expenses')));
    expect(labels, isNot(contains('Analytics')));
  });
}
