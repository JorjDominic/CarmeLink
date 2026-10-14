import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carmelitas_dormitory_system/services/conduct_case_service.dart';
import 'package:carmelitas_dormitory_system/services/staff_maintenance_service.dart';
import 'package:carmelitas_dormitory_system/views/shared/administrative_entry_dialog.dart';
import 'package:carmelitas_dormitory_system/views/shared/conduct_official_responses.dart';
import 'package:carmelitas_dormitory_system/views/shared/report_status_actions.dart';
import 'package:carmelitas_dormitory_system/views/owner/staff_maintenance_page.dart';

final record = ConductCaseRecord(
    id: 'case-1',
    category: 'rule_violation',
    title: 'Original conduct case',
    description: 'Original incident description',
    incidentAt: DateTime(2026, 10, 14),
    status: 'under_review',
    createdAt: DateTime(2026, 10, 14),
    updatedAt: DateTime(2026, 10, 14));

class Responses extends ConductCaseService {
  final calls = <bool>[];
  @override
  Future<List<ConductOfficialResponse>> listOfficialResponses(String caseId,
      {required bool staffMode}) async {
    calls.add(staffMode);
    return [
      ConductOfficialResponse(
          id: 'visible',
          body: 'Provide supporting information.',
          authorName: 'Owner name',
          authorRole: 'owner',
          visibility: 'tenant',
          createdAt: DateTime(2026, 10, 14, 9)),
      if (staffMode)
        ConductOfficialResponse(
            id: 'private',
            body: 'Private administrative instructions.',
            authorName: 'Caretaker name',
            authorRole: 'caretaker',
            visibility: 'internal',
            createdAt: DateTime(2026, 10, 14, 10)),
    ];
  }
}

class Maintenance extends StaffMaintenanceService {
  @override
  Future<StaffMaintenanceReport> getReport(String id) async =>
      StaffMaintenanceReport(
          id: id,
          tenantName: 'Reporting tenant',
          category: 'Plumbing',
          description: 'Original report details',
          location: 'Room 101',
          urgency: 'high',
          status: 'pending',
          notes: '',
          updatedAt: '2026-10-14T00:00:00Z',
          createdAt: DateTime(2026, 10, 14));
  @override
  Future<List<Map<String, dynamic>>> history(String id) async => [];
}

void main() {
  Future<void> openComposer(
      WidgetTester tester, Future<void> Function(String, String, String) save,
      {bool tenantChoice = true}) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => FilledButton(
                    onPressed: () => showAdministrativeEntryDialog(context,
                        title: 'Add official response',
                        allowTenantVisibility: tenantChoice,
                        onSave: save),
                    child: const Text('Open composer'))))));
    await tester.tap(find.text('Open composer'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'official entry previews visibility, requires confirmation, prevents duplicate clicks',
      (tester) async {
    final pending = Completer<void>();
    final writes = <({String body, String visibility, String key})>[];
    await openComposer(tester, (body, visibility, key) async {
      writes.add((body: body, visibility: visibility, key: key));
      await pending.future;
    });
    expect(find.textContaining('Only authorized staff'), findsOneWidget);
    await tester.enterText(
        find.byType(TextField), 'Please provide supporting documents.');
    await tester.tap(find.text('Review entry'));
    await tester.pumpAndSettle();
    expect(writes, isEmpty);
    expect(find.text('Confirm administrative entry'), findsOneWidget);
    await tester.tap(find.text('Confirm and save'));
    await tester.tap(find.text('Confirm and save'));
    await tester.pump();
    expect(writes, hasLength(1));
    expect(writes.single.visibility, 'internal');
    expect(
        writes.single.key,
        matches(RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    expect(
        tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
        isNull);
    pending.complete();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets(
      'failed save remains open and retry retains same immutable payload and key',
      (tester) async {
    final keys = <String>[];
    await openComposer(tester, (body, visibility, key) async {
      keys.add(key);
      if (keys.length == 1)
        throw const PostgrestException(message: 'Network interrupted');
    });
    await tester.enterText(
        find.byType(TextField), 'Official instructions awaiting confirmation.');
    await tester.tap(find.text('Review entry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm and save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('not confirmed saved'), findsOneWidget);
    expect(find.text('Edit'), findsNothing);
    await tester.tap(find.text('Confirm and save'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    expect(keys, hasLength(2));
    expect(keys.first, keys.last);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets(
      'tenant visibility requires explicit choice and is included in review',
      (tester) async {
    String? savedVisibility;
    await openComposer(tester, (body, visibility, key) async {
      savedVisibility = visibility;
    });
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tenant-visible official response').last);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextField), 'Acknowledge these official instructions.');
    await tester.tap(find.text('Review entry'));
    await tester.pumpAndSettle();
    expect(find.textContaining('tenant will be notified'), findsOneWidget);
    await tester.tap(find.text('Confirm and save'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    expect(savedVisibility, 'tenant');
  });

  testWidgets('short response is rejected before preview or persistence',
      (tester) async {
    var writes = 0;
    await openComposer(tester, (body, visibility, requestId) async {
      writes++;
    });
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.tap(find.text('Review entry'));
    await tester.pumpAndSettle();
    expect(find.text('Enter at least 5 characters.'), findsOneWidget);
    expect(writes, 0);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets(
      'tenant and staff response sections request their own authorized projections',
      (tester) async {
    final service = Responses();
    Future<void> render(bool staff) => tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: ConductOfficialResponses(
                    key: ValueKey(staff),
                    record: record,
                    staffMode: staff,
                    service: service,
                    onSaved: () async {})))));
    await render(false);
    await tester.pumpAndSettle();
    expect(find.text('Provide supporting information.'), findsOneWidget);
    expect(find.text('Private administrative instructions.'), findsNothing);
    expect(find.text('Add Official Response'), findsNothing);
    await render(true);
    await tester.pumpAndSettle();
    expect(find.text('Private administrative instructions.'), findsOneWidget);
    expect(find.text('Add Official Response'), findsOneWidget);
    expect(service.calls, [false, true]);
  });

  testWidgets(
      'report selector presents only valid next actions with no duplicate shortcut controls',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ReportStatusActions(
                currentStatus: 'pending',
                selectedStatus: 'pending',
                allowedStatuses: allowedMaintenanceStatuses('pending'),
                labels: maintenanceStatusLabels,
                onChanged: (_) {}))));
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.text('In Progress'), findsOneWidget);
    expect(find.text('Resolved'), findsNothing);
    expect(find.byType(ActionChip), findsNothing);
  });

  for (final width in [320.0, 1280.0]) {
    testWidgets(
        'response dialog fits $width with enlarged text and keyboard inset',
        (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(1.35),
                  viewInsets: const EdgeInsets.only(bottom: 220)),
              child: child!),
          home: Scaffold(
              body: Builder(
                  builder: (context) => FilledButton(
                      onPressed: () => showAdministrativeEntryDialog(context,
                          title: 'Add official response',
                          allowTenantVisibility: true,
                          onSave: (body, visibility, requestId) async {}),
                      child: const Text('Open'))))));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
    });
    testWidgets(
        'maintenance detail fits $width and preserves current status while choosing next action',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.35)),
              child: child!),
          home: StaffMaintenanceDetailsPage(
              id: 'report', service: Maintenance())));
      await tester.pumpAndSettle();
      expect(find.text('Pending'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      expect(find.byType(ActionChip), findsNothing);
      await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('In Progress').last);
      await tester.pumpAndSettle();
      expect(find.text('Pending'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
