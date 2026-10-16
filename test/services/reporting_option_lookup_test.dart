import 'dart:convert';
import 'dart:io';

import 'package:carmelitas_dormitory_system/services/dormitory_configuration_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Local HTTP protocol fixture. Database semantics/RLS are tested by the SQL runner.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HttpServer server;
  final previousOverrides = HttpOverrides.current;
  final patterns = <String>[];
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    HttpOverrides.global = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      final pattern = request.uri.queryParameters['label'];
      if (pattern != null) patterns.add(pattern);
      // Like PostgreSQL, unescaped wildcards would select the wrong first row.
      final literal = pattern == r'ilike.100\% repair\_type\\name';
      request.response.write(jsonEncode(pattern == 'ilike.Missing'
          ? []
          : [
              {
                'id': literal ? 'exact-category' : 'wrong-category',
                'label': r'100% repair_type\name'
              }
            ]));
      await request.response.close();
    });
    await Supabase.initialize(
      url: 'http://127.0.0.1:${server.port}',
      publishableKey: 'local-fixture',
      authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: false,
          detectSessionInUri: false,
          localStorage: EmptyLocalStorage()),
    );
  });
  tearDownAll(() async {
    await Supabase.instance.dispose();
    await server.close(force: true);
    HttpOverrides.global = previousOverrides;
  });

  test(
      'literal category labels escape %, _ and backslash instead of matching another category',
      () async {
    expect(
        await const DormitoryConfigurationService()
            .activeOptionId('maintenance_category', r' 100% repair_type\name '),
        'exact-category');
    expect(patterns.last, r'ilike.100\% repair\_type\\name');
  });
  test('missing or blank category does not resolve to a fallback option',
      () async {
    expect(
        await const DormitoryConfigurationService()
            .activeOptionId('maintenance_category', 'Missing'),
        isNull);
    final count = patterns.length;
    expect(
        await const DormitoryConfigurationService()
            .activeOptionId('maintenance_category', ' '),
        isNull);
    expect(patterns.length, count);
  });
}
