import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 4 dynamic refresh contract', () {
    test('mobile role shells catch up when the app resumes', () {
      for (final path in [
        'lib/views/tenant/tenant_shell.dart',
        'lib/views/owner/owner_shell.dart',
        'lib/views/caretaker/caretaker_shell.dart',
        'lib/views/guardian/guardian_shell.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('with WidgetsBindingObserver'), isTrue,
            reason: '$path must observe lifecycle changes');
        expect(source.contains('AppLifecycleState.resumed'), isTrue,
            reason: '$path must refresh after resume');
        expect(source.contains('_refreshLiveData()'), isTrue,
            reason: '$path must use the live refresh path');
      }
    });

    test('guardian realtime refresh avoids duplicate query cascades', () {
      final source = File(
        'lib/controllers/guardian_controller.dart',
      ).readAsStringSync();
      final start = source.indexOf('void _initRealtimeSubscription()');
      final end = source.indexOf('Future<void> loadGateEvents', start);
      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));
      final block = source.substring(start, end);

      expect(block.contains('loadData(force: true);'), isTrue);
      expect(block.contains('loadCurfewRequests(force: true);'), isFalse);
      expect(block.contains('loadGateEvents(force: true);'), isFalse);
    });

    test('realtime subscriptions retain a catch-up fallback', () {
      final source = File(
        'lib/services/table_refresh_subscription.dart',
      ).readAsStringSync();

      expect(
        source.contains(
            'Duration? catchUpInterval = const Duration(seconds: 30)'),
        isTrue,
      );
      expect(source.contains('Timer.periodic('), isTrue);
    });

    test('staff web also refreshes after tab or browser resume', () {
      final source = File(
        'lib/web/dashboard/staff_web_portal_shell.dart',
      ).readAsStringSync();

      expect(source.contains('with WidgetsBindingObserver'), isTrue);
      expect(source.contains('AppLifecycleState.resumed'), isTrue);
      expect(source.contains('Duration(seconds: 60)'), isTrue);
    });
  });
}
