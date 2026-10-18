import 'package:carmelitas_dormitory_system/core/widgets/workspace_columns.dart';
import 'package:carmelitas_dormitory_system/views/tenant/onboarding_form_page.dart';
import 'package:carmelitas_dormitory_system/views/shared/notification_destination.dart';
import 'package:carmelitas_dormitory_system/services/app_notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/controllers/messaging_controller.dart';
import 'package:carmelitas_dormitory_system/controllers/owner_controller.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/views/owner/owner_pages.dart';

void main() {
  for (final width in [320.0, 360.0, 390.0, 768.0, 1280.0, 1600.0]) {
    testWidgets('actual inbox and analytics composition at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final messages = MessagingController.instance;
      messages.clear();
      OwnerController.instance.clear();
      addTearDown(messages.clear);
      addTearDown(OwnerController.instance.clear);
      await tester.pumpWidget(const MaterialApp(home: OwnerMessagingPage()));
      await tester.pumpAndSettle();
      messages.setConversationsForTesting([
        ConversationRecord(
            id: 't',
            type: 'tenant_management',
            title: 'Long resident participant name for existing inbox',
            subtitle: 'Tenant',
            createdAt: DateTime(2026, 10, 18),
            updatedAt: DateTime(2026, 10, 18),
            unreadCount: 3),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Long resident participant name for existing inbox'),
          findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      await tester.enterText(
          find.byWidgetPredicate((widget) =>
              widget is TextField &&
              widget.decoration?.hintText ==
                  'Search by resident name or room...'),
          'resident');
      await tester.pumpAndSettle();
      expect(messages.searchQuery, 'resident');
      expect(find.text('Long resident participant name for existing inbox'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const MaterialApp(home: ReportsAnalyticsPage()));
      await tester.pumpAndSettle();
      expect(find.text('Operational snapshot'), findsOneWidget);
      expect(find.text('Bed Occupancy'), findsOneWidget);
      expect(find.text('Official PDF Reports & Data Exports'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    for (final scale in [1.0, 1.6]) {
      testWidgets('workspace preserves both panes and action at $width/$scale',
          (tester) async {
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var taps = 0;
        await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: Scaffold(
              body: SingleChildScrollView(
                  child: Padding(
            padding: const EdgeInsets.all(16),
            child: WorkspaceColumns(
              aside: const Text('Contacts and existing filters'),
              content: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const OnboardingProgress(step: 1),
                    FilledButton(
                        onPressed: () => taps++,
                        child: const Text('Existing action')),
                  ]),
            ),
          ))),
        ));
        final aside =
            tester.getTopLeft(find.text('Contacts and existing filters'));
        final content = tester.getTopLeft(find.byType(OnboardingProgress));
        if (width >= 1280 && scale == 1) {
          expect(content.dx, greaterThan(aside.dx));
          expect(content.dy, aside.dy);
        } else {
          expect(content.dy, greaterThan(aside.dy));
        }
        expect(find.text('2. Academic details'), findsOneWidget);
        expect(find.text('3. Emergency contact'), findsOneWidget);
        await tester.ensureVisible(find.text('Existing action'));
        await tester.tap(find.text('Existing action'));
        expect(taps, 1);
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets('notification preview retains full content at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final notice = AppNotificationItem(
          id: 'n',
          recipientId: 'u',
          notificationType: 'system',
          title: 'Important existing notice with a long title',
          body: 'Full original notification body\n${'Details ' * 30}',
          createdAt: DateTime(2026, 10, 18));
      await tester.pumpWidget(
          MaterialApp(home: NotificationDetailsPage(notification: notice)));
      await tester.pumpAndSettle();
      expect(find.text('Unread'), findsOneWidget);
      expect(find.byType(SelectableText), findsOneWidget);
      expect(find.text(notice.body), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
