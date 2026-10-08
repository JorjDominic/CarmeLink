import 'package:carmelitas_dormitory_system/services/payment_collection_settings_service.dart';
import 'package:carmelitas_dormitory_system/views/owner/payment_collection_settings_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _SettingsService extends PaymentCollectionSettingsService {
  PaymentCollectionSettings settings = const PaymentCollectionSettings();
  bool failLoad = false;
  bool failSave = false;
  int saves = 0;

  @override
  Future<PaymentCollectionSettings> load() async {
    if (failLoad) throw Exception('Offline');
    return settings;
  }

  @override
  Future<PaymentCollectionSettings> save(PaymentCollectionMode mode) async {
    saves++;
    if (failSave) throw Exception('Not ready');
    return settings =
        PaymentCollectionSettings(mode: mode, paymongoReady: true);
  }
}

void main() {
  Future<void> mount(WidgetTester tester, _SettingsService service) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: SingleChildScrollView(
              child: PaymentCollectionSettingsCard(service: service))),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('Manual is selected and unconfigured PayMongo cannot be enabled',
      (tester) async {
    final service = _SettingsService();
    await mount(tester, service);
    final selector = tester.widget<SegmentedButton<PaymentCollectionMode>>(
        find.byType(SegmentedButton<PaymentCollectionMode>));
    expect(selector.selected, {PaymentCollectionMode.manual});
    expect(selector.segments.last.enabled, isFalse);
    await tester.tap(find.text('Automatic'));
    await tester.pumpAndSettle();
    expect(service.saves, 0);
    expect(
        find.textContaining('PayMongo is not connected yet.'), findsOneWidget);
  });

  testWidgets('Configured modes persist through the service', (tester) async {
    final service = _SettingsService()
      ..settings = const PaymentCollectionSettings(paymongoReady: true);
    await mount(tester, service);
    await tester.tap(find.text('Automatic'));
    await tester.pumpAndSettle();
    expect(service.settings.mode, PaymentCollectionMode.paymongo);
    await tester.tap(find.text('Manual'));
    await tester.pumpAndSettle();
    expect(service.settings.mode, PaymentCollectionMode.manual);
    expect(service.saves, 2);
  });

  testWidgets('Failed save retains the previous selection', (tester) async {
    final service = _SettingsService()
      ..settings = const PaymentCollectionSettings(paymongoReady: true)
      ..failSave = true;
    await mount(tester, service);
    await tester.tap(find.text('Automatic'));
    await tester.pumpAndSettle();
    final selector = tester.widget<SegmentedButton<PaymentCollectionMode>>(
        find.byType(SegmentedButton<PaymentCollectionMode>));
    expect(selector.selected, {PaymentCollectionMode.manual});
    expect(
        find.textContaining('Could not change payment mode.'), findsOneWidget);
  });

  testWidgets('Load failure offers refresh without inventing a mode',
      (tester) async {
    final service = _SettingsService()..failLoad = true;
    await mount(tester, service);
    expect(find.byType(SegmentedButton<PaymentCollectionMode>), findsNothing);
    service.failLoad = false;
    await tester.tap(find.byTooltip('Refresh payment settings'));
    await tester.pumpAndSettle();
    expect(find.text('Manual'), findsOneWidget);
  });

  testWidgets('Payment setting fits a narrow mobile screen', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(tester, _SettingsService());
    expect(tester.takeException(), isNull);
  });
}
