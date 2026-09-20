import 'package:carmelitas_dormitory_system/views/auth/auth_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('welcome is shown once and skipped after completion',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MaterialApp(home: AuthFlow()));
    expect(find.byType(SplashPage), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();
    expect(find.byType(WelcomePage), findsOneWidget);

    await tester.ensureVisible(find.text('Continue to sign in'));
    await tester.tap(find.text('Continue to sign in'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SignInPage), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: AuthFlow()));
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(WelcomePage), findsNothing);
    expect(find.byType(SignInPage), findsOneWidget);
  });
}
