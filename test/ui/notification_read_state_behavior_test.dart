import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carmelitas_dormitory_system/services/app_notification_service.dart';
import 'package:carmelitas_dormitory_system/views/shared/shared_views.dart';

AppNotificationItem notice(String id, {bool read = false}) =>
    AppNotificationItem(
      id: id,
      recipientId: 'user',
      notificationType: 'system',
      title: 'Notice $id',
      body: 'Update',
      createdAt: DateTime(2026, 10, 9),
      readAt: read ? DateTime(2026, 10, 9) : null,
    );

class _Inbox extends AppNotificationService {
  _Inbox()
      : super.withClient(SupabaseClient('http://localhost', 'fixture',
            authOptions: const AuthClientOptions(autoRefreshToken: false)));
  final snapshots = StreamController<List<AppNotificationItem>>.broadcast();
  final save = Completer<bool>();
  List<AppNotificationItem> page = [notice('one')];
  int unread = 1;
  int saves = 0;
  @override
  Future<void> cleanupExpiredNotifications() async {}
  @override
  Future<List<AppNotificationItem>> fetchMyNotificationsPage(
          {int limit = 15, DateTime? before, String? beforeId}) async =>
      page;
  @override
  Stream<List<AppNotificationItem>> streamMyNotifications({int limit = 30}) =>
      snapshots.stream;
  @override
  Future<int?> fetchMyUnreadCount() async => unread;
  @override
  Future<bool> tryMarkAsRead(String id) {
    saves++;
    return save.future;
  }

  @override
  Future<bool> tryMarkAllAsRead() {
    saves++;
    return save.future;
  }
}

void main() {
  testWidgets('Mark All includes unread rows outside the loaded page',
      (tester) async {
    final service = _Inbox()
      ..page = [notice('one', read: true)]
      ..unread = 7;
    addTearDown(service.snapshots.close);
    await tester
        .pumpWidget(MaterialApp(home: NotificationsPage(service: service)));
    await tester.pumpAndSettle();
    expect(find.text('7 unread updates'), findsOneWidget);
    await tester.tap(find.text('Mark all read'));
    await tester.pump();
    expect(service.saves, 1);
    service.unread = 0;
    service.save.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Mark all read'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  for (final all in [false, true]) {
    testWidgets(
        'failed ${all ? 'mark all' : 'single read'} preserves concurrent realtime rows',
        (tester) async {
      final service = _Inbox();
      addTearDown(service.snapshots.close);
      await tester
          .pumpWidget(MaterialApp(home: NotificationsPage(service: service)));
      await tester.pumpAndSettle();
      if (all) {
        await tester.tap(find.text('Mark all read'));
      } else {
        await tester.tap(find.byKey(const Key('notification-one')));
      }
      await tester.pump();
      service.unread = 2;
      service.snapshots.add([notice('two')]);
      await tester.pump();
      service.save.complete(false);
      await tester.pumpAndSettle();
      expect(find.text('Notice one'), findsOneWidget);
      expect(find.text('Notice two'), findsOneWidget);
      expect(find.text('2 unread updates'), findsOneWidget);
      expect(find.textContaining('Could not mark'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
      'successful read publishes a post-save snapshot for badge refresh',
      (tester) async {
    final service = _Inbox();
    addTearDown(service.snapshots.close);
    final states = <List<AppNotificationItem>>[];
    await tester.pumpWidget(MaterialApp(
        home: NotificationsPage(
            service: service, onNotificationsChanged: states.add)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('notification-one')));
    await tester.pump();
    final optimisticSnapshots = states.length;
    service.unread = 0;
    service.save.complete(true);
    await tester.pumpAndSettle();
    expect(states.length, greaterThan(optimisticSnapshots));
    expect(states.last.single.isRead, isTrue);
    expect(find.text('You are all caught up'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
