import 'package:carmelitas_dormitory_system/services/confidential_report_service.dart';
import 'package:carmelitas_dormitory_system/views/shared/report_addenda.dart';
import 'package:carmelitas_dormitory_system/services/staff_maintenance_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/controllers/owner_controller.dart';
import 'package:carmelitas_dormitory_system/core/theme/app_theme.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/views/owner/owner_pages.dart';
import 'package:carmelitas_dormitory_system/views/owner/staff_maintenance_page.dart';

class _ReportHistoryFixture extends ConfidentialReportService {
  @override
  Future<List<ConfidentialReportAddendum>> listAddenda(String id) async => [
        ConfidentialReportAddendum(
            id: 'entry',
            reportId: id,
            authorId: 'author',
            authorName: 'A long report author name that must wrap safely',
            authorRole: 'tenant',
            body:
                'Original correction with evidence and investigation details remains fully readable.',
            createdAt: DateTime(2026, 10, 18, 21, 15))
      ];
}

void main() {
  final controller = OwnerController.instance;
  setUp(controller.clear);
  tearDown(controller.clear);
  for (final width in [320.0, 390.0, 768.0, 1280.0]) {
    testWidgets(
        'closed report retains readable correction history at ' +
            width.toString(), (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
              body: SingleChildScrollView(
                  child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: ReportAddenda(
                          reportId: 'report',
                          isResolved: true,
                          service: _ReportHistoryFixture()))))));
      await tester.pumpAndSettle();
      expect(find.text('A long report author name that must wrap safely'),
          findsOneWidget);
      expect(
          find.text(
              'Original correction with evidence and investigation details remains fully readable.'),
          findsOneWidget);
      expect(find.text('tenant'), findsOneWidget);
      expect(find.text('Add correction'), findsNothing);
      expect(tester.takeException(), isNull);
    });
    testWidgets('existing report exports remain available at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.light(), home: const ReportsAnalyticsPage()));
      await tester.pumpAndSettle();
      expect(find.text('Print / Download PDF'), findsNWidgets(6));
      expect(find.text('Official PDF Reports & Data Exports'), findsOneWidget);
      final cards = find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_ReportExportCard');
      final first = tester.getTopLeft(cards.at(0));
      final second = tester.getTopLeft(cards.at(1));
      if (width == 1280) {
        expect(second.dx, greaterThan(first.dx));
      } else {
        expect(second.dy, greaterThan(first.dy));
      }
      for (var index = 0; index < 6; index++) {
        final button = find
            .widgetWithText(OutlinedButton, 'Print / Download PDF')
            .at(index);
        await tester.ensureVisible(button);
        expect(tester.widget<OutlinedButton>(button).onPressed, isNotNull);
      }
      expect(tester.takeException(), isNull);
    });
    testWidgets(
        'financial category values retain the existing totals at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      controller.setPaymentsForTesting([
        Payment(
            id: 'rent',
            label: 'Partial rent',
            amount: 3000,
            verifiedAmount: 800,
            remainingBalance: 2200,
            status: 'Partially paid',
            dueDate: DateTime.now().subtract(const Duration(days: 1)))
      ]);
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.light(), home: const ExpenseIncomeSummaryPage()));
      await tester.pumpAndSettle();
      expect(find.text('Rent Collections'), findsOneWidget);
      expect(find.text('Utility Collections'), findsOneWidget);
      expect(find.text('\u20b1800.00'), findsNWidgets(2));
      expect(find.text('\u20b12200.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets(
        'maintenance damage record and floor-plan controls fit at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      controller.setStaffMaintenanceForTesting([
        StaffMaintenanceReport(
            id: 'damage',
            tenantName: 'A long resident name that must remain readable',
            category: 'Damage - broken bedroom door',
            description:
                'The door frame requires repair and the original report must remain intact.',
            location: 'Room 204 - second floor - bed 3',
            urgency: 'high',
            status: 'pending',
            notes: '',
            updatedAt: 'version-1',
            createdAt: DateTime(2026, 10, 18))
      ]);
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.light(), home: const StaffMaintenancePage()));
      await tester.pumpAndSettle();
      expect(find.text('Damage - broken bedroom door'), findsOneWidget);
      expect(find.text('High Priority'), findsOneWidget);
      expect(find.text('Resolved (0)'), findsOneWidget);
      await tester.tap(find.byTooltip('Floor Plan Overview'));
      await tester.pumpAndSettle();
      expect(find.text('Dormitory Floor Plan Monitoring'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
