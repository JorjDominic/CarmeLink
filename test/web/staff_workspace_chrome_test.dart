import 'package:carmelitas_dormitory_system/core/widgets/adaptive_shell.dart';
import 'package:carmelitas_dormitory_system/web/dashboard/widgets/staff_workspace_chrome.dart';
import 'package:carmelitas_dormitory_system/web/theme/web_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> mount(
    WidgetTester tester, {
    required Size size,
    required String role,
    required VoidCallback onMessages,
    required VoidCallback onNotifications,
    required VoidCallback onProfile,
    required Future<void> Function() onSignOut,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        theme: WebTheme.light(),
        home: CarmelitaNavScope(
          openMenu: () async {},
          openMessages: onMessages,
          openNotifications: onNotifications,
          unreadMessageCount: 2,
          unreadNotificationCount: 5,
          selectIndex: (_) {},
          selectLabel: (label) {
            if (label == 'Profile') onProfile();
          },
          child: StaffWorkspaceChrome(
            roleLabel: role,
            onSignOut: onSignOut,
            child: const Center(child: Text('Existing staff modules')),
          ),
        ),
      ),
    );
  }

  testWidgets('desktop top header owns utilities and logout', (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    var messages = 0;
    var notifications = 0;
    var profiles = 0;
    var logouts = 0;
    await mount(
      tester,
      size: const Size(1280, 800),
      role: 'Owner',
      onMessages: () => messages++,
      onNotifications: () => notifications++,
      onProfile: () => profiles++,
      onSignOut: () async {
        logouts++;
      },
    );

    expect(find.text('Staff workspace'), findsOneWidget);
    expect(find.text('Owner'), findsOneWidget);
    expect(find.text('Public website'), findsNothing);
    expect(find.text('Logout'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('Existing staff modules'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('staff-workspace-messages')));
    await tester.tap(find.byKey(const Key('staff-workspace-notifications')));
    await tester.tap(find.byKey(const Key('web-header-account')));
    await tester.tap(find.byKey(const Key('staff-workspace-logout')));
    await tester.pump();

    expect(messages, 1);
    expect(notifications, 1);
    expect(profiles, 1);
    expect(logouts, 1);
  });

  testWidgets('320px top header stays usable without overflow', (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await mount(
      tester,
      size: const Size(320, 640),
      role: 'Caretaker',
      onMessages: () {},
      onNotifications: () {},
      onProfile: () {},
      onSignOut: () async {},
    );

    expect(find.text('Caretaker'), findsOneWidget);
    expect(find.text('Public website'), findsNothing);
    expect(find.byKey(const Key('staff-workspace-messages')), findsOneWidget);
    expect(
        find.byKey(const Key('staff-workspace-notifications')), findsOneWidget);
    expect(find.byKey(const Key('web-header-account')), findsOneWidget);
    expect(find.byKey(const Key('staff-workspace-logout')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
