import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/main_staff_preview.dart';
import 'package:carmelitas_dormitory_system/web/landing/landing_page.dart';

void main() {
  testWidgets('local demo opens public site before preview', (tester) async {
    await tester.pumpWidget(const CarmeLinkLocalDemoApp());
    expect(find.byType(LandingPage), findsOneWidget);

    // Use the same named route invoked by the landing page's footer link.
    final landingContext = tester.element(find.byType(LandingPage));
    Navigator.of(landingContext).pushNamed('/staff');
    await tester.pumpAndSettle();
    expect(find.text('Preview the staff portal.'), findsOneWidget);
    expect(find.text('LOCAL DEMO'), findsOneWidget);
  });
}
