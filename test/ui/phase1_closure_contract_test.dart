import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 1 closure contract', () {
    test('shared notification entry opens the live NotificationsPage', () {
      final common =
          File('lib/core/widgets/common_widgets.dart').readAsStringSync();
      final shell =
          File('lib/core/widgets/adaptive_shell.dart').readAsStringSync();

      expect(common.contains('class _GlobalNotificationsPage'), isFalse);
      expect(
        common.contains('AdaptiveRoleShell.openNotifications(context)'),
        isTrue,
      );
      expect(shell.contains('_notificationsPage()'), isTrue);
      expect(shell.contains('onOpenNotification: _openNotificationDestination'),
          isTrue);
    });

    test('device binding UI is hidden while the feature is deferred', () {
      final source =
          File('lib/views/shared/shared_views.dart').readAsStringSync();
      expect(source.contains('class SettingsPage'), isTrue);
      expect(source.contains('DeviceBindingPage'), isFalse);
      expect(source.contains('Device binding'), isFalse);
      expect(source.contains('Trusted-device registration'), isFalse);
      expect(source.contains('Cryptographic Device Trust'), isFalse);
    });

    test(
        'web staff navigation keeps simple primary destinations plus grouped tools',
        () {
      final source = File(
        'lib/web/dashboard/staff_web_portal_shell.dart',
      ).readAsStringSync();

      for (final label in ['Dashboard', 'Residents', 'Profile']) {
        expect(source.contains("label: '$label'"), isTrue);
      }
      expect(source.contains("label: 'Curfew'"), isFalse);
      expect(
        source.contains(
            'static List<AppDestination> desktopTools(UserRole role)'),
        isTrue,
      );
      expect(source.contains("webGroup: 'Facilities'"), isTrue);
      expect(source.contains("webGroup: 'Billing & Records'"), isTrue);
    });

    test(
        'operations hub exposes the six approved groups with consolidated room tools',
        () {
      final source =
          File('lib/views/owner/owner_pages.dart').readAsStringSync();

      for (final group in [
        'Residents',
        'Rooms & Facilities',
        'Billing & Payments',
        'Reports & Cases',
        'Access & Visitors',
        'Communication',
      ]) {
        expect(source.contains("'$group'"), isTrue, reason: 'Missing $group');
      }

      expect(source.contains("_OperationItem('Floor plan'"), isFalse);
      expect(
        source.contains(
          "'Occupancy, floor plan, inspection notices, and findings'",
        ),
        isTrue,
      );
      expect(source.contains("Key('operations-summary-row')"), isTrue);
    });

    test('web staff keeps a persistent nested workspace navigator', () {
      final source =
          File('lib/core/widgets/adaptive_shell.dart').readAsStringSync();

      expect(
        source.contains('GlobalKey<NavigatorState> _webWorkspaceNavigatorKey'),
        isTrue,
      );
      expect(source.contains('_webWorkspace(page, activeIndex)'), isTrue);
      expect(
        source.contains('MediaQuery.sizeOf(context).width >= 1024'),
        isTrue,
      );
      expect(
        source.contains('navigator.popUntil((route) => route.isFirst)'),
        isTrue,
      );
    });

    test('staff web keeps data live and surfaces new in-app updates', () {
      final shell = File(
        'lib/web/dashboard/staff_web_portal_shell.dart',
      ).readAsStringSync();
      final adaptive =
          File('lib/core/widgets/adaptive_shell.dart').readAsStringSync();

      expect(shell.contains("'staff-web-live-sync'"), isTrue);
      expect(shell.contains("'gate_events'"), isTrue);
      expect(shell.contains("'payments'"), isTrue);
      expect(
          shell.contains('notificationPageBuilder: _notificationDestination'),
          isTrue);
      expect(adaptive.contains('streamMyNotifications(limit: 30)'), isTrue);
      expect(adaptive.contains('Duration(seconds: 60)'), isTrue);
      expect(adaptive.contains('_UnreadCountBadge'), isTrue);
      expect(adaptive.contains("label: 'View'"), isTrue);
      expect(
          adaptive.contains('onOpenNotification: _openNotificationDestination'),
          isTrue);
    });

    test(
        'web pages can use the workspace width and the pictured curfew page expands',
        () {
      final common =
          File('lib/core/widgets/common_widgets.dart').readAsStringSync();
      final owner = File('lib/views/owner/owner_pages.dart').readAsStringSync();

      expect(
        common.contains('maxWidth ?? (webPortal ? double.infinity : null)'),
        isTrue,
      );
      expect(owner.contains('maxWidth: kIsWeb ? 1400 : 780'), isTrue);
    });

    test('tenant report workflows share purpose and audience framing', () {
      final tenant =
          File('lib/views/tenant/tenant_pages.dart').readAsStringSync();
      final cleaning = File(
        'lib/views/shared/room_cleaning_pages.dart',
      ).readAsStringSync();

      expect(tenant.contains("title: 'Maintenance issue'"), isTrue);
      expect(tenant.contains("title: 'Confidential concern'"), isTrue);
      expect(cleaning.contains("title: 'Missed cleaning duty'"), isTrue);
      expect(
          cleaning.contains("label: const Text('Report privately')"), isTrue);
    });

    test('payment history uses a ten-record load-more contract', () {
      final source =
          File('lib/views/tenant/tenant_pages.dart').readAsStringSync();

      expect(source.contains("Key('payment-filter-row')"), isTrue);
      expect(source.contains("Key('payment-sort-menu')"), isTrue);
      expect(source.contains('pageSize: 10'), isTrue);
      expect(source.contains("loadMoreLabel: 'Load more'"), isTrue);
      expect(source.contains('showVisibleCount: true'), isTrue);
      expect(source.contains("endLabel: 'End of payment records'"), isTrue);
    });

    test('web metadata uses CarmeLink branding rather than Flutter defaults',
        () {
      final index = File('web/index.html').readAsStringSync();
      final manifest = File('web/manifest.json').readAsStringSync();

      expect(index.contains('favicon.png?v=2'), isTrue);
      expect(index.contains('CarmeLink'), isTrue);
      expect(manifest.contains('A new Flutter project.'), isFalse);
      expect(manifest.contains('CarmeLink dormitory management'), isTrue);
    });

    test('feedback remains an explicit non-persistent preview', () {
      final source =
          File('lib/views/shared/shared_views.dart').readAsStringSync();

      expect(source.contains("title: 'Feedback'"), isTrue);
      expect(source.contains('currently a UI preview'), isTrue);
      expect(source.contains('Feedback is not '), isTrue);
      expect(
        source.contains(
          'transmitted or stored until backend support is added.',
        ),
        isTrue,
      );
      expect(source.contains('Feedback preview validated'), isTrue);
      expect(source.contains('not sent or stored'), isTrue);
    });

    test('readiness script permits the active web branch', () {
      final source = File(
        'tool/phase5b_integration_readiness.ps1',
      ).readAsStringSync();

      expect(source.contains("@('japel', 'main', 'web')"), isTrue);
    });
  });
}
