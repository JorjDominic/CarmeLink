import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/core/widgets/adaptive_shell.dart';

void main() {
  testWidgets('Wide web uses existing role destinations in a sidebar',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(
      home: AdaptiveRoleShell(
        roleLabel: 'Owner',
        messagePage: const Scaffold(body: Text('Messages content')),
        destinations: const [
          AppDestination(
            label: 'Dashboard',
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard,
            page: Center(child: Text('Dashboard content')),
          ),
          AppDestination(
            label: 'Curfew',
            icon: Icons.schedule_outlined,
            selectedIcon: Icons.schedule,
            page: Center(child: Text('Curfew content')),
            isWorkInProgress: true,
          ),
        ],
      ),
    ));

    if (kIsWeb) {
      expect(find.byKey(const Key('web-staff-sidebar')), findsOneWidget);
      expect(find.text('WIP'), findsOneWidget);
      expect(find.text('Dashboard content'), findsOneWidget);
      await tester.tap(find.byKey(const Key('web-staff-destination-1')));
      await tester.pumpAndSettle();
      expect(find.text('Curfew content'), findsOneWidget);
    } else {
      // Non-web runtimes keep the original mobile navigation.
      expect(find.byKey(const Key('web-staff-sidebar')), findsNothing);
      expect(find.text('Dashboard content'), findsOneWidget);
    }
  });

  testWidgets('Narrow web keeps the original mobile-style navigation',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(
      home: AdaptiveRoleShell(
        roleLabel: 'Caretaker',
        messagePage: Scaffold(body: Text('Messages')),
        destinations: [
          AppDestination(
            label: 'Tenants',
            icon: Icons.groups_outlined,
            selectedIcon: Icons.groups,
            page: Center(child: Text('Tenants content')),
          ),
        ],
      ),
    ));

    expect(find.byKey(const Key('web-staff-sidebar')), findsNothing);
    expect(find.text('Tenants content'), findsOneWidget);
  });

  testWidgets('Web-only staff pages stay out of mobile navigation',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(
      home: AdaptiveRoleShell(
        roleLabel: 'Owner',
        messagePage: Scaffold(body: Text('Messages')),
        destinations: [
          AppDestination(
              label: 'Dashboard',
              icon: Icons.dashboard_outlined,
              selectedIcon: Icons.dashboard,
              page: Center(child: Text('Dashboard view'))),
        ],
        webDestinations: [
          AppDestination(
              label: 'Accounts',
              icon: Icons.manage_accounts_outlined,
              selectedIcon: Icons.manage_accounts,
              page: Center(child: Text('Accounts view'))),
        ],
      ),
    ));
    if (kIsWeb) {
      expect(find.text('STAFF TOOLS'), findsOneWidget);
      await tester.tap(find.byKey(const Key('web-staff-destination-1')));
      await tester.pumpAndSettle();
      expect(find.text('Accounts view'), findsOneWidget);
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpAndSettle();
      expect(find.text('Dashboard view'), findsOneWidget);
      expect(find.text('Accounts view'), findsNothing);
      expect(find.byKey(const Key('web-staff-sidebar')), findsNothing);
    } else {
      expect(find.text('Accounts view'), findsNothing);
      expect(find.text('Dashboard view'), findsOneWidget);
    }
  });

}
