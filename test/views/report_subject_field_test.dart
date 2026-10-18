import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/services/report_subject_service.dart';
import 'package:carmelitas_dormitory_system/views/shared/report_subject_field.dart';

class Subjects extends ReportSubjectService {
  bool fail = false;
  int calls = 0;
  Completer<List<ReportSubject>>? pending;
  @override
  Future<List<ReportSubject>> search(String query, {int offset = 0}) async {
    calls++;
    if (fail) throw StateError('Lookup unavailable');
    if (pending != null) return await pending!.future;
    return const [ReportSubject('tenant-b', 'Tenant B')];
  }
}

void main() {
  for (final width in [320.0, 1280.0]) {
    testWidgets('select and clear optional report subject at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      ReportSubject? selected;
      final service = Subjects();
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: StatefulBuilder(
                  builder: (context, setState) => SingleChildScrollView(
                      child: ReportSubjectField(
                          value: selected,
                          service: service,
                          onChanged: (value) =>
                              setState(() => selected = value)))))));
      await tester.tap(find.text('Find tenant'));
      await tester.pumpAndSettle();
      expect(service.calls, 0);
      await tester.enterText(find.byType(TextField), 'Tenant B');
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(ListTile, 'Tenant B'));
      await tester.tap(find.widgetWithText(ListTile, 'Tenant B'));
      await tester.pumpAndSettle();
      expect(selected!.id, 'tenant-b');
      expect(find.text('Tenant B'), findsOneWidget);
      await tester.tap(find.text('Clear'));
      await tester.pump();
      expect(selected, isNull);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('failed lookup can be cancelled without requiring a subject',
      (tester) async {
    ReportSubject? selected;
    final service = Subjects()..fail = true;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ReportSubjectField(
                value: null,
                service: service,
                onChanged: (value) => selected = value))));
    await tester.tap(find.text('Find tenant'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Tenant');
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Tenant search is unavailable.'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(selected, isNull);
    expect(find.text('Find tenant'), findsOneWidget);
  });
  testWidgets('editing a query invalidates pending results', (tester) async {
    final service = Subjects()..pending = Completer<List<ReportSubject>>();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ReportSubjectField(
                value: null, service: service, onChanged: (_) {}))));
    await tester.tap(find.text('Find tenant'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Old name');
    await tester.tap(find.text('Search'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'New name');
    service.pending!.complete(const [ReportSubject('old', 'Old result')]);
    await tester.pumpAndSettle();
    expect(find.text('Old result'), findsNothing);
  });
  testWidgets('short query is rejected before directory lookup',
      (tester) async {
    final service = Subjects();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ReportSubjectField(
                value: null, service: service, onChanged: (_) {}))));
    await tester.tap(find.text('Find tenant'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'A');
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(service.calls, 0);
    expect(find.textContaining('Enter 2 to 80'), findsOneWidget);
  });
}
