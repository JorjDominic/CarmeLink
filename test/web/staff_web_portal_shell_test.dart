import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/web/dashboard/staff_web_portal_shell.dart';
import 'package:carmelitas_dormitory_system/web/dashboard/staff_overview_page.dart';

void main() {
  test('owner uses live dashboard and simplified management destinations', () {
    final main = StaffWebDestinations.primary(UserRole.owner);
    final extra = StaffWebDestinations.desktopTools(UserRole.owner);
    expect(main.map((e) => e.label),
        ['Dashboard', 'Residents', 'Operations', 'Profile']);
    expect(main.first.page, isA<StaffOverviewPage>());
    expect(extra, isEmpty);
  });

  test('caretaker cannot access owner-only contract or guardian routes', () {
    final main = StaffWebDestinations.primary(UserRole.caretaker);
    final extra = StaffWebDestinations.desktopTools(UserRole.caretaker);
    expect(main.map((e) => e.label),
        ['Dashboard', 'Residents', 'Operations', 'Profile']);
    expect(extra, isEmpty);
    expect([...main, ...extra].map((e) => e.label),
        isNot(contains('Contracts')));
    expect([...main, ...extra].map((e) => e.label),
        isNot(contains('Guardian links')));
  });
}
