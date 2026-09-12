import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/core/widgets/adaptive_shell.dart';
import 'package:carmelitas_dormitory_system/views/tenant/tenant_pages.dart';
import 'package:carmelitas_dormitory_system/views/owner/owner_pages.dart';
import 'package:carmelitas_dormitory_system/views/owner/room_monitoring_page.dart';
import 'package:carmelitas_dormitory_system/views/guardian/guardian_pages.dart';
import 'package:carmelitas_dormitory_system/views/shared/shared_views.dart';
import 'package:carmelitas_dormitory_system/views/shared/account_management_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Check semantics tree on all role destinations and pages',
      (tester) async {
    final handle = tester.ensureSemantics();

    // 1. Tenant Shell
    final tenantDestinations = [
      const AppDestination(
        label: 'Home',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        page: TenantDashboardPage(),
      ),
      const AppDestination(
        label: 'Payments',
        icon: Icons.account_balance_wallet_outlined,
        selectedIcon: Icons.account_balance_wallet,
        page: PaymentsPage(),
      ),
      const AppDestination(
        label: 'Curfew',
        icon: Icons.schedule_outlined,
        selectedIcon: Icons.schedule,
        page: TenantPresencePage(),
      ),
      const AppDestination(
        label: 'Profile',
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        page: ProfilePage(),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: AdaptiveRoleShell(
          roleLabel: 'Tenant',
          messagePage: const TenantMessagesPage(),
          destinations: tenantDestinations,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap on Payments tab by icon (last is in the navigation bar)
    await tester.tap(find.byIcon(Icons.account_balance_wallet_outlined).last);
    await tester.pumpAndSettle();

    // Tap on Curfew tab by icon
    await tester.tap(find.byIcon(Icons.schedule_outlined).last);
    await tester.pumpAndSettle();

    // Tap on Profile tab by icon
    await tester.tap(find.byIcon(Icons.person_outline).last);
    await tester.pumpAndSettle();

    // 2. UploadPaymentProofPage directly
    await tester.pumpWidget(
      const MaterialApp(
        home: UploadPaymentProofPage(),
      ),
    );
    await tester.pumpAndSettle();

    // 3. Owner Shell
    final ownerDestinations = [
      const AppDestination(
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        page: OwnerDashboardPage(),
      ),
      const AppDestination(
        label: 'Tenants',
        icon: Icons.groups_outlined,
        selectedIcon: Icons.groups,
        page: TenantDirectoryPage(),
      ),
      const AppDestination(
        label: 'Operations',
        icon: Icons.tune_outlined,
        selectedIcon: Icons.tune,
        page: OperationsHubPage(),
      ),
      const AppDestination(
        label: 'Curfew',
        icon: Icons.schedule_outlined,
        selectedIcon: Icons.schedule,
        page: GeofenceMonitoringPage(),
      ),
      const AppDestination(
        label: 'Profile',
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        page: ProfilePage(),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: AdaptiveRoleShell(
          roleLabel: 'Owner',
          messagePage: const OwnerMessagingPage(),
          destinations: ownerDestinations,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 4. Caretaker Shell
    final caretakerDestinations = [
      const AppDestination(
        label: 'Tenants',
        icon: Icons.groups_outlined,
        selectedIcon: Icons.groups,
        page: TenantDirectoryPage(),
      ),
      const AppDestination(
        label: 'Rooms',
        icon: Icons.bed_outlined,
        selectedIcon: Icons.bed,
        page: RoomMonitoringPage(),
      ),
      const AppDestination(
        label: 'Payments',
        icon: Icons.payments_outlined,
        selectedIcon: Icons.payments,
        page: PaymentVerificationPage(),
      ),
      const AppDestination(
        label: 'Maintenance',
        icon: Icons.build_outlined,
        selectedIcon: Icons.build,
        page: MaintenanceManagementPage(),
      ),
      const AppDestination(
        label: 'Accounts',
        icon: Icons.manage_accounts_outlined,
        selectedIcon: Icons.manage_accounts,
        page: AccountManagementPage(),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: AdaptiveRoleShell(
          roleLabel: 'Caretaker',
          messagePage: const OwnerMessagingPage(),
          destinations: caretakerDestinations,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Directly test PaymentVerificationPage
    await tester.pumpWidget(
      const MaterialApp(
        home: PaymentVerificationPage(),
      ),
    );
    await tester.pumpAndSettle();

    // 5. Guardian Shell
    final guardianDestinations = [
      const AppDestination(
        label: 'Home',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        page: GuardianDashboardPage(),
      ),
      const AppDestination(
        label: 'Curfew',
        icon: Icons.schedule_outlined,
        selectedIcon: Icons.schedule,
        page: GuardianPresenceMonitoringPage(),
      ),
      const AppDestination(
        label: 'Notices',
        icon: Icons.campaign_outlined,
        selectedIcon: Icons.campaign,
        page: GuardianAnnouncementsPage(),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: AdaptiveRoleShell(
          roleLabel: 'Guardian',
          messagePage: const GuardianMessagesPage(),
          destinations: guardianDestinations,
        ),
      ),
    );
    await tester.pumpAndSettle();

    handle.dispose();
  });
}
