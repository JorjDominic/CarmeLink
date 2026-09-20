import 'package:carmelitas_dormitory_system/views/auth/auth_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('email verification uses a six-digit code', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: EmailVerificationCodePage(email: 'resident@example.com'),
      ),
    );

    expect(find.text('Verify your email'), findsOneWidget);
    expect(find.text('Six-digit verification code'), findsOneWidget);
    expect(find.text('Verify email'), findsOneWidget);
    expect(find.text('Send code'), findsOneWidget);
    expect(find.text('Use a different account'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '12a345678');
    expect(find.text('123456'), findsOneWidget);
  });

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
    expect(find.text('Send code'), findsOneWidget);
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
