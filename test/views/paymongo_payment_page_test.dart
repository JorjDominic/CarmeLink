import 'package:carmelitas_dormitory_system/services/paymongo_payment_service.dart';
import 'package:carmelitas_dormitory_system/services/payment_collection_settings_service.dart';
import 'package:carmelitas_dormitory_system/views/tenant/tenant_pages.dart';
import 'package:carmelitas_dormitory_system/views/shared/paymongo_payment_page.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/controllers/tenant_controller.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';

class _AdvanceGateway extends PaymongoPaymentService {
  List<String>? selected;
  bool confirmedRequested = false;
  @override
  Future<PaymongoPaymentSession?> confirmed(String id) async {
    confirmedRequested = true;
    return const PaymongoPaymentSession(
        id: 'confirmed',
        status: 'succeeded',
        amountCentavos: 650000,
        environment: 'test',
        reference: 'pay_Receipt',
        billBreakdown: [
          PaymongoBillBreakdown(
              chargeId: 'nov', title: 'November Rent', amountCentavos: 300000),
          PaymongoBillBreakdown(
              chargeId: 'dec', title: 'December Rent', amountCentavos: 350000),
        ]);
  }

  @override
  Future<PaymongoPaymentSession?> latest(String id) async => null;
  @override
  Future<PaymongoPaymentSession> createAdvance(List<String> ids) async {
    selected = ids;
    return const PaymongoPaymentSession(
        id: 'advance',
        status: 'pending',
        amountCentavos: 650000,
        environment: 'test',
        billBreakdown: [
          PaymongoBillBreakdown(
              chargeId: 'nov', title: 'November Rent', amountCentavos: 300000),
          PaymongoBillBreakdown(
              chargeId: 'dec', title: 'December Rent', amountCentavos: 350000),
        ]);
  }

