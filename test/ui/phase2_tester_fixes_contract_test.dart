import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 2 tester-visible fixes contract', () {
    test('maintenance cancellation is status based and preserves history', () {
      final tenant =
          File('lib/views/tenant/tenant_pages.dart').readAsStringSync();
      final controller =
          File('lib/controllers/tenant_controller.dart').readAsStringSync();
      final service =
          File('lib/services/maintenance_service.dart').readAsStringSync();
      final migration = File(
        'supabase/migrations/202609281731_phase2_notifications_and_maintenance.sql',
      ).readAsStringSync();

      expect(
          tenant.contains('controller.cancelMaintenance(report.id)'), isTrue);
      expect(
          controller.contains('_maintenanceService.cancelReport(id)'), isTrue);
      expect(service.contains("rpc(\n      'cancel_my_maintenance_report'"),
          isTrue);
      expect(migration.contains('cancel_my_maintenance_report'), isTrue);
      expect(migration.contains("status = 'cancelled'"), isTrue);
    });

    test('maintenance room selector no longer exposes the map shortcut', () {
      final tenant =
          File('lib/views/tenant/tenant_pages.dart').readAsStringSync();
      expect(tenant.contains("tooltip: 'Pick on floor plan'"), isFalse);
      expect(tenant.contains("labelText: 'Room / area'"), isTrue);
      expect(
          tenant.contains('Choose the closest room or common area.'), isTrue);
    });

    test(
        'pinned announcements move into needs-your-attention without duplicate section',
        () {
      final tenant =
          File('lib/views/tenant/tenant_pages.dart').readAsStringSync();
      expect(tenant.contains('items.where((item) => item.isPinned).toList()'),
          isTrue);
      expect(tenant.contains("'Latest announcement'"), isFalse);
      expect(tenant.contains("'Needs your attention'"), isTrue);
    });

    test('bed labels are normalized instead of being prefixed twice', () {
      for (final path in [
        'lib/views/tenant/tenant_pages.dart',
        'lib/views/owner/owner_pages.dart',
        'lib/views/guardian/guardian_pages.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('Bed Bed'), isFalse, reason: path);
      }
      final profile =
          File('lib/services/profile_service.dart').readAsStringSync();
      expect(profile.contains("startsWith('bed ')"), isTrue);
      expect(profile.contains("• Bed \${bed?['label']"), isFalse);
    });

    test('shared cards provide a Material surface for ListTile ink', () {
      final common =
          File('lib/core/widgets/common_widgets.dart').readAsStringSync();
      expect(common.contains('type: MaterialType.transparency'), isTrue);
    });
  });
}
