import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/services/conduct_case_service.dart';
import 'package:carmelitas_dormitory_system/services/confidentiality_agreement_service.dart';
import 'package:carmelitas_dormitory_system/views/shared/conduct_investigation_panel.dart';
import 'package:carmelitas_dormitory_system/views/shared/confidentiality_agreements_page.dart';

final version = <String, dynamic>{
  'id': 'agreement-1',
  'version': '1',
  'audience': 'tenant',
  'published_at': '2026-10-16T00:00:00Z',
  'content':
      List.filled(30, 'Approved test fixture content for agreement review.')
          .join('\n\n')
};
final record = ConductCaseRecord(
    id: 'case-1',
    category: 'safety',
    title: 'Original case',
    description: 'Original incident description',
    incidentAt: DateTime(2026, 10, 16),
    status: 'under_review',
    tenantNotifiedAt: DateTime(2026, 10, 16),
    createdAt: DateTime(2026, 10, 16),
    updatedAt: DateTime(2026, 10, 16));

class Agreements extends ConfidentialityAgreementService {
  final calls = <String>[];
  Completer<void>? pending;
  bool fail = false;
  @override
  Future<void> accept(String id,
      {required bool reviewed, required bool accepted}) async {
    expect(reviewed, isTrue);
    expect(accepted, isTrue);
    calls.add(id);
    if (fail) throw StateError('Offline');
    await pending?.future;
  }
}

class Investigation extends ConductCaseService {
  bool fail = false;
  @override
  Future<Map<String, dynamic>> investigation(String id) async {
    if (fail) throw StateError('Offline');
    return {
      'tenant_status': {
        'tenant_id': 'tenant-1',
        'status': 'continuous_violations',
        'confirmed': 4,
        'recent_confirmed': 3
      },
      'counts': {
        'total': 4,
        'confirmed': 2,
        'pending': 1,
        'unconfirmed': 1,
        'closed_without_outcome': 0,
        'appealed': 1
      },
      'decisions': [
        {
          'outcome': 'confirmed',
          'reason':
              List.filled(20, 'A documented investigation finding.').join(' '),
          'actor_name': 'Owner',
          'created_at': '2026-10-16T00:00:00Z'
        }
      ]
    };
  }

  @override
  Future<String> evidencePreview(ConductCaseEvidence evidence) async =>
      throw StateError('No access');
}

class Decisions extends Investigation {
  final calls = <Map<String, String>>[];
  bool reject = true;
  @override
  Future<void> recordDecision(
      {required ConductCaseRecord record,
      required String outcome,
      required String reason,
      required String requestId,
      String? appealId}) async {
    calls.add({'reason': reason, 'request': requestId, 'outcome': outcome});
    if (reject) throw StateError('Network interrupted');
  }
}

Future<void> bottom(WidgetTester tester) async {
  for (var n = 0; n < 24; n++) {
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [320.0, 1280.0]) {
    testWidgets('agreement review and explicit acceptance at width $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = Agreements()..pending = Completer<void>();
      await tester.pumpWidget(MaterialApp(
          home: AgreementReviewPage(
              version: version, canAccept: true, service: service)));
      await tester.pumpAndSettle();
      expect(service.calls, isEmpty);
      await bottom(tester);
      expect(
          tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
          isFalse);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.text('Accept agreement'));
      await tester.pump();
      expect(service.calls, ['agreement-1']);
      expect(find.text('Acceptance saved successfully.'), findsNothing);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull);
      service.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Acceptance saved successfully.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets('investigation decisions and counts wrap at width $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: ConductInvestigationPanel(
                      record: record, service: Investigation())))));
      await tester.pumpAndSettle();
      expect(find.text('Tenant conduct status: Continuous violations'),
          findsOneWidget);
      expect(find.text('Confirmed violation'), findsOneWidget);
      expect(find.textContaining('Confirmed incidents: 2'), findsOneWidget);
      expect(find.text('Confirm violation'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'Owner decision fits narrow keyboard layout and retries the frozen payload',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final service = Decisions();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: ConductInvestigationPanel(
                    record: record, canDecide: true, service: service)))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Confirm violation'));
    await tester.tap(find.text('Confirm violation'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 250);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextField), 'Reviewed original evidence and explanation.');
    await tester.ensureVisible(find.text('Save decision'));
    await tester.tap(find.text('Save decision'));
    await tester.pumpAndSettle();
    expect(service.calls.length, 1);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    service.reject = false;
    await tester.tap(find.text('Save decision'));
    await tester.pumpAndSettle();
    expect(service.calls.length, 2);
    expect(service.calls[0], service.calls[1]);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('failed acceptance never reports success and can retry safely',
      (tester) async {
    final service = Agreements()..fail = true;
    await tester.pumpWidget(MaterialApp(
        home: AgreementReviewPage(version: {
      ...version,
      'content': 'Complete short approved test fixture.'
    }, canAccept: true, service: service)));
    await tester.pumpAndSettle();
    await bottom(tester);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.text('Accept agreement'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Acceptance was not confirmed.'), findsOneWidget);
    expect(find.text('Acceptance saved successfully.'), findsNothing);
    service.fail = false;
    await tester.tap(find.text('Accept agreement'));
    await tester.pumpAndSettle();
    expect(find.text('Acceptance saved successfully.'), findsOneWidget);
  });
  testWidgets(
      'historical or already accepted agreements never show new acceptance controls',
      (tester) async {
    final service = Agreements();
    await tester.pumpWidget(MaterialApp(
        home: AgreementReviewPage(
            version: version, canAccept: false, service: service)));
    await tester.pumpAndSettle();
    await bottom(tester);
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(service.calls, isEmpty);
    await tester.pumpWidget(MaterialApp(
        home: AgreementReviewPage(
            key: const ValueKey('accepted'),
            version: version,
            acceptedAt: '2026-10-16T01:00:00Z',
            canAccept: true,
            service: service)));
    await tester.pumpAndSettle();
    await bottom(tester);
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(service.calls, isEmpty);
  });
  testWidgets(
      'investigation error does not display inferred confirmation and retry restores projection',
      (tester) async {
    final service = Investigation()..fail = true;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: ConductInvestigationPanel(
                    record: record, service: service)))));
    await tester.pumpAndSettle();
    expect(find.text('Confirmed violation'), findsNothing);
    service.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmed violation'), findsOneWidget);
  });
  testWidgets('evidence preview authorization failure leaves retry available',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ConductEvidencePreview(
                evidence: ConductCaseEvidence(
                    id: 'e',
                    originalName: 'image.png',
                    caption: 'Preserved caption',
                    createdAt: DateTime(2026)),
                service: Investigation()))));
    await tester.tap(find.text('Preview image'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Unable to open evidence.'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNotNull);
  });
}