  @override
  Future<PaymongoPaymentSession> refresh(String id) async =>
      throw StateError('No polling expected');
}

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
  testWidgets('paid bill reopens the confirmed multi-month receipt',
      (tester) async {
    final gateway = _AdvanceGateway();
    final paid = Payment(
        id: 'dec',
        label: 'December Rent',
        amount: 3500,
        remainingBalance: 0,
        dueDate: DateTime(2026, 12, 1),
        status: 'verified',
        paymentMethod: 'PayMongo QR Ph (Demo Test)');
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: PaymongoPaymentPage(payment: paid, service: gateway))));
    await tester.pumpAndSettle();
    expect(gateway.confirmedRequested, isTrue);
    expect(find.text('November Rent'), findsOneWidget);
    expect(find.text('December Rent'), findsOneWidget);
    expect(find.text('PHP 6500.00'), findsOneWidget);
    expect(find.text('Reference: pay_Receipt'), findsOneWidget);
    expect(find.text('Generate payment request'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('selected rent months show balances and use one payment request',
      (tester) async {
    final november = Payment(
        id: 'nov',
        label: 'November Rent',
        amount: 3500,
        remainingBalance: 3000,
        dueDate: DateTime(2026, 11, 1),
        periodStart: DateTime(2026, 11, 1),
        periodEnd: DateTime(2026, 11, 30),
        status: 'upcoming');
    final december = Payment(
        id: 'dec',
        label: 'December Rent',
        amount: 3500,
        dueDate: DateTime(2026, 12, 1),
        periodStart: DateTime(2026, 12, 1),
        periodEnd: DateTime(2026, 12, 31),
        status: 'upcoming');
    TenantController.instance.setPaymentsForTesting([
      november,
      december,
      Payment(
          id: 'utility',
          label: 'Water',
          amount: 500,
          dueDate: DateTime(2026, 11, 1),
          status: 'due',
          category: 'utility')
    ]);
    addTearDown(() => TenantController.instance.setPaymentsForTesting([]));
    final gateway = _AdvanceGateway();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: PaymongoPaymentPage(payment: november, service: gateway))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rent-month-utility')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('rent-month-dec')));
    await tester.pumpAndSettle();
    expect(find.text('PHP 6500.00'), findsOneWidget);
    expect(find.text('Payment breakdown'), findsOneWidget);
    expect(find.text('November 2026'), findsOneWidget);
    expect(find.text('December 2026'), findsOneWidget);
    await tester.ensureVisible(find.text('Generate payment request'));
    await tester.tap(find.text('Generate payment request'));
    await tester.pumpAndSettle();
    expect(gateway.selected, unorderedEquals(['nov', 'dec']));
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.text('November Rent'), findsOneWidget);
    expect(find.text('December Rent'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('confirmed payment keeps its saved month breakdown',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: PaymongoPaymentPage(
                initialSession: PaymongoPaymentSession(
                    id: 'saved',
                    status: 'succeeded',
                    amountCentavos: 700000,
                    environment: 'live',
                    reference: 'pay_Saved',
                    billBreakdown: [
          PaymongoBillBreakdown(
              chargeId: 'nov',
              title: 'November 2026 Rent',
              amountCentavos: 350000),
          PaymongoBillBreakdown(
              chargeId: 'dec',
              title: 'December 2026 Rent',
              amountCentavos: 350000),
        ])))));
    await tester.pumpAndSettle();
    expect(find.text('November 2026 Rent'), findsWidgets);
    expect(find.text('December 2026 Rent'), findsWidgets);
    expect(find.text('PHP 7000.00'), findsOneWidget);
    expect(find.text('Reference: pay_Saved'), findsOneWidget);
    expect(find.text('Payment confirmed'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('payment entry follows the persisted automatic mode',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: UploadPaymentProofPage(
                collectionSettingsService: _AutomaticSettings()))));
    await tester.pumpAndSettle();
    expect(find.byType(PaymongoPaymentPage), findsOneWidget);
    expect(find.text('Pay with PayMongo QR Ph (TEST)'), findsOneWidget);
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
    expect(find.text('Payment preview; bills remain unchanged. (TEST)'),
        findsOneWidget);
    await tap(tester, 'Start demo payment');
    expect(find.text('Awaiting payment (TEST)'), findsOneWidget);
    expect(find.byKey(const Key('demo-payment-qr')), findsOneWidget);
    await tap(tester, 'Simulate successful payment');
    expect(find.text('Payment confirmed (TEST)'), findsOneWidget);
    expect(find.textContaining('Actual balances unchanged.'), findsOneWidget);
    expect(service.calls, 0);
  });
  testWidgets('demo failure, expiry and cancellation permit restarting',
      (tester) async {
    final service = _NeverCalledGateway();
    await demo(tester, service);
    await tap(tester, 'Start demo payment');
    await tap(tester, 'Simulate failed payment');
    expect(find.text('Payment failed (TEST)'), findsOneWidget);
    await tap(tester, 'Start demo payment');
    await tap(tester, 'Simulate expired QR');
    expect(find.text('QR expired (TEST)'), findsOneWidget);
    await tap(tester, 'Start demo payment');
    await tap(tester, 'Cancel payment request');
    expect(find.text('Payment cancelled (TEST)'), findsOneWidget);
    expect(service.calls, 0);
  });
  testWidgets('sandbox displays a nonpayment demo QR and simulation link',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: PaymongoPaymentPage(
      initialSession: PaymongoPaymentSession(
          id: 'test',
          status: 'pending',
          amountCentavos: 350000,
          environment: 'test',
          qrImage:
              'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
          testUrl: 'https://test-sources.paymongo.com/demo'),
    ))));
    await tester.pump();
    expect(find.byType(Image), findsNothing);
    final qr =
        tester.widget<QrImageView>(find.byKey(const Key('demo-payment-qr')));
    expect(qr.semanticsLabel, 'Demo QR code. Cannot collect payment.');
    expect(find.text('Payment QR (TEST)'), findsOneWidget);
    expect(find.text('Open payment page (TEST)'), findsOneWidget);
    expect(find.textContaining('No real money is received. (TEST)'),
        findsOneWidget);
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
