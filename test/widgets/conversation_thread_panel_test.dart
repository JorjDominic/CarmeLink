import 'package:carmelitas_dormitory_system/core/widgets/common_widgets.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('conversation thread stays bounded and scrolls messages internally',
      (tester) async {
    final composer = TextEditingController();
    addTearDown(composer.dispose);
    final messages = List.generate(
      30,
      (index) => ChatMessage(
        id: 'm$index',
        senderName: index.isEven ? 'Tenant' : 'Management',
        senderRole: index.isEven ? 'tenant' : 'owner',
        body: 'Message $index',
        sentAt: DateTime(2026, 9, 27, 12, index % 60),
        senderId: index.isEven ? 'tenant' : 'owner',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConversationThreadPanel(
            messages: messages,
            composerController: composer,
            isMine: (message) => message.senderId == 'owner',
            onSend: () async {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('conversation-thread-panel')), findsOneWidget);
    expect(find.byKey(const Key('conversation-message-scroll')), findsOneWidget);
    expect(find.byKey(const Key('conversation-composer')), findsOneWidget);
    expect(find.text('Message 29'), findsOneWidget);
  });
}
