import 'package:carmelitas_dormitory_system/core/widgets/common_widgets.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage message({DateTime? readAt}) => ChatMessage(
      id: 'message',
      senderName: 'Owner',
      senderRole: 'owner',
      body: 'Hello',
      sentAt: DateTime(2026, 9, 19, 10, 30),
      isRead: readAt != null,
      readAt: readAt,
    );

void main() {
  testWidgets('shows Sent for an outgoing unread message', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MessageDeliveryMeta(message: message(), isMine: true),
      ),
    ));

    expect(find.text('Sent'), findsOneWidget);
    expect(find.byIcon(Icons.done_rounded), findsOneWidget);
  });

  testWidgets('shows Read for an outgoing read message', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MessageDeliveryMeta(
          message: message(readAt: DateTime(2026, 9, 19, 10, 35)),
          isMine: true,
        ),
      ),
    ));

    expect(find.text('Read'), findsOneWidget);
    expect(find.byIcon(Icons.done_all_rounded), findsOneWidget);
  });

  testWidgets('does not show a receipt on incoming messages', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MessageDeliveryMeta(
          message: message(readAt: DateTime(2026, 9, 19, 10, 35)),
          isMine: false,
        ),
      ),
    ));

    expect(find.text('Read'), findsNothing);
    expect(find.text('Sent'), findsNothing);
  });
}
