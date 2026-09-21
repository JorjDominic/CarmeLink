import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/web/dashboard/widgets/staff_workspace_chrome.dart';
import 'package:carmelitas_dormitory_system/web/theme/web_theme.dart';

void main() {
  Future<void> mount(
    WidgetTester tester, {
    required Size size,
    required String role,
    required VoidCallback onPublic,
    required Future<void> Function() onSignOut,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(MaterialApp(
      theme: WebTheme.light(),
      home: StaffWorkspaceChrome(
        roleLabel: role,
        onPublicWebsite: onPublic,
        onSignOut: onSignOut,
        child: const Center(child: Text('Existing staff modules')),
      ),
    ));
  }

  testWidgets('desktop displays real-workspace chrome and both controls',
      (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    var publicOpens = 0;
    var signOuts = 0;
    await mount(
      tester,
      size: const Size(1280, 800),
      role: 'Owner',
      onPublic: () => publicOpens++,
      onSignOut: () async {
        signOuts++;
      },
    );
    expect(find.text('Staff workspace'), findsOneWidget);
    expect(find.text('Owner'), findsOneWidget);
    expect(find.text('Existing staff modules'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('staff-workspace-public')));
    await tester.tap(find.byKey(const Key('staff-workspace-signout')));
    await tester.pump();
    expect(publicOpens, 1);
    expect(signOuts, 1);
  });

  testWidgets('320px browser shows compact controls without overflow',
      (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    var publicOpens = 0;
    var signOuts = 0;
    await mount(
      tester,
      size: const Size(320, 640),
      role: 'Caretaker',
      onPublic: () => publicOpens++,
      onSignOut: () async {
        signOuts++;
      },
    );
    expect(find.text('Caretaker workspace'), findsOneWidget);
    expect(find.text('Existing staff modules'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('staff-workspace-public')));
    await tester.tap(find.byKey(const Key('staff-workspace-signout')));
    await tester.pump();
    expect(publicOpens, 1);
    expect(signOuts, 1);
    expect(tester.takeException(), isNull);
  });
}
