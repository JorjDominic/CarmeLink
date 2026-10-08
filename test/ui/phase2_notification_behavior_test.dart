import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carmelitas_dormitory_system/core/runtime/app_surface.dart';
import 'package:carmelitas_dormitory_system/core/widgets/adaptive_shell.dart';
import 'package:carmelitas_dormitory_system/core/widgets/common_widgets.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/services/app_notification_service.dart';
import 'package:carmelitas_dormitory_system/views/shared/shared_views.dart';
import 'package:carmelitas_dormitory_system/views/tenant/tenant_pages.dart';

class _Routes extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
    super.didPush(route, previousRoute);
  }
}

void main() {
  for (final type in ['late_return', 'overnight_leave']) {
    testWidgets('$type notification displays saved departure and return times',
        (tester) async {
      final departure = DateTime(2026, 10, 9, 19, 30);
      final returning = DateTime(2026, 10, 10, 0, 45);
      final request = CurfewRequest(
          id: 'request',
          tenantId: 'tenant',
          destination: 'Family visit',
          reason: 'Scheduled family visit',
          departureTime: departure,
          expectedReturnTime: returning,
          status: 'approved',
          requestType: type);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
        child: TenantCurfewNotificationRequests(
            requests: [request], onCancel: (_) {}),
      ))));
      expect(find.text('${shortDate(departure)} ${timeText(departure)}'),
          findsOneWidget);
      expect(find.text('${shortDate(returning)} ${timeText(returning)}'),
          findsOneWidget);
      expect(find.text(request.requestTypeLabel.toUpperCase()), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('deleted or inaccessible curfew request has a readable fallback',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: TenantCurfewNotificationRequests(
                requests: const [], onCancel: (_) {}))));
    expect(find.text('Request unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final surface in CarmeLinkAppSurface.values) {
    testWidgets('$surface notification tap uses the authenticated navigator',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final root = _Routes();
      await tester.pumpWidget(MaterialApp(
        navigatorObservers: [root],
        home: CarmeLinkSurfaceScope(
            surface: surface,
            child: AdaptiveRoleShell(
              roleLabel: 'Owner workspace',
              messagePage: const SizedBox(),
              notificationPageBuilder: (_) =>
                  const Scaffold(body: Text('Protected request record')),
              destinations: [
                AppDestination(
                    label: 'Dashboard',
                    icon: Icons.home_outlined,
                    selectedIcon: Icons.home,
                    page: Builder(
                        builder: (context) => Scaffold(
                            body: TextButton(
                                onPressed: () =>
                                    AdaptiveRoleShell.openNotifications(
                                        context),
                                child: const Text('Open inbox')))))
              ],
            )),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open inbox'));
      await tester.pumpAndSettle();
      final inbox =
          tester.widget<NotificationsPage>(find.byType(NotificationsPage));
      final before = root.pushes;
      unawaited(inbox.onOpenNotification!(AppNotificationItem(
          id: '',
          recipientId: 'owner',
          notificationType: 'curfew_pass',
          title: 'Curfew Pass',
          body: 'Request',
          createdAt: DateTime(2026))));
      await tester.pumpAndSettle();
      expect(find.text('Protected request record'), findsOneWidget);
      expect(root.pushes,
          surface == CarmeLinkAppSurface.webPortal ? before : before + 1);
      expect(
          find.byType(AdaptiveRoleShell, skipOffstage: false), findsOneWidget);
      expect(tester.takeException(), isNull);
      // Dispose notification polling and shell subscriptions before teardown.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}
