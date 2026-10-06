import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('staff web navigation is wired to browser back and forward history', () {
    final shell =
        File('lib/core/widgets/adaptive_shell.dart').readAsStringSync();
    final history = File(
      'lib/services/web_browser_history_service_web.dart',
    ).readAsStringSync();
    final workspace = File(
      'lib/web/dashboard/staff_workspace_page.dart',
    ).readAsStringSync();

    expect(shell, contains('WebBrowserHistoryService.instance'));
    expect(shell, contains('_restoreBrowserHistory'));
    expect(shell, contains('_recordDestinationBrowserHistory'));
    expect(shell, contains('_recordPageBrowserHistory'));
    expect(history, contains('html.window.onPopState.listen'));
    expect(history, contains('html.window.history.pushState'));
    expect(history, contains('html.window.history.replaceState'));
    expect(history, contains("'#/staff'"));

    // Browser Back must be allowed to leave the staff route naturally once
    // the internal CarmeLink history entries are exhausted.
    expect(workspace, isNot(contains('canPop: false')));
    expect(workspace, isNot(contains('_confirmReturnToLanding')));

    // Explicit logout remains protected by confirmation.
    expect(workspace, contains("title: const Text('Logout?')"));
  });

  test('workspace history covers destinations and nested utility pages', () {
    final shell =
        File('lib/core/widgets/adaptive_shell.dart').readAsStringSync();

    expect(shell, contains('_recordDestinationBrowserHistory(value)'));
    expect(shell, contains('_openWebCommunicationPage'));
    expect(shell, contains("label: 'Notifications'"));
    expect(shell, contains("label: 'Messages'"));
    expect(shell, contains('_openWebWorkspacePage'));
    expect(shell, contains('page: page'));
  });
}
