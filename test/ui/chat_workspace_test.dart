import 'package:carmelitas_dormitory_system/controllers/messaging_controller.dart';
import 'package:carmelitas_dormitory_system/core/widgets/common_widgets.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/views/owner/owner_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Routes extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
    super.didPush(route, previousRoute);
  }
}

void main() {
  for (final width in [390.0, 1280.0, 1600.0]) {
    testWidgets('chat selection and cleanup at $width', (tester) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final messaging = MessagingController.instance;
      messaging.clear();
      addTearDown(messaging.clear);
      final routes = _Routes();
      await tester.pumpWidget(MaterialApp(
          navigatorObservers: [routes], home: const OwnerMessagingPage()));
      await tester.pumpAndSettle();
      messaging.setConversationsForTesting([
        for (final id in ['one', 'two'])
          ConversationRecord(
              id: id,
              type: 'tenant_management',
              title: 'Tenant $id',
              subtitle: 'Tenant',
              createdAt: DateTime(2026, 10, 18),
              updatedAt: DateTime(2026, 10, 18)),
      ]);
      await tester.pumpAndSettle();
      final originalPushes = routes.pushes;
      final first = find.widgetWithText(ConversationListCard, 'Tenant one');
      await tester.ensureVisible(first);
      await tester.tap(first);
      await tester.pumpAndSettle();
      expect(messaging.activeConversation?.id, 'one');
      expect(tester.takeException(), isNull);
      if (width >= 1280) {
        expect(routes.pushes, originalPushes);
        expect(
            tester
                .widget<OwnerConversationPage>(
                    find.byType(OwnerConversationPage))
                .embedded,
            isTrue);
        final search = find.byWidgetPredicate((w) =>
            w is TextField &&
            w.decoration?.hintText == 'Search by resident name or room...');
        expect(
            tester.getTopLeft(search).dx,
            greaterThan(tester
                .getTopLeft(find.byKey(const Key('conversation-thread-panel')))
                .dx));
        final second = find.widgetWithText(ConversationListCard, 'Tenant two');
        await tester.ensureVisible(second);
        await tester.tap(second);
        await tester.pumpAndSettle();
        expect(messaging.activeConversation?.id, 'two');
        expect(routes.pushes, originalPushes);
        expect(tester.widget<ConversationListCard>(second).selected, isTrue);
        await tester.enterText(search, 'one');
        await tester.pumpAndSettle();
        expect(messaging.activeConversation?.id, 'two');
        expect(find.widgetWithText(ConversationListCard, 'Tenant two'),
            findsNothing);
      } else {
        expect(routes.pushes, originalPushes + 1);
        expect(
            tester
                .widget<OwnerConversationPage>(
                    find.byType(OwnerConversationPage))
                .embedded,
            isFalse);
        Navigator.of(tester.element(find.byType(OwnerConversationPage))).pop();
        await tester.pumpAndSettle();
        expect(find.byType(OwnerMessagingPage), findsOneWidget);
        expect(messaging.activeConversation, isNull);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();
      expect(messaging.activeConversation, isNull);
      expect(tester.takeException(), isNull);
    });
  }
}
