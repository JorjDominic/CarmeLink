import 'package:carmelitas_dormitory_system/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/core/widgets/adaptive_shell.dart';
import 'package:carmelitas_dormitory_system/views/shared/shared_views.dart';
import 'package:carmelitas_dormitory_system/views/tenant/tenant_pages.dart';
import 'package:carmelitas_dormitory_system/views/guardian/guardian_pages.dart';
import 'package:carmelitas_dormitory_system/views/guardian/guardian_documents_page.dart';
import 'package:carmelitas_dormitory_system/views/owner/owner_pages.dart';

// Expressions from the role shells; renders the real bar and screen widgets.
void main() {
  final roles = <String, List<AppDestination>>{
    'owner': [
      AppDestination(
          label: 'Dashboard',
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard,
          page: OwnerDashboardPage()),
      AppDestination(
          label: 'Tenants',
          icon: Icons.groups_outlined,
          selectedIcon: Icons.groups,
          page: TenantDirectoryPage()),
      AppDestination(
          label: 'Operations',
          icon: Icons.tune_outlined,
          selectedIcon: Icons.tune,
          page: OperationsHubPage()),
      AppDestination(
          label: 'Curfew',
          icon: Icons.schedule_outlined,
          selectedIcon: Icons.schedule,
          page: GeofenceMonitoringPage(),
          isWorkInProgress: true),
      AppDestination(
          label: 'Profile',
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
          page: ProfilePage()),
    ],
    'caretaker': [
      AppDestination(
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        page: OwnerDashboardPage(isCaretaker: true),
      ),
      AppDestination(
        label: 'Tenants',
        icon: Icons.groups_outlined,
        selectedIcon: Icons.groups,
        page: TenantDirectoryPage(),
      ),
      AppDestination(
        label: 'Operations',
        icon: Icons.tune_outlined,
        selectedIcon: Icons.tune,
        page: OperationsHubPage(),
      ),
      AppDestination(
        label: 'Profile',
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        page: ProfilePage(),
      ),
    ],
    'tenant': [
      AppDestination(
        label: 'Home',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        page: TenantDashboardPage(),
      ),
      AppDestination(
        label: 'Payments',
        icon: Icons.account_balance_wallet_outlined,
        selectedIcon: Icons.account_balance_wallet,
        page: PaymentsPage(),
      ),
      AppDestination(
        label: 'Reports',
        icon: Icons.assignment_outlined,
        selectedIcon: Icons.assignment,
        page: TenantReportsHubPage(),
      ),
      AppDestination(
        label: 'Curfew',
        icon: Icons.schedule_outlined,
        selectedIcon: Icons.schedule,
        page: TenantPresencePage(),
        isWorkInProgress: true,
      ),
      AppDestination(
        label: 'Profile',
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        page: ProfilePage(),
      ),
    ],
    'guardian': [
      AppDestination(
          label: 'Home',
          icon: Icons.home_outlined,
          selectedIcon: Icons.home,
          page: GuardianDashboardPage()),
      AppDestination(
          label: 'Curfew',
          icon: Icons.schedule_outlined,
          selectedIcon: Icons.schedule,
          page: GuardianPresenceMonitoringPage(),
          isWorkInProgress: true),
      AppDestination(
          label: 'Notices',
          icon: Icons.campaign_outlined,
          selectedIcon: Icons.campaign,
          page: GuardianAnnouncementsPage()),
      AppDestination(
          label: 'Documents',
          icon: Icons.folder_outlined,
          selectedIcon: Icons.folder,
          page: GuardianDocumentsPage()),
      AppDestination(
          label: 'Messages',
          icon: Icons.chat_bubble_outline,
          selectedIcon: Icons.chat_bubble,
          page: GuardianMessagesPage()),
      AppDestination(
          label: 'Profile',
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
          page: ProfilePage()),
    ]
  };
  for (final entry in roles.entries) {
    for (final width in [320.0, 360.0, 390.0, 768.0, 1280.0]) {
      testWidgets(
          entry.key + ' destinations and nested back at ' + width.toString(),
          (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        // Existing destination content triggers this framework paint diagnostic.
        // Keep it separate from navigation/overflow failures; do not hide others.
        final previousErrorHandler = FlutterError.onError;
        FlutterError.onError = (details) {
          if (details.exceptionAsString().startsWith(
              'ListTile background color or ink splashes may be invisible.'))
            return;
          previousErrorHandler?.call(details);
        };
        addTearDown(() => FlutterError.onError = previousErrorHandler);
        await tester.pumpWidget(MaterialApp(
            theme: AppTheme.light(),
            home: AdaptiveRoleShell(
                roleLabel: entry.key,
                messagePage: const SizedBox(),
                destinations: entry.value)));
        await tester.pumpAndSettle();
        final bar = find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_FloatingIslandNavigation');
        expect(bar, findsOneWidget);
        final buttons =
            find.descendant(of: bar, matching: find.byType(InkWell));
        expect(buttons, findsNWidgets(entry.value.length));
        for (var i = 0; i < entry.value.length; i++) {
          await tester.tap(buttons.at(i));
          await tester.pumpAndSettle();
          expect(find.byType(entry.value[i].page.runtimeType), findsOneWidget);
          final icons = tester
              .widgetList<Icon>(
                  find.descendant(of: bar, matching: find.byType(Icon)))
              .toList();
          expect(icons.map((icon) => icon.icon), [
            for (var j = 0; j < entry.value.length; j++)
              j == i ? entry.value[j].selectedIcon : entry.value[j].icon
          ]);
          expect(tester.takeException(), isNull);
          final context =
              tester.element(find.byType(entry.value[i].page.runtimeType));
          Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                  appBar: AppBar(),
                  body: const Text('Navigation back probe'))));
          await tester.pumpAndSettle();
          expect(find.text('Navigation back probe'), findsOneWidget);
          await tester.pageBack();
          await tester.pumpAndSettle();
          expect(find.byType(entry.value[i].page.runtimeType), findsOneWidget);
          expect(
              find.descendant(
                  of: bar, matching: find.byIcon(entry.value[i].selectedIcon)),
              findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}
