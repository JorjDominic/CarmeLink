import 'package:carmelitas_dormitory_system/core/widgets/common_widgets.dart';
import 'package:carmelitas_dormitory_system/core/widgets/notice_content.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/controllers/owner_controller.dart';
import 'package:carmelitas_dormitory_system/views/owner/contracts_page.dart';
import 'package:carmelitas_dormitory_system/views/owner/owner_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [320.0, 390.0, 768.0, 1280.0, 1600.0]) {
    testWidgets('live contract and tenant preview wrap at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      addTearDown(OwnerController.instance.clear);
      const name = 'Resident with a long complete name and multiple surnames';
      OwnerController.instance.clear();
      OwnerController.instance.setContractsForTesting([
        TenantContract(
            id: 'c',
            tenantId: 't',
            tenantName: name,
            contractNumber: 'CTR-2026-LONG-IDENTIFIER-1234567890',
            startsOn: DateTime(2026, 1),
            endsOn: DateTime(2027, 1),
            monthlyRent: 123456.78,
            securityDeposit: 123456.78,
            status: 'active',
            createdAt: DateTime(2026, 1),
            updatedAt: DateTime(2026, 1)),
      ]);
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!),
        home: const ContractsPage(),
      ));
      await tester.pumpAndSettle();
      expect(find.text(name), findsOneWidget);
      expect(find.text('Documents'), findsOneWidget);
      await tester.ensureVisible(find.text('Documents'));
      expect(tester.takeException(), isNull);
      var details = 0;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: Padding(
        padding: const EdgeInsets.all(16),
        child: TenantQuickPreview(
            tenant: const TenantDirectoryEntry(
                id: 't',
                name: name,
                room: 'Third floor - long room assignment',
                bedSpace: 'Bed 4',
                phone: '+639171234567',
                guardianName: 'Guardian with a long complete name and surname',
                guardianPhone: '+639171234568'),
            onFullDetails: () => details++,
            onManageAccount: () {},
            onClose: () {}),
      )))));
      await tester.pumpAndSettle();
      await tester
          .ensureVisible(find.byKey(const Key('tenant-quick-full-details')));
      await tester.tap(find.byKey(const Key('tenant-quick-full-details')));
      expect(details, 1);
      expect(tester.takeException(), isNull);
    });
  }
  for (final width in [320.0, 360.0, 390.0, 768.0, 1280.0, 1600.0]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets('conversation and notice layout at $width / $scale',
          (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var opens = 0;
        const name = 'A resident with a very long participant name and surname';
        final message = ChatMessage(
            id: 'm',
            senderName: name,
            senderRole: 'tenant',
            body: 'A long multiline message\n${'message content ' * 25}',
            sentAt: DateTime(2026, 10, 18, 12));
        await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: Scaffold(
              body: SingleChildScrollView(
                  child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              ConversationListCard(
                  name: name,
                  role: 'Guardian',
                  lastMessage: message,
                  unreadCount: 123,
                  onTap: () => opens++),
              ConversationMessageBubble(message: message, mine: true),
              ConversationMessageBubble(message: message, mine: false),
              NoticeContent(
                  title:
                      'An important notice with a long title that must remain readable',
                  body: 'Full notice content\n${'Notice details ' * 20}',
                  color: Colors.brown),
            ]),
          ))),
        ));
        await tester.tap(find.byType(ConversationListCard));
        expect(opens, 1);
        expect(find.text('123'), findsOneWidget);
        expect(find.byType(MessageDeliveryMeta), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets('composer remains usable with keyboard at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 922);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = TextEditingController(text: 'Existing message');
      addTearDown(controller.dispose);
      var sends = 0;
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(viewInsets: const EdgeInsets.only(bottom: 350)),
            child: child!),
        home: Scaffold(
            body: SingleChildScrollView(
                child: ConversationThreadPanel(
          messages: const [],
          composerController: controller,
          isMine: (_) => true,
          onSend: () async {
            sends++;
          },
        ))),
      ));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Send message'));
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      expect(sends, 1);
      expect(find.text('No messages yet.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
