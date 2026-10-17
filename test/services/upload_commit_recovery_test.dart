import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/services/contract_document_service.dart';
import 'package:carmelitas_dormitory_system/services/maintenance_service.dart';
import 'package:carmelitas_dormitory_system/services/payment_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final previousOverrides = HttpOverrides.current;
  late HttpServer server;
  const userId = '00000000-0000-0000-0000-000000000001';
  final files = <String>{};
  final documents = <Map<String, dynamic>>[];
  Map<String, dynamic>? savedPayment;
  late Map<String, dynamic> report;
  var deletedReports = 0;
  var writeAttempts = 0;
  var mode = 'truncated';
  String token(Map<String, dynamic> row) =>
      base64Url.encode(utf8.encode(jsonEncode(row))).replaceAll('=', '');
  final contract = TenantContract.fromRow({
    'id': 'contract',
    'tenant_id': userId,
    'contract_number': 'QA-001',
    'starts_on': '2026-10-17',
    'ends_on': '2027-10-16',
    'monthly_rent': 2500,
    'security_deposit': 2500,
    'status': 'draft',
    'created_at': '2026-10-17T00:00:00Z',
    'updated_at': '2026-10-17T00:00:00Z',
    'occupancy_snapshot': {
      'room_number': '101',
      'mode': 'solo',
      'members': [
        {
          'tenant_id': userId,
          'name': 'QA Tenant',
          'bed_label': 'Bed 1',
          'rent_cents': 250000
        }
      ],
      'total_rent_cents': 250000
    },
  });

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    HttpOverrides.global = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final path = request.uri.pathSegments.last;
      final jsonBody =
          request.headers.contentType?.mimeType == 'application/json';
      final payload = await request
          .fold<List<int>>([], (bytes, chunk) => bytes..addAll(chunk));
      final raw = jsonBody ? utf8.decode(payload) : '';
      final body = raw.isNotEmpty && jsonBody
          ? jsonDecode(raw) as Map<String, dynamic>
          : <String, dynamic>{};
      request.response.headers.contentType = ContentType.json;
      Object result = [];
      var databaseWrite = false;
      if (path == 'token') {
        result = {
          'access_token': '${token({'alg': 'HS256'})}.${token({
                'sub': userId,
                'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
                'role': 'authenticated'
              })}.fixture',
          'refresh_token': 'fixture',
          'expires_in': 3600,
          'token_type': 'bearer',
          'user': {
            'id': userId,
            'aud': 'authenticated',
            'role': 'authenticated',
            'email': 'qa@example.test',
            'created_at': '2026-10-17T00:00:00Z',
            'app_metadata': {},
            'user_metadata': {}
          }
        };
      } else if (path == 'cloudinary-media-upload') {
        final reference =
            'cloudinary://authenticated/$userId/${body['kind']}/${body['record_id']}/proof.png';
        files.add(reference);
        result = {'reference': reference};
      } else if (path == 'cloudinary-media-delete') {
        files.remove(body['reference']);
        result = {'deleted': true};
      } else if (request.uri.path.contains('/storage/v1/object/')) {
        if (request.method == 'DELETE') {
          for (final prefix in body['prefixes'] as List) {
            files.remove(prefix);
          }
        } else {
          files.add(request.uri.path.split('/contract-documents/').last);
        }
        result = {'Key': request.uri.path};
      } else if (path == 'contract_documents') {
        if (request.method == 'POST') {
          databaseWrite = true;
          if (mode != 'rejected')
            documents.add({
              ...body,
              'id': 'document',
              'uploaded_at': '2026-10-17T00:00:00Z'
            });
        }
        result = documents;
      } else if (path == 'submit_payment_transaction' ||
          path == 'record_staff_payment') {
        databaseWrite = true;
        if (mode != 'rejected') savedPayment = Map.of(body);
      } else if (path == 'dormitory_options') {
        result = [
          {
            'id': 'option',
            'group_key': 'maintenance_category',
            'code': 'plumbing',
            'label': 'Plumbing',
            'is_active': true,
            'is_system': true,
            'sort_order': 0
          }
        ];
      } else if (path == 'maintenance_reports') {
        if (request.method == 'PATCH') {
          databaseWrite = true;
          if (mode != 'rejected') report.addAll(body);
        } else if (request.method == 'DELETE') {
          deletedReports++;
        }
        result = report;
      }
      if (databaseWrite) {
        writeAttempts++;
        if (mode == 'truncated') {
          request.response.write('{"id":');
          await request.response.close();
          return;
        }
        request.response.statusCode = mode == 'rejected' ? 400 : 503;
        result = {
          'code': mode == 'rejected' ? 'P0001' : '503',
          'message': mode == 'rejected'
              ? 'Write rejected'
              : 'Upstream response unavailable'
        };
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
        .signInWithPassword(email: 'qa@example.test', password: 'fixture');
  });
  setUp(() {
    files.clear();
    documents.clear();
    savedPayment = null;
    deletedReports = 0;
    writeAttempts = 0;
    report = {
      'id': 'report',
      'tenant_id': userId,
      'category': 'plumbing',
      'category_option_id': 'option',
      'description': 'Leaking faucet',
      'location': 'Room 101',
      'urgency': 'normal',
      'status': 'pending',
      'photo_path': null,
      'created_at': '2026-10-17T00:00:00Z',
      'updated_at': '2026-10-17T00:00:00Z'
    };
  });
  tearDownAll(() async {
    await Supabase.instance.dispose();
    await server.close(force: true);
    HttpOverrides.global = previousOverrides;
  });

  for (final responseMode in ['truncated', 'unavailable', 'rejected']) {
    for (final kind in [
      'generated contract',
      'signed contract',
      'tenant proof',
      'staff payment',
      'new maintenance photo',
      'replacement maintenance photo'
    ]) {
      test('$kind preserves committed evidence after $responseMode response',
          () async {
        mode = responseMode;
        final bytes = Uint8List.fromList([1, 2, 3]);
        final Future<dynamic> operation = switch (kind) {
          'generated contract' =>
            const ContractDocumentService().generateContract(contract),
          'signed contract' => const ContractDocumentService().uploadSigned(
              contract: contract,
              version: 1,
              filename: 'signed.pdf',
              mimeType: 'application/pdf',
              bytes: bytes),
          'tenant proof' => const PaymentService().submitPaymentProof(
              paymentId: 'bill',
              amount: 100,
              method: 'GCash',
              referenceNumber: 'QA-REF',
              receiptBytes: bytes,
              fileName: 'proof.png',
              mimeType: 'image/png'),
          'staff payment' => const PaymentService().recordReceivedPayment(
              requestId: 'request',
              paymentId: 'bill',
              amount: 100,
              method: 'f2f',
              receivedOn: DateTime(2026, 10, 17),
              receiptBytes: bytes,
              fileName: 'proof.png',
              mimeType: 'image/png'),
          'new maintenance photo' => const MaintenanceService().createReport(
              category: 'plumbing',
              description: 'Leaking faucet',
              location: 'Room 101',
              urgency: 'normal',
              photoBytes: bytes,
              photoFileName: 'proof.png',
              photoMimeType: 'image/png'),
          _ => const MaintenanceService().updateReport(
              id: 'report',
              category: 'plumbing',
              description: 'Leaking faucet',
              location: 'Room 101',
              urgency: 'normal',
              photoBytes: bytes,
              photoFileName: 'proof.png',
              photoMimeType: 'image/png'),
        };
        await expectLater(operation, throwsA(anything));
        expect(writeAttempts, 1);
        if (mode == 'rejected') {
          expect(files, isEmpty);
        } else {
          expect(files, hasLength(1),
              reason:
                  'The server saved a reference before its response was lost.');
          if (kind.contains('contract')) {
            final saved = (await const ContractDocumentService()
                    .listDocuments('contract'))
                .single;
            expect(files, contains(saved.storagePath));
          } else if (kind == 'tenant proof' || kind == 'staff payment') {
            expect(files, contains(savedPayment!['p_receipt_path']));
          } else {
            expect(files, contains(report['photo_path']));
            expect(deletedReports, 0);
          }
        }
      });
    }
  }
}
