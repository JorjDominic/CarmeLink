import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/web/demo/demo_portal.dart';
import 'package:carmelitas_dormitory_system/web/preview/staff_preview_app.dart';

void main() {
  testWidgets('demo role selector opens local owner workspace', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const StaffPreviewApp());
    expect(find.text('Preview the staff portal.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('preview-owner')));
    await tester.pumpAndSettle();
    expect(find.byType(DemoPortal), findsOneWidget);
    expect(find.text('Good day, Demo Owner.'), findsOneWidget);
  });
}
