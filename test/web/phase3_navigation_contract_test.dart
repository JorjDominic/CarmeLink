import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 3 staff web navigation contract', () {
    test('desktop sidebar is persistent, grouped and expandable', () {
      final source =
          File('lib/core/widgets/adaptive_shell.dart').readAsStringSync();

      expect(source.contains("Key('web-staff-sidebar')"), isTrue);
      expect(
        source.contains('class _WebStaffSidebar extends StatelessWidget'),
        isTrue,
      );
      expect(source.contains('_expandedWebGroups'), isTrue);
      expect(source.contains('web-staff-group-'), isTrue);
      expect(source.contains('_groupKey(entry.key)'), isTrue);
      expect(source.contains('Icons.keyboard_arrow_down_rounded'), isTrue);
      expect(source.contains('_expandedWebGroups.remove(group)'), isTrue);
      expect(source.contains('_expandedWebGroups.add(group)'), isTrue);
      expect(source.contains('MANAGEMENT AREAS'), isTrue);
    });

    test('workspace chrome exposes active parent and page context', () {
      final source =
          File('lib/core/widgets/adaptive_shell.dart').readAsStringSync();

      expect(source.contains('class _WebWorkspaceContextBar'), isTrue);
      expect(source.contains("Key('web-workspace-context-bar')"), isTrue);
      expect(source.contains('destination.webGroup'), isTrue);
      expect(source.contains('_workspaceLabelOverride'), isTrue);
      expect(source.contains('_workspaceGroupOverride'), isTrue);
    });

    test(
      'dashboard quick actions select sidebar destinations instead of stacking pages',
      () {
        final adaptive =
            File('lib/core/widgets/adaptive_shell.dart').readAsStringSync();
        final overview =
            File('lib/web/dashboard/staff_overview_page.dart').readAsStringSync();

        expect(adaptive.contains('selectLabel'), isTrue);
        expect(adaptive.contains('void _selectByLabel(String label)'), isTrue);
        expect(overview.contains('nav.selectLabel(destinationLabel)'), isTrue);
        expect(overview.contains("destinationLabel: 'Maintenance'"), isTrue);
        expect(
          overview.contains("destinationLabel: 'Payment verification'"),
          isTrue,
        );
        expect(overview.contains("destinationLabel: 'Residents'"), isTrue);
      },
    );

    test('production staff web exposes all grouped management areas', () {
      final source = File(
        'lib/web/dashboard/staff_web_portal_shell.dart',
      ).readAsStringSync();

      for (final group in [
        'Facilities',
        'Access & Safety',
        'Billing & Records',
        'Communication',
        'Administration',
      ]) {
        expect(source.contains("webGroup: '$group'"), isTrue, reason: group);
      }

      for (final tool in [
        'Rooms',
        'Maintenance',
        'Cleaning schedules',
        'Room inspections',
        'Visitors',
        'Presence & Curfew',
        'Employee curfew',
        'Conduct & Cases',
        'Payment verification',
        'Report management',
        'Announcements',
        'Accounts',
        'Security & retention',
      ]) {
        expect(source.contains("label: '$tool'"), isTrue, reason: tool);
      }
    });

    test('Phase 3 leaves the mobile floating navigation path intact', () {
      final source =
          File('lib/core/widgets/adaptive_shell.dart').readAsStringSync();
      expect(source.contains('_FloatingIslandNavigation('), isTrue);
      expect(source.contains('extendBody: !webPortal'), isTrue);
      expect(source.contains(': Stack('), isTrue);
    });
  });
}
