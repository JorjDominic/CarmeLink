import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/core/widgets/adaptive_shell.dart';
import 'package:carmelitas_dormitory_system/views/owner/owner_pages.dart';

void main() {
  for (final role in ['owner', 'caretaker']) {
    test('$role restores original Operations destination on the mobile surface',
        () {
      final source =
          File('lib/views/$role/${role}_shell.dart').readAsStringSync();
      expect(
          source, contains('if (!CarmeLinkSurfaceScope.isWebPortal(context))'));
      expect(source, isNot(contains('if (!kIsWeb)')));
      final tenants = source.indexOf("label: 'Tenants'");
      final operations = source.indexOf("label: 'Operations'");
      final profile = source.indexOf("label: 'Profile'");
      expect(operations, greaterThan(tenants));
      expect(operations, lessThan(profile));
      expect(source.substring(operations, profile),
          contains('page: OperationsHubPage()'));
      expect(source.substring(operations, profile),
          contains('selectedIcon: Icons.tune'));
    });
    for (final width in [320.0, 360.0, 390.0, 768.0]) {
      testWidgets('$role Operations selects hub and returns at $width',
          (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
            home: AdaptiveRoleShell(
          roleLabel: role,
          messagePage: const SizedBox(),
          destinations: [
            const AppDestination(
                label: 'Dashboard',
                icon: Icons.dashboard_outlined,
                selectedIcon: Icons.dashboard,
                page: Center(child: Text('Dashboard content'))),
            const AppDestination(
                label: 'Tenants',
                icon: Icons.groups_outlined,
                selectedIcon: Icons.groups,
                page: SizedBox()),
            const AppDestination(
                label: 'Operations',
                icon: Icons.tune_outlined,
                selectedIcon: Icons.tune,
                page: OperationsHubPage()),
            if (role == 'owner')
              const AppDestination(
                  label: 'Curfew',
                  icon: Icons.schedule_outlined,
                  selectedIcon: Icons.schedule,
                  page: SizedBox()),
            const AppDestination(
                label: 'Profile',
                icon: Icons.person_outline,
                selectedIcon: Icons.person,
                page: SizedBox()),
          ],
        )));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.tune_outlined));
        await tester.pumpAndSettle();
        expect(find.byType(OperationsHubPage), findsOneWidget);
        expect(find.byIcon(Icons.tune), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byIcon(Icons.dashboard_outlined).last);
        await tester.pumpAndSettle();
        expect(find.text('Dashboard content'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
