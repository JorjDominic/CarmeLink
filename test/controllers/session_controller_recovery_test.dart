import 'package:carmelitas_dormitory_system/controllers/session_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('password recovery callback detection', () {
    test('recognizes the production reset path', () {
      expect(
        SessionController.isPasswordRecoveryUri(
          Uri.parse(
            'https://carmelitasdormitory.site/reset-password?code=abc',
          ),
        ),
        isTrue,
      );
    });

    test('recognizes a hash-routed reset path', () {
      expect(
        SessionController.isPasswordRecoveryUri(
          Uri.parse(
            'https://carmelitasdormitory.site/#/reset-password?code=abc',
          ),
        ),
        isTrue,
      );
    });

    test('does not treat the login page as recovery', () {
      expect(
        SessionController.isPasswordRecoveryUri(
          Uri.parse('https://carmelitasdormitory.site/login'),
        ),
        isFalse,
      );
    });
  });
}
