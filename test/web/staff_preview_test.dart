import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/web/demo/demo_portal.dart';
import 'package:carmelitas_dormitory_system/web/preview/staff_preview_app.dart';

void main() {
  testWidgets('owner preview is clearly marked as local demo', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const StaffPreviewApp());
    expect(find.text('LOCAL DEMO'), findsOneWidget);
    expect(find.textContaining('No password required.'), findsOneWidget);

    final owner = find.byKey(const Key('preview-owner'));
    await tester.ensureVisible(owner);
    await tester.pumpAndSettle();
    await tester.tap(owner);
    await tester.pumpAndSettle();
    expect(find.byType(DemoPortal), findsOneWidget);
    expect(find.text('Good day, Demo Owner.'), findsOneWidget);
  });

  testWidgets('caretaker opens the separate local workspace', (tester) async {
    // Reproduce the smaller default widget-test viewport.
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const StaffPreviewApp());
    final caretaker = find.byKey(const Key('preview-caretaker'));
    await tester.ensureVisible(caretaker);
    await tester.pumpAndSettle();
    await tester.tap(caretaker);
    await tester.pumpAndSettle();
    expect(find.byType(DemoPortal), findsOneWidget);
    expect(find.text('Good day, Demo Caretaker.'), findsOneWidget);
  });
}
