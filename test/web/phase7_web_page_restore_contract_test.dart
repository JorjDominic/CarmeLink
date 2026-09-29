import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web shell persists the visible page and restores it after reload', () {
    final shell =
        File('lib/core/widgets/adaptive_shell.dart').readAsStringSync();
    final service = File(
      'lib/services/web_workspace_persistence_service.dart',
    ).readAsStringSync();

    expect(shell.contains('WebWorkspacePersistenceService'), isTrue);
    expect(shell.contains('_restoreWebWorkspaceState()'), isTrue);
    expect(shell.contains('_persistWorkspaceDestination'), isTrue);
    expect(shell.contains("wanted == 'messages'"), isTrue);
    expect(shell.contains("wanted == 'notifications'"), isTrue);
    expect(shell.contains('saveExpandedGroups'), isTrue);

    expect(service.contains('baseDestinationLabel'), isTrue);
    expect(service.contains('visiblePageLabel'), isTrue);
    expect(service.contains('SharedPreferences.getInstance()'), isTrue);
  });

  test('billing center is a persistent staff destination', () {
    final source = File(
      'lib/web/dashboard/staff_web_portal_shell.dart',
    ).readAsStringSync();

    expect(source.contains("label: 'Billing & charges'"), isTrue);
    expect(source.contains('page: BillingManagementPage()'), isTrue);
    expect(source.contains("webGroup: 'Billing & Records'"), isTrue);
  });
}
