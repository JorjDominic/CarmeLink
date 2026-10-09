import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/core/utils/confidential_review_action.dart';
import 'package:carmelitas_dormitory_system/services/confidential_report_service.dart';
import 'package:carmelitas_dormitory_system/services/room_service.dart';
import 'package:carmelitas_dormitory_system/views/shared/report_addenda.dart';
import 'package:carmelitas_dormitory_system/views/shared/review_notes_dialog.dart';
import 'package:carmelitas_dormitory_system/views/owner/floor_management_page.dart';
import 'package:carmelitas_dormitory_system/views/owner/room_monitoring_page.dart';

class _Reports extends ConfidentialReportService {
  bool fail = false;
  int writes = 0;
  @override
  Future<List<ConfidentialReportAddendum>> listAddenda(String id) async => [];
  @override
  Future<void> addCorrection(String id, String body,
      {required String requestId}) async {
    writes++;
    if (fail) throw StateError('Persistence failed');
  }
}

class _Rooms extends RoomService {
  bool fail = false;
  Map<String, String>? saved;
  @override
  Future<List<String>> listFloors() async => ['Ground floor', 'Second floor'];
  @override
  Future<void> updateRoom(
      {required String id,
      required String number,
      required String floor,
      required String description}) async {
    if (fail) throw StateError('Persistence failed');
    saved = {'id': id, 'number': number, 'floor': floor};
  }
}

const room = RoomRecord(
    id: 'stable-room-id',
    number: '101',
    floor: 'Ground floor',
    capacity: 4,
    description: '',
    beds: []);

void main() {
  test('floor API errors distinguish missing cache, RPC and permissions', () {
    expect(
        roomServiceError(const PostgrestException(
            message:
                "Could not find the table 'public.room_floors' in the schema cache",
            code: 'PGRST205')),
        contains('migration and schema cache'));
    expect(
        roomServiceError(const PostgrestException(
            message: 'permission denied for table room_floors', code: '42501')),
        contains('access was denied'));
    expect(
        roomServiceError(const PostgrestException(
            message: 'Could not find the function public.create_room_floor',
            code: 'PGRST202')),
        contains('RPCs and schema cache'));
  });
  test('confidential actions have distinct persisted status and messages', () {
    final review = ConfidentialReviewAction.forStatus('under_review');
    expect(review.title.toLowerCase(), contains('under review'));
    expect(review.successMessage.toLowerCase(), isNot(contains('resolved')));
    expect(ConfidentialReviewAction.forStatus('resolved').successMessage,
        'Confidential report resolved.');
    expect(
        () => ConfidentialReviewAction.forStatus('unknown'), throwsStateError);
    final source = File('lib/views/owner/owner_pages.dart').readAsStringSync();
    expect(source, contains('if (saved == true && mounted)'));
    expect(source, contains('action.successMessage'));
  });

  test(
      'review response preserves configured labels, specific concerns and history',
      () {
    final report = reviewedConfidentialReport({
      'id': 'report',
      'category': 'other',
      'report_type_label': 'Private custom concern',
      'specific_concern': 'Original specific details',
      'summary': 'Original report',
      'status': 'submitted',
      'created_at': '2026-10-09T00:00:00Z',
    }, {
      'id': 'report',
      'status': 'under_review',
      'response_notes': 'Review notes'
    });
    expect(report.status, 'Under Review');
    expect(report.category, 'Private custom concern');
    expect(report.specificConcern, 'Original specific details');
    expect(report.summary, 'Original report');
    expect(report.responseNotes, 'Review notes');
  });

  for (final title in [
    'Move to review',
    'Issue warning',
    'Resolve case',
    'Dismiss case'
  ]) {
    testWidgets('$title handles long notes and keyboard without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.reset);
      final controller = TextEditingController(
          text: List.filled(80, 'Long review notes').join('\n'));
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Builder(
                  builder: (context) => TextButton(
                      onPressed: () => showDialog<void>(
                          context: context,
                          builder: (_) => ReviewNotesDialog(
                                  title: title,
                                  controller: controller,
                                  label: 'Notes',
                                  maxLength: 4000,
                                  actions: [
                                    TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Cancel')),
                                    FilledButton(
                                        onPressed: () {},
                                        child: const Text('Save'))
                                  ])),
                      child: const Text('Open'))))));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.maxLines, 6);
      expect(tester.getRect(find.text('Save')).bottom, lessThan(360));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  }

  testWidgets('resolved reports retain history but disable addenda',
      (tester) async {
    final service = _Reports();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: ReportAddenda(
                    reportId: 'report', isResolved: true, service: service)))));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(service.writes, 0);
  });

  testWidgets('failed addendum save never displays success', (tester) async {
    final service = _Reports()..fail = true;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: ReportAddenda(reportId: 'report', service: service)))));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Additional details');
    await tester.tap(find.text('Add to report'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm and add'));
    await tester.pumpAndSettle();
    expect(service.writes, 1);
    expect(find.textContaining('Could not save'), findsOneWidget);
    expect(find.text('Correction added to the report.'), findsNothing);
  });

  test('room validation and filters preserve existing records', () {
    expect(() => validateRoomIdentity('', 'Ground floor'), throwsArgumentError);
    expect(() => validateFloorName(' '), throwsArgumentError);
    expect(() => validateFloorName(List.filled(61, 'a').join()),
        throwsArgumentError);
    const archived = RoomRecord(
        id: 'archived',
        number: '102',
        floor: 'Second floor',
        capacity: 4,
        description: '',
        beds: [],
        isActive: false);
    const records = [room, archived];
    expect(filterRoomDirectory(records, availability: 'active').single.id,
        room.id);
    expect(filterRoomDirectory(records, availability: 'archived').single.id,
        archived.id);
    expect(records.length, 2);
  });

  testWidgets('floor selection uses existing labels, not free text',
      (tester) async {
    final controller = TextEditingController(text: 'Ground floor');
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: FloorNameField(
                controller: controller,
                floors: const ['Ground floor', 'Second floor']))));
    expect(find.byType(TextFormField), findsNothing);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Second floor').last);
    await tester.pumpAndSettle();
    expect(controller.text, 'Second floor');
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  for (final failure in [false, true]) {
    testWidgets(
        'room editor preserves identity and ${failure ? 'failed' : 'successful'} save behavior',
        (tester) async {
      final service = _Rooms()..fail = failure;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Builder(
                  builder: (context) => TextButton(
                      onPressed: () => showDialog<bool>(
                          context: context,
                          builder: (_) =>
                              RoomEditor(service: service, room: room)),
                      child: const Text('Edit'))))));
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Renamed 101');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      if (failure) {
        expect(find.byType(RoomEditor), findsOneWidget);
        expect(service.saved, isNull);
      } else {
        expect(find.byType(RoomEditor), findsNothing);
        expect(service.saved?['id'], 'stable-room-id');
        expect(service.saved?['number'], 'Renamed 101');
      }
      expect(tester.takeException(), isNull);
    });
  }
}
