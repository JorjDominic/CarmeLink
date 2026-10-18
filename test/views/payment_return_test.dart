import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/core/utils/payment_return_link.dart';
import 'package:carmelitas_dormitory_system/services/paymongo_payment_service.dart';
import 'package:carmelitas_dormitory_system/services/receipt_print_service.dart';
import 'package:carmelitas_dormitory_system/views/shared/paymongo_payment_page.dart';
import 'package:carmelitas_dormitory_system/views/shared/payment_return_session_page.dart';
import 'package:carmelitas_dormitory_system/web/payment/payment_return_page.dart';

const id = '00000000-0000-4000-8000-000000000001';
PaymongoPaymentSession session(String status) => PaymongoPaymentSession(
    id: id, status: status, amountCentavos: 10000, environment: 'test');

class Gateway extends PaymongoPaymentService {
  int reads = 0, creates = 0;
  bool fail = false;
  String status = 'pending';
  Completer<PaymongoPaymentSession>? next;
  @override
  Future<PaymongoPaymentSession> refresh(String id) async {
    reads++;
    if (fail) throw StateError('Not authorized or unavailable');
    final pending = next;
    next = null;
    return pending == null ? session(status) : await pending.future;
  }

  @override
  Future<PaymongoPaymentSession> create(String id) async {
    creates++;
    throw StateError('Return must not create a payment');
  }

  @override
  Future<List<PaymentReceipt>> receipts(String id) async => [];
}

void main() {
  for (final width in [320.0, 1280.0]) {
    testWidgets(
        'public return page opens only the app session and remains neutral at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Uri? opened;
      await tester.pumpWidget(MaterialApp(
          home: PaymentReturnPage(
              uri: Uri.parse(
                  'https://carmelitasdormitory.site/payment/return?session_id=$id&status=succeeded'),
              openApp: (uri) async {
                opened = uri;
                return true;
              })));
      await tester.ensureVisible(
          find.widgetWithText(FilledButton, 'Return to CarmeLink'));
      await tester
          .tap(find.widgetWithText(FilledButton, 'Return to CarmeLink'));
      await tester.pumpAndSettle();
      expect(opened, PaymentReturnLink.appUri(id));
      expect(opened!.queryParameters.containsKey('status'), false);
      expect(find.textContaining('does not confirm'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('invalid return link cannot launch anything', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: PaymentReturnPage(
            uri: Uri.parse(
                'https://carmelitasdormitory.site/payment/return?session_id=invalid'))));
    expect(find.byType(FilledButton), findsNothing);
    expect(find.textContaining('incomplete or invalid'), findsOneWidget);
  });
  testWidgets('missing app provides manual fallback', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: PaymentReturnPage(
            uri: PaymentReturnLink.websiteUri(id),
            openApp: (_) async => false)));
    await tester.tap(find.widgetWithText(FilledButton, 'Return to CarmeLink'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not open CarmeLink'), findsOneWidget);
  });
  testWidgets(
      'return verifies through gateway, handles failure and never creates payment',
      (tester) async {
    final gateway = Gateway()..fail = true;
    await tester.pumpWidget(MaterialApp(
        home: PaymentReturnSessionPage(sessionId: id, service: gateway)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not verify'), findsOneWidget);
    gateway.fail = false;
    gateway.status = 'failed';
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(gateway.reads, 2);
    expect(gateway.creates, 0);
    expect(find.text('Payment failed (TEST)'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('app resume immediately rechecks existing pending request',
      (tester) async {
    final gateway = Gateway();
    await tester.pumpWidget(MaterialApp(
        home: PaymongoPaymentPage(
            initialSession: session('pending'), service: gateway)));
    await tester.pumpAndSettle();
    final before = gateway.reads;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(gateway.reads, before + 1);
    expect(gateway.creates, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('resume during a request queues one follow-up verification',
      (tester) async {
    final pending = Completer<PaymongoPaymentSession>();
    final gateway = Gateway()..next = pending;
    await tester.pumpWidget(MaterialApp(
        home: PaymongoPaymentPage(
            initialSession: session('pending'), service: gateway)));
    await tester.pump();
    expect(gateway.reads, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    pending.complete(session('pending'));
    await tester.pumpAndSettle();
    expect(gateway.reads, 2);
    expect(gateway.creates, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
