import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile sign-in fields use icons without floating field labels', () {
    final source =
        File('lib/views/auth/auth_views.dart').readAsStringSync();

    final start = source.indexOf('class SignInPage');
    final end = source.indexOf('class EmailVerificationCodePage', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));

    final signIn = source.substring(start, end);

    expect(signIn.contains("labelText: 'Email address'"), isFalse);
    expect(signIn.contains("labelText: 'Password'"), isFalse);
    expect(signIn.contains('Icon(Icons.mail_outline)'), isTrue);
    expect(signIn.contains('Icon(Icons.lock_outline)'), isTrue);
  });
}
