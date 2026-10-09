import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carmelitas_dormitory_system/services/curfew_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final previousHttpOverrides = HttpOverrides.current;
  late HttpServer server;
  var failure = true;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    HttpOverrides.global = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path.startsWith('/auth/')) {
        request.response.write(jsonEncode({
          'access_token': 'fixture',
          'refresh_token': 'fixture',
          'token_type': 'bearer',
          'expires_in': 3600,
          'user': {
            'id': '00000000-0000-0000-0000-000000000001',
            'aud': 'authenticated',
            'role': 'authenticated',
            'email': 'fixture@example.test',
            'app_metadata': {},
            'user_metadata': {},
            'created_at': '2026-10-09T00:00:00Z'
          }
        }));
      } else if (failure) {
        request.response.statusCode = 403;
        request.response.write(jsonEncode({
          'code': '42501',
          'message': 'Fixture access denied',
          'details': null,
          'hint': null
        }));
      } else {
        request.response.write('[]');
      }
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
        .signInWithPassword(email: 'fixture@example.test', password: 'fixture');
  });
  tearDownAll(() async {
    await Supabase.instance.dispose();
    await server.close(force: true);
    HttpOverrides.global = previousHttpOverrides;
  });
  for (final entry in {
    'tenant': () => const CurfewService().listOwnRequests(),
    'staff': () => const CurfewService().listStaffRequests(),
    'guardian': () => const CurfewService().listGuardianRequests(),
  }.entries) {
    test(
        '${entry.key}: backend failure propagates; empty success remains valid',
        () async {
      failure = true;
      await expectLater(entry.value(), throwsA(isA<PostgrestException>()));
      failure = false;
      expect(await entry.value(), isEmpty);
    });
  }
}
