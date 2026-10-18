import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/services/confidentiality_agreement_service.dart';
import 'package:carmelitas_dormitory_system/views/shared/module_agreement_gate.dart';
import 'package:carmelitas_dormitory_system/controllers/tenant_controller.dart';

class Agreements extends ConfidentialityAgreementService {
  Agreements(AgreementModule module) : super(module: module);
  bool allowed = false, fail = false, failAccept = false, published = true;
  String version = '1';
  int acceptCalls = 0;
  Completer<ModuleAgreementStatus>? pending;
  @override
  Future<ModuleAgreementStatus> status() async {
    if (fail) throw StateError('Offline');
    if (pending != null) return pending!.future;
    return ModuleAgreementStatus(
        allowed: allowed,
        agreement: !published
            ? null
            : {
                'id': '${module.key}-$version',
                'audience': 'tenant',
                'version': version,
                'published_at': '2026-10-18T00:00:00Z',
                'content':
                    'Approved test fixture for ${module.title}. Review the full text before accepting.',
              });
  }

  @override
  Future<void> accept(String id,
      {required bool reviewed, required bool accepted}) async {
    expect(reviewed && accepted, isTrue);
    expect(id, '${module.key}-$version');
    acceptCalls++;
    if (failAccept) throw StateError('Acceptance failed');
    allowed = true;
  }
}

void main() {
  for (final module in AgreementModule.values) {
    for (final width in [320.0, 1280.0]) {
      testWidgets(
          '${module.title}: review and explicit acceptance unlock only after save at $width',
          (tester) async {
        tester.view.physicalSize = Size(width, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final service = Agreements(module)..failAccept = true;
        var builds = 0;
        await tester.pumpWidget(MaterialApp(
            home: ModuleAgreementGate(
                service: service,
                builder: (_) {
                  builds++;
                  return const Scaffold(body: Text('Protected module'));
                })));
        await tester.pumpAndSettle();
        expect(builds, 0);
        expect(find.text('Protected module'), findsNothing);
        expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
            isNull);
        await tester.ensureVisible(find.byType(CheckboxListTile));
        await tester.tap(find.byType(CheckboxListTile));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Accept and continue'));
        await tester.tap(find.text('Accept and continue'));
        await tester.pumpAndSettle();
        expect(service.acceptCalls, 1);
        expect(builds, 0);
        expect(find.textContaining('Acceptance was not confirmed'),
            findsOneWidget);
        service.failAccept = false;
        await tester.tap(find.text('Accept and continue'));
        await tester.pumpAndSettle();
        expect(find.text('Protected module'), findsOneWidget);
        expect(builds, greaterThan(0));
        service.allowed = false;
        service.version = '2';
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pumpAndSettle();
        expect(find.text('Protected module'), findsNothing);
        expect(find.textContaining('Agreement · 2'), findsOneWidget);
        expect(
            tester
                .widget<CheckboxListTile>(find.byType(CheckboxListTile))
                .value,
            isFalse);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
    testWidgets(
        '${module.title}: missing agreement and network failure keep content unbuilt',
        (tester) async {
      final service = Agreements(module)..published = false;
      var builds = 0;
      await tester.pumpWidget(MaterialApp(
          home: ModuleAgreementGate(
              service: service,
              builder: (_) {
                builds++;
                return const Text('Protected module');
              })));
      await tester.pumpAndSettle();
      expect(builds, 0);
      expect(find.textContaining('until the owner publishes'), findsOneWidget);
      service.fail = true;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(builds, 0);
      expect(find.textContaining('Unable to verify'), findsOneWidget);
    });
    testWidgets('${module.title}: decline returns without accepting',
        (tester) async {
      final service = Agreements(module);
      await tester.pumpWidget(MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                              builder: (_) => ModuleAgreementGate(
                                  service: service,
                                  builder: (_) =>
                                      const Text('Protected module')))),
                      child: const Text('Open module'))))));
      await tester.tap(find.text('Open module'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Decline and go back'));
      await tester.tap(find.text('Decline and go back'));
      await tester.pumpAndSettle();
      expect(find.text('Open module'), findsOneWidget);
      expect(service.acceptCalls, 0);
    });
  }
  test(
      'geofence check is blocked before location evaluation when acceptance is absent',
      () async {
    final service = Agreements(AgreementModule.geofencing);
    final result = await TenantController.instance
        .performGeofenceCheckIn(agreementService: service);
    expect(result.isUnavailable, isTrue);
    expect(result.errorMessage,
        contains('accept the current geofencing agreement'));
  });
}
