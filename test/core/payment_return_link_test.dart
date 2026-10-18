import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/core/utils/payment_return_link.dart';

void main() {
  const id = '00000000-0000-4000-8000-000000000001';
  test('app and website return links resolve only their payment session', () {
    expect(PaymentReturnLink.sessionId(PaymentReturnLink.appUri(id)), id);
    expect(PaymentReturnLink.sessionId(PaymentReturnLink.websiteUri(id)), id);
    expect(
        PaymentReturnLink.sessionId(Uri.parse(
            'https://carmelitasdormitory.site/#/payment/return?session_id=$id')),
        id);
    expect(
        PaymentReturnLink.sessionId(Uri.parse(
            'carmelink://payment-return?session_id=$id&status=succeeded&amount=1')),
        id);
  });
  test(
      'wrong origins, malformed and ambiguous session identifiers are rejected',
      () {
    for (final link in [
      'https://evil.example/payment/return?session_id=$id',
      'https://carmelitasdormitory.site.evil.example/payment/return?session_id=$id',
      'http://carmelitasdormitory.site/payment/return?session_id=$id',
      'https://user@carmelitasdormitory.site/payment/return?session_id=$id',
      'https://carmelitasdormitory.site:444/payment/return?session_id=$id',
      'carmelink://onboarding?session_id=$id',
      'carmelink://payment-return/other?session_id=$id',
      'carmelink://payment-return?session_id=not-a-session',
      'carmelink://payment-return?session_id=$id&session_id=$id',
      'carmelink://payment-return?session_id=%FF',
      'carmelink://payment-return?session_id=$id#/payment/return?session_id=$id',
      'https://carmelitasdormitory.site/?session_id=$id#/payment/return?session_id=$id',
      'carmelink://payment-return',
    ]) {
      expect(PaymentReturnLink.sessionId(Uri.parse(link)), isNull,
          reason: link);
    }
    expect(() => PaymentReturnLink.appUri('bad'), throwsArgumentError);
  });
}
