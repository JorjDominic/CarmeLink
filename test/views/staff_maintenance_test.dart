import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/controllers/owner_controller.dart';
import 'package:carmelitas_dormitory_system/services/staff_maintenance_service.dart';
import 'package:carmelitas_dormitory_system/views/owner/staff_maintenance_page.dart';

void main() {
  setUp(() {
    OwnerController.instance.clear();
  });

  tearDown(() {
    OwnerController.instance.clear();
  });

  Widget buildTestable(Widget child) {
    return MaterialApp(
      home: Scaffold(body: child),
    );
  }

  group('StaffMaintenancePage Widget Test', () {
    testWidgets('renders metric cards, search, and filter chips', (tester) async {
      OwnerController.instance.setStaffMaintenanceForTesting([]);

      await tester.pumpWidget(buildTestable(const StaffMaintenancePage()));
      await tester.pump();

      // Metric cards
      expect(find.text('Open Issues'), findsOneWidget);
      expect(find.text('High Priority'), findsOneWidget);
      expect(find.text('In Progress'), findsOneWidget);
      expect(find.text('Resolved'), findsOneWidget);

      // Search bar
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.hintText ==
                  'Search by tenant, room, category, or issue...',
        ),
        findsOneWidget,
      );

      // Filter chips
      expect(find.text('All (0)'), findsOneWidget);
      expect(find.text('Pending (0)'), findsOneWidget);
      expect(find.text('Assigned (0)'), findsOneWidget);
      expect(find.text('In Progress (0)'), findsOneWidget);
      expect(find.text('Resolved (0)'), findsOneWidget);
      expect(find.text('Cancelled (0)'), findsOneWidget);

      // Empty state
      expect(find.text('No maintenance requests logged yet.'), findsOneWidget);
    });

    testWidgets('renders reports and filters by status chips', (tester) async {
      final reports = [
        StaffMaintenanceReport(
          id: 'test-smr-1',
          tenantName: 'Juan Dela Cruz',
          category: 'Plumbing',
          description: 'Clogged bathroom drain in room 204',
          location: 'Room 204',
          urgency: 'high',
          status: 'pending',
          notes: '',
          updatedAt: 'v1',
          createdAt: DateTime(2026, 9, 14, 8, 0),
        ),
        StaffMaintenanceReport(
          id: 'test-smr-2',
          tenantName: 'Ana Gomez',
          category: 'Electrical',
          description: 'Flickering ceiling light fixture',
          location: 'Room 105',
          urgency: 'medium',
          status: 'in_progress',
          notes: 'Technician on site',
          updatedAt: 'v2',
          createdAt: DateTime(2026, 9, 14, 9, 15),
        ),
      ];

      OwnerController.instance.setStaffMaintenanceForTesting(reports);

      await tester.pumpWidget(buildTestable(const StaffMaintenancePage()));
      await tester.pump();

      expect(find.text('All (2)'), findsOneWidget);
      expect(find.text('Pending (1)'), findsOneWidget);
      expect(find.text('In Progress (1)'), findsOneWidget);

      // Both reports visible
      expect(find.text('Plumbing'), findsOneWidget);
      expect(find.text('Room 204'), findsOneWidget);
      expect(find.text('Electrical'), findsOneWidget);
      expect(find.text('Room 105'), findsOneWidget);

      // Filter by 'Pending'
      await tester.tap(find.text('Pending (1)'));
      await tester.pump();

      expect(find.text('Plumbing'), findsOneWidget);
      expect(find.text('Electrical'), findsNothing);

      // Filter by 'In Progress'
      await tester.tap(find.text('In Progress (1)'));
      await tester.pump();

      expect(find.text('Plumbing'), findsNothing);
      expect(find.text('Electrical'), findsOneWidget);
    });

    testWidgets('search query filters reports in real-time', (tester) async {
      final reports = [
        StaffMaintenanceReport(
          id: 'test-smr-1',
          tenantName: 'Juan Dela Cruz',
          category: 'Plumbing',
          description: 'Clogged bathroom drain in room 204',
          location: 'Room 204',
          urgency: 'high',
          status: 'pending',
          notes: '',
          updatedAt: 'v1',
          createdAt: DateTime(2026, 9, 14, 8, 0),
        ),
        StaffMaintenanceReport(
          id: 'test-smr-2',
          tenantName: 'Ana Gomez',
          category: 'Electrical',
          description: 'Flickering ceiling light fixture',
          location: 'Room 105',
          urgency: 'medium',
          status: 'in_progress',
          notes: 'Technician on site',
          updatedAt: 'v2',
          createdAt: DateTime(2026, 9, 14, 9, 15),
        ),
      ];

      OwnerController.instance.setStaffMaintenanceForTesting(reports);

      await tester.pumpWidget(buildTestable(const StaffMaintenancePage()));
      await tester.pump();

      // Enter search text "Gomez"
      final searchFinder = find.byWidgetPredicate((w) => w is TextField);
      await tester.enterText(searchFinder, 'Gomez');
      await tester.pump();

      expect(find.text('Ana Gomez'), findsOneWidget);
      expect(find.text('Juan Dela Cruz'), findsNothing);

      // Search non-existent
      await tester.enterText(searchFinder, 'NonExistentXYZ');
      await tester.pump();

      expect(find.text('No reports match the selected filters.'), findsOneWidget);
    });

    testWidgets('toggles dormitory floor plan overview', (tester) async {
      OwnerController.instance.setStaffMaintenanceForTesting([]);

      await tester.pumpWidget(buildTestable(const StaffMaintenancePage()));
      await tester.pump();

      expect(find.text('Dormitory Floor Plan Monitoring'), findsNothing);

      // Tap floor plan icon button
      final mapIconFinder = find.byIcon(Icons.map_outlined);
      expect(mapIconFinder, findsOneWidget);
      await tester.tap(mapIconFinder);
      await tester.pumpAndSettle();

      expect(find.text('Dormitory Floor Plan Monitoring'), findsOneWidget);

      // Tap close button on floor plan card
      final closeFinder = find.byIcon(Icons.close);
      await tester.tap(closeFinder);
      await tester.pumpAndSettle();

      expect(find.text('Dormitory Floor Plan Monitoring'), findsNothing);
    });
  });
}

