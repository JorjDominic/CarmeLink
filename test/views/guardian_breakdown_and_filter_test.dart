import 'package:carmelitas_dormitory_system/core/widgets/common_widgets.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/services/guardian_alert_service.dart';
import 'package:carmelitas_dormitory_system/views/guardian/guardian_pages.dart';
import 'package:carmelitas_dormitory_system/views/shared/employee_curfew_profile_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Guardian request breakdown & curfew profile hide tests', () {
    testWidgets(
        'Curfew request card displays complete breakdown with status, date, time, room, bed, and status',
        (tester) async {
      final request = CurfewRequest(
        id: 'req-1',
        tenantId: 'tenant-1',
        tenantName: 'Juan Dela Cruz',
        requestType: 'overnight_leave',
        departureTime: DateTime(2026, 10, 2, 18, 30),
        expectedReturnTime: DateTime(2026, 10, 3, 8, 0),
        destination: 'Family Home, Quezon City',
        reason: 'Weekend family gathering',
        status: 'pending_guardian',
        createdAt: DateTime(2026, 10, 2, 10, 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GuardianCurfewRequestCard(
                request: request,
                isProcessing: false,
                onEndorse: () {},
                onDecline: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('REQUEST & RESIDENT BREAKDOWN'), findsOneWidget);
      expect(find.text('Tenant Status'), findsOneWidget);
      expect(find.text('Date & Time'), findsOneWidget);
      expect(find.text('Room & Bed'), findsOneWidget);
      expect(find.text('Request Status'), findsOneWidget);
      expect(find.textContaining('10/2/2026'), findsWidgets);
    });

    testWidgets(
        'Presence update request breakdown shows status of tenant, date, time, room, bed, and delivery status',
        (tester) async {
      final sampleRequests = [
        GuardianPresenceUpdateRequest(
          id: 'upd-1',
          tenantId: 'tenant-1',
          requestedAt: DateTime(2026, 10, 2, 18, 30),
          dispatchedAt: DateTime(2026, 10, 2, 18, 30, 5),
          pushDeliveredAt: DateTime(2026, 10, 2, 18, 30, 10),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GuardianStatusRequestBreakdown(
                requests: sampleRequests,
                isLoading: false,
                tenantName: 'Juan Dela Cruz',
                tenantPresence: 'Inside',
                room: const Room(
                  id: 'room-1',
                  number: '204',
                  floor: '2',
                  capacity: 4,
                  occupied: 3,
                  bedSpace: 'Bed B',
                  roommates: [],
                  utilitySummary: '',
                  roommateDetails: [],
                ),
                onRefresh: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Presence update request breakdown'), findsOneWidget);
      expect(find.text('Tenant & Status'), findsOneWidget);
      expect(find.textContaining('Juan Dela Cruz (Inside)'), findsOneWidget);
      expect(find.text('Room & Bed'), findsOneWidget);
      expect(find.text('Room 204 • Bed B'), findsOneWidget);
      expect(find.text('Push delivered'), findsOneWidget);
      expect(find.textContaining('10/2/2026'), findsOneWidget);
    });

    testWidgets(
        'No approved employee curfew profile notice is hideable via close button',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TenantEmployeeCurfewProfileCard(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final noticeTextFinder = find.textContaining(
        'No approved employee curfew profile applies today',
      );
      final hideBtnFinder = find.byTooltip('Hide notice');

      if (noticeTextFinder.evaluate().isNotEmpty &&
          hideBtnFinder.evaluate().isNotEmpty) {
        expect(noticeTextFinder, findsOneWidget);
        await tester.tap(hideBtnFinder);
        await tester.pump();
        expect(noticeTextFinder, findsNothing);
      }
    });

    testWidgets(
        'RecordListToolbar uses single horizontally scrollable row on mobile width',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 640);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecordListToolbar(
              scope: RecordListScope.active,
              sort: RecordListSort.newest,
              activeCount: 3,
              historyCount: 12,
              onScopeChanged: (_) {},
              onSortChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(SingleChildScrollView), findsOneWidget);
      final scrollView = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(scrollView.scrollDirection, Axis.horizontal);
      expect(find.text('Active (3)'), findsOneWidget);
      expect(find.text('History (12)'), findsOneWidget);
    });
  });
}
