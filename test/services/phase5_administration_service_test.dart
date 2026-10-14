// Protocol checks against a loopback fixture. Backend permissions are tested
// separately by tool/test_phase5_report_conduct.mjs.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carmelitas_dormitory_system/services/conduct_case_service.dart';
import 'package:carmelitas_dormitory_system/services/confidential_report_service.dart';
import 'package:carmelitas_dormitory_system/services/report_administration_service.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final previousOverrides = HttpOverrides.current;
  late HttpServer server;
  final requests = <({String path, Map<String, dynamic> body, Uri uri})>[];
  var fail = false;
  const userId = '00000000-0000-0000-0000-000000000001';
  final date = DateTime.utc(2026, 10, 14);
  final record = ConductCaseRecord(
      id: 'case',
      category: 'rule_violation',
      title: 'Case title',
      description: 'Case description',
      incidentAt: date,
      status: 'under_review',
      createdAt: date,
      updatedAt: date);
  String token(Map<String, dynamic> payload) =>
      base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll('=', '');
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    HttpOverrides.global = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final path = request.uri.path.split('/').last;
      final raw = await utf8.decoder.bind(request).join();
      final body = raw.isEmpty
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(jsonDecode(raw) as Map);
      requests.add((path: path, body: body, uri: request.uri));
      request.response.headers.contentType = ContentType.json;
      Object? result;
      if (path == 'token') {
        final expires = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
        result = {
          'access_token': '${token({'alg': 'HS256', 'typ': 'JWT'})}.${token({
                'sub': userId,
                'role': 'authenticated',
                'exp': expires
              })}.fixture',
          'refresh_token': 'fixture',
          'expires_in': 3600,
          'token_type': 'bearer',
          'user': {
            'id': userId,
            'aud': 'authenticated',
            'role': 'authenticated',
            'email': 'phase5@example.test',
            'created_at': date.toIso8601String(),
            'app_metadata': {},
            'user_metadata': {}
          }
        };
      } else if (fail) {
        request.response.statusCode = 400;
        result = {
          'code': '40001',
          'message': 'This case changed. Refresh before continuing.'
        };
      } else if (path == 'get_my_conduct_official_responses') {
        result = [
          {
            'id': 'entry',
            'body': 'Official reply',
            'actor_name': 'Owner',
            'actor_role': 'owner',
            'created_at': date.toIso8601String()
          }
        ];
      } else if (path == 'conduct_case_events') {
        result = [
          {
            'id': 'entry',
            'notes': 'Internal instructions',
            'actor_name': 'Caretaker',
            'actor_role': 'caretaker',
            'visibility': 'internal',
            'created_at': date.toIso8601String()
          }
        ];
      } else if (path == 'review_confidential_report_guarded') {
        result = {
          'id': 'report',
          'summary': 'Original report details',
          'category': 'other',
          'status': body['p_status'],
          'response_notes': body['p_notes'],
          'created_at': date.toIso8601String(),
          'updated_at': '2026-10-14T01:00:00Z'
        };
      } else if (path == 'add_conduct_official_response') {
        result = 'entry';
      }
      request.response.write(jsonEncode(result));
      await request.response.close();
    });
    await Supabase.initialize(
        url: 'http://127.0.0.1:${server.port}',
        publishableKey: 'fixture',
        authOptions: FlutterAuthClientOptions(
            autoRefreshToken: false,
            detectSessionInUri: false,
            localStorage: EmptyLocalStorage()));
    await Supabase.instance.client.auth
        .signInWithPassword(email: 'phase5@example.test', password: 'fixture');
  });
  setUp(() {
    requests.clear();
    fail = false;
  });
  tearDownAll(() async {
    await Supabase.instance.dispose();
    await server.close(force: true);
    HttpOverrides.global = previousOverrides;
  });
  test('tenant response reader uses only the restricted own-case RPC',
      () async {
    final entries = await const ConductCaseService()
        .listOfficialResponses('case', staffMode: false);
    expect(entries.single.body, 'Official reply');
    expect(entries.single.visibility, 'tenant');
    expect(requests.single.path, 'get_my_conduct_official_responses');
    expect(requests.single.body, {'p_case_id': 'case'});
  });
  test(
      'staff reads official entries from existing case history with visibility',
      () async {
    final entries = await const ConductCaseService()
        .listOfficialResponses('case', staffMode: true);
    expect(entries.single.visibility, 'internal');
    expect(entries.single.authorRole, 'caretaker');
    expect(requests.single.path, 'conduct_case_events');
    expect(requests.single.uri.queryParameters['case_id'], 'eq.case');
    expect(requests.single.uri.queryParameters['event_type'],
        'eq.official_response');
  });
  test(
      'official save sends immutable case version and stable key without separate notifications or status writes',
      () async {
    await const ConductCaseService().addOfficialResponse(
        record: record,
        body: ' Official reply ',
        visibility: 'tenant',
        requestId: 'request-key');
    expect(requests, hasLength(1));
    expect(requests.single.path, 'add_conduct_official_response');
    expect(requests.single.body, {
      'p_case_id': 'case',
      'p_expected_updated_at': date.toIso8601String(),
      'p_body': 'Official reply',
      'p_visibility': 'tenant',
      'p_request_id': 'request-key'
    });
  });
  test('failed official save propagates failure without follow-up mutations',
      () async {
    fail = true;
    await expectLater(
        const ConductCaseService().addOfficialResponse(
            record: record,
            body: 'Official reply',
            visibility: 'tenant',
            requestId: 'key'),
        throwsA(isA<PostgrestException>()));
    expect(requests, hasLength(1));
  });
  test(
      'confidential review sends original version and retains original configured label and concern',
      () async {
    final original = ConcernReport(
        id: 'report',
        category: 'Custom safety concern',
        specificConcern: 'Preserved concern',
        summary: 'Original report details',
        status: 'Submitted',
        createdAt: date,
        updatedAt: '2026-10-14T00:00:00.123456Z');
    final saved = await const ConfidentialReportService().review(
        reportId: 'report',
        status: 'under_review',
        notes: ' Review started ',
        originalReport: original);
    expect(requests.single.path, 'review_confidential_report_guarded');
    expect(requests.single.body['p_expected_updated_at'], original.updatedAt);
    expect(saved.category, original.category);
    expect(saved.specificConcern, original.specificConcern);
    expect(saved.updatedAt, '2026-10-14T01:00:00Z');
    expect(saved.status, 'Under Review');
  });
  test(
      'internal report note uses history RPC without writing tenant-visible fields',
      () async {
    await const ReportAdministrationService().addInternalNote(
        'confidential', 'report', ' Private instructions ', 'key');
    expect(requests.single.path, 'append_report_internal_note');
    expect(requests.single.body, {
      'p_report_type': 'confidential',
      'p_report_id': 'report',
      'p_body': 'Private instructions',
      'p_request_id': 'key'
    });
  });
}
