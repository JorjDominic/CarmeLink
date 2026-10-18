import 'package:carmelitas_dormitory_system/views/shared/shared_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('profile operation tiles keep visible ink surfaces',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
    await tester.pumpAndSettle();
    expect(find.text('Room transfers & amendments'), findsOneWidget);
    expect(find.text('Eviction & departure notices'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final width in [320.0, 360.0, 390.0, 768.0, 1280.0, 1600.0]) {
      testWidgets('profile ink and system insets at $platform / $width',
          (tester) async {
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
            theme: ThemeData(platform: platform), home: const ProfilePage()));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Room transfers & amendments'));
        expect(find.text('Room transfers & amendments'), findsOneWidget);
        await tester.ensureVisible(find.text('Eviction & departure notices'));
        expect(find.text('Eviction & departure notices'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
