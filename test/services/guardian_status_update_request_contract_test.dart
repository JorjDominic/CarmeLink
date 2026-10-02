import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('guardian presence requests are linked, audited, and rate limited', () {
    final migration = File(
      'supabase/migrations/202610020003_guardian_status_update_requests.sql',
    ).readAsStringSync();

    expect(migration, contains('guardian_tenant_links'));
    expect(migration, contains("interval '30 minutes'"));
    expect(migration, contains('>= 5'));
    expect(migration, contains('pg_advisory_xact_lock'));
    expect(migration, contains('requested_at'));
  });

  test('tenant reminder uses fixed server-authored copy and an in-app record',
      () {
    final function = File(
      'supabase/functions/request-tenant-status-update/index.ts',
    ).readAsStringSync();

    expect(function, contains("'request_tenant_status_update'"));
    expect(function, contains("const title = 'Presence update requested'"));
    expect(function, contains(".from('app_notifications').insert"));
    expect(function, isNot(contains('input?.title')));
    expect(function, isNot(contains('input?.body')));
  });
}
