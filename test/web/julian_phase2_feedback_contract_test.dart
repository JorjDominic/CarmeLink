import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Julian Phase 2 feedback contract', () {
    test('top staff header owns messages notifications account and logout', () {
      final chrome = File(
        'lib/web/dashboard/widgets/staff_workspace_chrome.dart',
      ).readAsStringSync();
      final adaptive =
          File('lib/core/widgets/adaptive_shell.dart').readAsStringSync();

      expect(chrome.contains("Key('staff-workspace-messages')"), isTrue);
      expect(chrome.contains("Key('staff-workspace-notifications')"), isTrue);
      expect(chrome.contains("Key('web-header-account')"), isTrue);
      expect(chrome.contains("Key('staff-workspace-logout')"), isTrue);
      expect(chrome.contains("Text('Logout')"), isTrue);
      expect(chrome.contains('Public website'), isFalse);

      final wideBarStart = adaptive.indexOf('class _WebWorkspaceContextBar');
      final sidebarStart = adaptive.indexOf('class _WebStaffSidebar');
      expect(wideBarStart, greaterThanOrEqualTo(0));
      expect(sidebarStart, greaterThan(wideBarStart));
      final wideBar = adaptive.substring(wideBarStart, sidebarStart);
      expect(wideBar.contains("tooltip: 'Messages'"), isFalse);
      expect(wideBar.contains("tooltip: 'Account'"), isFalse);
    });

    test('staff back and logout require confirmation before landing', () {
      final source = File(
        'lib/web/dashboard/staff_workspace_page.dart',
      ).readAsStringSync();

      expect(source.contains('PopScope('), isTrue);
      expect(source.contains('canPop: false'), isTrue);
      expect(source.contains('Return to landing page?'), isTrue);
      expect(source.contains("title: const Text('Logout?')"), isTrue);
      expect(source.contains('await SessionController.instance.signOut()'),
          isTrue);
      expect(source.contains('onBack();'), isTrue);
    });

    test('profile logout also confirms and web logout returns to landing', () {
      final source =
          File('lib/views/shared/shared_views.dart').readAsStringSync();

      expect(source.contains('Future<bool> _confirmLogout'), isTrue);
      expect(source.contains("Key('profile-logout')"), isTrue);
      expect(source.contains('pushNamedAndRemoveUntil('), isTrue);
      expect(source.contains("'/'"), isTrue);
    });

    test('staff sign in and maintenance use active theme colors in dark mode',
        () {
      final access =
          File('lib/web/auth/staff_access_page.dart').readAsStringSync();
      final maintenance = File(
        'lib/views/owner/staff_maintenance_page.dart',
      ).readAsStringSync();

      expect(access.contains('final scheme = theme.colorScheme;'), isTrue);
      expect(access.contains('color: scheme.surface'), isTrue);
      expect(access.contains('color: scheme.onSurface'), isTrue);
      expect(access.contains('WebPalette.surface'), isFalse);
      expect(access.contains('WebPalette.background'), isFalse);

      expect(maintenance.contains('prominentCompactText: true'), isTrue);
      expect(maintenance.contains('color: AppColors.darkBrown'), isFalse);
      expect(maintenance.contains('fillColor: Colors.white'), isFalse);
      expect(maintenance.contains('backgroundColor: Colors.white'), isFalse);
    });

    test('tenant payment page no longer exposes Pay now floating action', () {
      final source =
          File('lib/views/tenant/tenant_pages.dart').readAsStringSync();
      final paymentsStart = source.indexOf('class PaymentsPage');
      final uploadStart = source.indexOf('class UploadPaymentProofPage');
      expect(paymentsStart, greaterThanOrEqualTo(0));
      expect(uploadStart, greaterThan(paymentsStart));

      final payments = source.substring(paymentsStart, uploadStart);
      expect(payments.contains("Text('Pay now')"), isFalse);
      expect(
          payments.contains('UploadPaymentProofPage(targetPayment: payment)'),
          isTrue);
    });

    test('operations retain the approved merged tools and report cleanup', () {
      final owner = File('lib/views/owner/owner_pages.dart').readAsStringSync();
      final shell = File(
        'lib/web/dashboard/staff_web_portal_shell.dart',
      ).readAsStringSync();
      final rooms =
          File('lib/views/owner/room_monitoring_page.dart').readAsStringSync();
      final cleaning = File(
        'lib/views/shared/cleaning_schedule_management_page.dart',
      ).readAsStringSync();

      expect(shell.contains("label: 'Rooms & inspections'"), isTrue);
      expect(shell.contains("label: 'Cleaning schedules & reports'"), isTrue);
      expect(shell.contains("label: 'Maintenance'"), isFalse);
      expect(shell.contains("label: 'Room inspections'"), isFalse);
      expect(
          rooms.contains('compareNaturalLabels(a.number, b.number)'), isTrue);
      expect(cleaning.contains('compareNaturalLabels(a.number, b.number)'),
          isTrue);
      expect(owner.contains("title: 'Cleaning compliance reports'"), isFalse);
      expect(
          owner.contains('return const MaintenanceManagementPage();'), isTrue);
      expect(owner.contains('prominentCompactText: true'), isTrue);
      expect(owner.contains("title: 'Maintenance reports'"), isTrue);
      expect(owner.contains("title: 'Confidential reports'"), isTrue);
      expect(owner.contains("'Announcements, messages, and contact directory'"),
          isFalse);
      expect(owner.contains("_OperationItem('Messages'"), isFalse);
    });

    test('contact directory keeps web call controls out and identifies links',
        () {
      final owner = File('lib/views/owner/owner_pages.dart').readAsStringSync();

      expect(owner.contains("'Tenants / students'"), isTrue);
      expect(owner.contains("'Guardians'"), isTrue);
      expect(owner.contains('Linked resident:'), isTrue);
      expect(owner.contains('_roomBedLabel'), isTrue);
      expect(owner.contains('trailing: webPortal'), isTrue);
    });
  });
}
