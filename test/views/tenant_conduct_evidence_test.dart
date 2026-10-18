import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carmelitas_dormitory_system/services/tenant_conduct_evidence_service.dart';
import 'package:carmelitas_dormitory_system/views/shared/tenant_conduct_evidence.dart';

final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=');

class Evidence extends TenantConductEvidenceService {
  bool fail = true, reject = false;
  final attempts = <Map<String, dynamic>>[];
  final cleaned = <String>[];
  @override
  Future<TenantEvidenceDraft?> pickPhoto() async =>
      TenantEvidenceDraft(name: 'photo.png', bytes: png, mime: 'image/png');
  @override
  Future<String> upload(
          String caseId, String request, TenantEvidenceDraft photo) async =>
      photo.uploadedPath ??= 'tenant/$caseId/$request/${photo.fileId}.png';
  @override
  Future<void> submit(
      {required String id,
      required String caseId,
      required String kind,
      required String statement,
      required String support,
      required List<Map<String, dynamic>> photos}) async {
    attempts.add({
      'id': id,
      'case': caseId,
      'kind': kind,
      'statement': statement,
      'support': support,
      'photos': photos
    });
    if (reject)
      throw const PostgrestException(message: 'Closed case', code: 'P0001');
    if (fail) {
      fail = false;
      throw StateError('Lost reply');
    }
  }

  @override
  Future<void> cleanup(String path) async {
    cleaned.add(path);
  }

  @override
  Future<List<Map<String, dynamic>>> list(
          {required String caseId,
          String? responseId,
          String? appealId}) async =>
      [
        {
          'storage_path': 'private/path',
          'caption': 'My photo context',
          'original_name': 'photo.png',
          'created_at': '2026-10-18'
        }
      ];
}

void main() {
  test('only supported photo signatures are accepted', () {
    expect(TenantConductEvidenceService.imageMime(png), 'image/png');
    expect(
        () => TenantConductEvidenceService.imageMime(
            Uint8List.fromList([1, 2, 3])),
        throwsArgumentError);
  });
  for (final width in [320.0, 1280.0]) {
    for (final appeal in [false, true]) {
      testWidgets(
          'evidence preview removal and immutable retry for appeal=$appeal at $width',
          (tester) async {
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final service = Evidence();
        await tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: TenantConductSubmissionDialog(
                    caseId: 'case', appeal: appeal, service: service))));
        await tester.enterText(find.byType(TextField).first,
            'My detailed explanation and supporting evidence');
        await tester.tap(find.text('Attach evidence photo'));
        await tester.pumpAndSettle();
        expect(find.byType(Image), findsOneWidget);
        await tester.ensureVisible(find.text('Remove photo'));
        await tester.tap(find.text('Remove photo'));
        await tester.pumpAndSettle();
        expect(find.byType(Image), findsNothing);
        await tester.tap(find.text('Attach evidence photo'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField), 'Photo context');
        final submit = find.widgetWithText(
            FilledButton, appeal ? 'Submit appeal' : 'Submit response');
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(find.byType(TextField).first).enabled,
            false);
        await tester.tap(find.text('Retry submission'));
        await tester.pumpAndSettle();
        expect(service.attempts.length, 2);
        expect(service.attempts[0], service.attempts[1]);
        expect((service.attempts.first['photos'] as List).single['caption'],
            'Photo context');
        expect(service.cleaned, isEmpty);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('confirmed database rejection allows correction', (tester) async {
    final service = Evidence()..reject = true;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: TenantConductSubmissionDialog(
                caseId: 'case', appeal: false, service: service))));
    await tester.enterText(find.byType(TextField), 'My explanation');
    await tester.tap(find.widgetWithText(FilledButton, 'Submit response'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, true);
    expect(find.textContaining('Submission was not saved'), findsOneWidget);
  });
  testWidgets('tenant evidence metadata is shown beside its parent submission',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: TenantConductEvidencePanel(
                caseId: 'case', responseId: 'response', service: Evidence()))));
    await tester.pumpAndSettle();
    expect(find.text('My photo context'), findsOneWidget);
    expect(find.textContaining('Tenant evidence'), findsOneWidget);
  });
}
