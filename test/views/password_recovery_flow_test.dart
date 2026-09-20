import 'package:carmelitas_dormitory_system/views/auth/auth_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('recovery code page masks email and exposes safe controls',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PasswordRecoveryCodePage(email: 'resident@example.com'),
      ),
    );

    expect(find.text('Enter recovery code'), findsOneWidget);
    expect(find.textContaining('r••'), findsOneWidget);
    expect(find.text('Six-digit code'), findsOneWidget);
    expect(find.text('Verify code'), findsOneWidget);
    expect(find.textContaining('Resend code in'), findsOneWidget);
    expect(find.text('Use a different email'), findsOneWidget);
  });

  testWidgets('recovery code field accepts only six digits', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PasswordRecoveryCodePage(email: 'resident@example.com'),
      ),
    );

    await tester.enterText(find.byType(TextField), '12a345678');

    expect(find.text('123456'), findsOneWidget);
  });
}
