import 'package:carmelitas_dormitory_system/services/paymongo_payment_service.dart';
import 'package:carmelitas_dormitory_system/services/payment_collection_settings_service.dart';
import 'package:carmelitas_dormitory_system/views/tenant/tenant_pages.dart';
import 'package:carmelitas_dormitory_system/views/shared/paymongo_payment_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _NeverCalledGateway extends PaymongoPaymentService {
  int calls = 0;
  @override
  Future<PaymongoPaymentSession> create(String id) async {
    calls++;
    throw StateError('Demo contacted backend');
  }

  @override
  Future<PaymongoPaymentSession> refresh(String id) async {
    calls++;
    throw StateError('Demo contacted backend');
  }

  @override
  Future<PaymongoPaymentSession> cancel(String id) async {
    calls++;
    throw StateError('Demo contacted backend');
  }

  @override
  Future<PaymongoPaymentSession?> latest(String id) async {
    calls++;
    throw StateError('Demo contacted backend');
  }
}

class _AutomaticSettings extends PaymentCollectionSettingsService {
  @override
  Future<PaymentCollectionSettings> load() async =>
      const PaymentCollectionSettings(
          mode: PaymentCollectionMode.paymongo, paymongoReady: true);
}

void main() {
  testWidgets('payment entry follows the persisted automatic mode',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: UploadPaymentProofPage(
                collectionSettingsService: _AutomaticSettings()))));
    await tester.pumpAndSettle();
    expect(find.byType(PaymongoPaymentPage), findsOneWidget);
    expect(find.text('Pay with PayMongo QR Ph'), findsOneWidget);
    expect(find.text('Upload receipt'), findsNothing);
  });
  Future<void> tap(WidgetTester tester, String label) async {
    final finder = find.text(label);
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> demo(WidgetTester tester, _NeverCalledGateway service) async {
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home:
            Scaffold(body: PaymongoPaymentPage(demo: true, service: service))));
    await tester.pumpAndSettle();
  }

  testWidgets('iOS demo confirms only the sample bill without backend calls',
      (tester) async {
    final service = _NeverCalledGateway();
    await demo(tester, service);
    expect(find.textContaining('DEMO ONLY'), findsOneWidget);
    await tap(tester, 'Start demo payment');
    expect(find.text('Awaiting payment'), findsOneWidget);
    await tap(tester, 'Simulate successful payment');
    expect(find.text('Test payment confirmed'), findsOneWidget);
    expect(find.textContaining('Actual balances unchanged.'), findsOneWidget);
    expect(service.calls, 0);
  });
  testWidgets('demo failure, expiry and cancellation permit restarting',
      (tester) async {
    final service = _NeverCalledGateway();
    await demo(tester, service);
    await tap(tester, 'Start demo payment');
    await tap(tester, 'Simulate failed payment');
    expect(find.text('Payment failed'), findsOneWidget);
    await tap(tester, 'Start demo payment');
    await tap(tester, 'Simulate expired QR');
    expect(find.text('QR expired'), findsOneWidget);
    await tap(tester, 'Start demo payment');
    await tap(tester, 'Cancel payment request');
    expect(find.text('Payment cancelled'), findsOneWidget);
    expect(service.calls, 0);
  });
  testWidgets('sandbox suppresses a scannable QR and offers test page',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: PaymongoPaymentPage(
      initialSession: PaymongoPaymentSession(
          id: 'test',
          status: 'pending',
          amountCentavos: 350000,
          environment: 'test',
          qrImage: 'data:image/png;base64,aGVsbG8=',
          testUrl: 'https://test-sources.paymongo.com/demo'),
    ))));
    await tester.pump();
    expect(find.byType(Image), findsNothing);
    expect(find.text('Open test payment page'), findsOneWidget);
    expect(
        find.textContaining('Actual bills remain unchanged.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('demo fits a narrow iOS screen', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await demo(tester, _NeverCalledGateway());
    await tap(tester, 'Start demo payment');
    expect(tester.takeException(), isNull);
  });
}
