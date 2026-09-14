import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/controllers/tenant_controller.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/views/tenant/tenant_pages.dart';

void main() {
  setUp(() {
    TenantController.instance.clear();
  });

  tearDown(() {
    TenantController.instance.clear();
  });

  Widget buildTestable(Widget child) {
    return MaterialApp(
      home: Scaffold(body: child),
    );
  }

  group('TenantReportsHubPage Widget Test', () {
    testWidgets('renders summary cards and action buttons', (tester) async {
      TenantController.instance.setMaintenanceForTesting([]);

      await tester.pumpWidget(buildTestable(const TenantReportsHubPage()));
      await tester.pump();

      expect(find.text('REPORT SUMMARY'), findsOneWidget);
      expect(find.text('Maintenance'), findsOneWidget);
      expect(find.text('Resolved'), findsOneWidget);
      expect(find.text('Confidential'), findsOneWidget);
      expect(find.text('Maintenance reports'), findsOneWidget);
      expect(find.text('Confidential concern'), findsOneWidget);
      expect(find.text('Report issue'), findsOneWidget);
    });

    testWidgets('displays active maintenance issue preview when pending report exists', (tester) async {
      TenantController.instance.setMaintenanceForTesting([
        MaintenanceReport(
          id: 'mr-test-1',
          category: 'Plumbing',
          description: 'Sink leaking water onto the cabinet floor',
          location: 'Room 204',
          urgency: 'High',
          status: 'Pending',
          createdAt: DateTime(2026, 9, 14, 8, 0),
        ),
      ]);

      await tester.pumpWidget(buildTestable(const TenantReportsHubPage()));
      await tester.pump();

      expect(find.text('ACTIVE MAINTENANCE ISSUE'), findsOneWidget);
      expect(find.text('Plumbing • Room 204'), findsOneWidget);
      expect(find.text('Sink leaking water onto the cabinet floor'), findsOneWidget);
    });
  });

  group('MaintenanceReportsPage Widget Test', () {
    testWidgets('renders filter chips and empty state when no reports exist', (tester) async {
      TenantController.instance.setMaintenanceForTesting([]);

      await tester.pumpWidget(buildTestable(const MaintenanceReportsPage()));
      await tester.pump();

      expect(find.text('REPORT SUMMARY'), findsOneWidget);
      expect(find.text('Open reports'), findsOneWidget);
      expect(find.text('High priority'), findsOneWidget);

      // Verify filter chips exist
      expect(find.text('All (0)'), findsOneWidget);
      expect(find.text('Pending (0)'), findsOneWidget);
      expect(find.text('In Progress (0)'), findsOneWidget);
      expect(find.text('Resolved (0)'), findsOneWidget);
      expect(find.text('Cancelled (0)'), findsOneWidget);

      // Verify empty state
      expect(
        find.text('No maintenance reports yet. Use Report issue to submit one.'),
        findsOneWidget,
      );

      // Verify FAB
      expect(find.text('Report issue'), findsOneWidget);
    });

    testWidgets('renders report card and opens details sheet on tap', (tester) async {
      TenantController.instance.setMaintenanceForTesting([
        MaintenanceReport(
          id: 'mr-detail-1',
          category: 'Air conditioning',
          description: 'AC unit blowing warm air only',
          location: 'Room 204',
          urgency: 'Medium',
          status: 'Pending',
          createdAt: DateTime(2026, 9, 14, 9, 30),
          staffNotes: 'Technician scheduled for 3pm',
        ),
      ]);

      await tester.pumpWidget(buildTestable(const MaintenanceReportsPage()));
      await tester.pump();

      expect(find.text('All (1)'), findsOneWidget);
      expect(find.text('Pending (1)'), findsOneWidget);
      expect(find.text('Air conditioning • Room 204'), findsOneWidget);

      // Tap report card to open details modal sheet
      await tester.tap(find.text('Air conditioning • Room 204'));
      await tester.pumpAndSettle();

      // Verify detail sheet content
      expect(find.text('DESCRIPTION'), findsOneWidget);
      expect(find.text('AC unit blowing warm air only'), findsOneWidget);
      expect(find.text('STAFF UPDATES'), findsOneWidget);
      expect(find.text('Technician scheduled for 3pm'), findsOneWidget);
      expect(find.text('Edit report'), findsOneWidget);
      expect(find.text('Cancel request'), findsOneWidget);
    });
  });
}

