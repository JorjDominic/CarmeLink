import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 5 persistent staff sidebar contract', () {
    test('disclosure state belongs to the persistent shell and starts closed',
        () {
      final source =
          File('lib/core/widgets/adaptive_shell.dart').readAsStringSync();

      expect(
          source.contains('final Set<String> _expandedWebGroups = <String>{};'),
          isTrue);
      expect(source.contains('void _toggleWebGroup(String group)'), isTrue);
      expect(source.contains('expandedGroups: _expandedWebGroups'), isTrue);
      expect(source.contains('onGroupToggle: _toggleWebGroup'), isTrue);
      expect(source.contains('_expandedWebGroups.addAll'), isFalse);
    });

    test(
        'sidebar is controlled and navigation does not recreate disclosure state',
        () {
      final source =
          File('lib/core/widgets/adaptive_shell.dart').readAsStringSync();

      expect(source.contains('class _WebStaffSidebar extends StatelessWidget'),
          isTrue);
      expect(source.contains('final Set<String> expandedGroups;'), isTrue);
      expect(
          source.contains('final ValueChanged<String> onGroupToggle;'), isTrue);
      expect(source.contains('expandedGroups.contains(entry.key)'), isTrue);
      expect(source.contains('onTap: () => onGroupToggle(entry.key)'), isTrue);
      expect(source.contains("PageStorageKey<String>('web-staff-navigation')"),
          isTrue);
    });

    test(
        'role changes reset disclosure while page selection keeps its group open',
        () {
      final source =
          File('lib/core/widgets/adaptive_shell.dart').readAsStringSync();

      expect(
          source.contains('oldWidget.roleLabel != widget.roleLabel'), isTrue);
      expect(source.contains('_expandedWebGroups.clear();'), isTrue);
      final selectStart = source.indexOf('void _select(int value)');
      final selectEnd = source.indexOf('void _selectByLabel', selectStart);
      final selectBody = source.substring(selectStart, selectEnd);
      expect(selectBody.contains('final selectedGroup ='), isTrue);
      expect(selectBody.contains('_expandedWebGroups'), isTrue);
      expect(selectBody.contains('..clear()'), isTrue);
      expect(selectBody.contains('..add(selectedGroup)'), isTrue);
    });
  });
}
