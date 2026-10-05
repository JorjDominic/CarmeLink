import 'package:carmelitas_dormitory_system/core/widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TripwireFlowCard(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the complete dual-geofence flow on mobile',
      (tester) async {
    await pumpAt(tester, const Size(320, 700));
    expect(find.text('How automatic crossing detection works'), findsOneWidget);
    expect(find.textContaining('Wake circle'), findsOneWidget);
    expect(find.textContaining('Property polygon'), findsOneWidget);
    expect(find.textContaining('Official gate'), findsOneWidget);
    expect(find.textContaining('Point 1 → Point 2'), findsOneWidget);
    expect(find.byKey(const Key('dual-geofence-diagram')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a horizontal-capable flow on web width', (tester) async {
    await pumpAt(tester, const Size(1200, 800));
    expect(
        find.textContaining('Coordinates stay on the phone'), findsOneWidget);
    expect(find.byType(TripwireFlowCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('collapses and hides/shows detection guide', (tester) async {
    await pumpAt(tester, const Size(360, 800));
    expect(find.text('How automatic crossing detection works'), findsOneWidget);
    expect(find.textContaining('Wake circle'), findsOneWidget);

    // Tap collapse button
    await tester.tap(find.byTooltip('Collapse guide'));
    await tester.pump();

    // Diagram/explanation hidden, title remains
    expect(find.text('How automatic crossing detection works'), findsOneWidget);
    expect(find.textContaining('Wake circle'), findsNothing);

    // Tap expand button to restore
    await tester.tap(find.byTooltip('Expand guide'));
    await tester.pump();
    expect(find.textContaining('Wake circle'), findsOneWidget);

    // Tap hide/close button
    await tester.tap(find.byTooltip('Hide guide'));
    await tester.pump();
    expect(find.text('How automatic crossing detection works'), findsNothing);
    expect(find.text('Show crossing detection guide'), findsOneWidget);

    // Tap show guide button to restore
    await tester.tap(find.text('Show crossing detection guide'));
    await tester.pump();
    expect(find.text('How automatic crossing detection works'), findsOneWidget);
    expect(find.textContaining('Wake circle'), findsOneWidget);
  });
}
