import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/core/widgets/chat_workspace.dart';

void main() {
  testWidgets(
      'notification thread keeps the desktop contact list and selection',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const threadKey = ValueKey('inbox-notification');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ChatWorkspace(
          initialThread:
              const Text('Notification conversation', key: threadKey),
          contactsBuilder: (select, selectedKey) {
            expect(select, isNotNull);
            expect(selectedKey, threadKey);
            return const Text('Conversation contacts');
          },
        ),
      ),
    ));
    expect(find.text('Notification conversation'), findsOneWidget);
    expect(find.text('Conversation contacts'), findsOneWidget);
    expect(find.text('Select a conversation'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
