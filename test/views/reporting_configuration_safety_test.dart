import 'dart:async';
import '../support/accepted_module_agreements.dart';

import 'package:carmelitas_dormitory_system/controllers/tenant_controller.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/services/dormitory_configuration_service.dart';
import 'package:carmelitas_dormitory_system/views/tenant/tenant_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

DormitoryOption option(String group, String id, String label) =>
    DormitoryOption(
      id: id,
      groupKey: group,
      code: id,
      label: label,
      isActive: true,
      isSystem: false,
      sortOrder: 0,
      categoryCode: group == 'report_type' ? 'other' : null,
    );

class Choices extends DormitoryConfigurationService {
  List<DormitoryOption> categories = [
    option('maintenance_category', 'pest', 'Pest treatment')
  ];
  List<DormitoryOption> areas = [option('common_area', 'lounge', 'Lounge')];
  List<DormitoryOption> concerns = [
    option('report_type', 'noise', 'Noise concern')
  ];
  List<String> rooms = ['Room 204'];
  bool fail = false;
  Future<List<DormitoryOption>>? next;

  @override
  Future<List<DormitoryOption>> options(String groupKey,
      {bool activeOnly = true}) async {
    if (fail) throw StateError('Offline');
    final pending = next;
    if (pending != null) {
      next = null;
      return pending;
    }
    return List.of(switch (groupKey) {
      'maintenance_category' => categories,
      'common_area' => areas,
      'report_type' => concerns,
      _ => <DormitoryOption>[],
    })
      ..sort(DormitoryConfigurationService.compareOptions);
  }

  @override
  Future<List<String>> maintenanceRoomLocations() async => rooms;
}

void main() {
  setUp(() => TenantController.instance.clear());
  tearDown(() => TenantController.instance.clear());

  Future<void> open(WidgetTester tester, Widget page,
      {double width = 390}) async {
    tester.view.physicalSize = Size(width, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: page)));
    await tester.pumpAndSettle();
  }

  DropdownButtonFormField<String> field(WidgetTester tester, String label) =>
      tester
          .widget(find.widgetWithText(DropdownButtonFormField<String>, label));
  DropdownButton<String> menu(WidgetTester tester, String label) =>
      tester.widget(find.descendant(
          of: find.widgetWithText(DropdownButtonFormField<String>, label),
          matching: find.byType(DropdownButton<String>)));
  Future<void> refresh(WidgetTester tester) async {
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator).first)
        .onRefresh();
    await tester.pumpAndSettle();
  }

  testWidgets(
      'maintenance add/rename/archive/restore and location changes refresh without restart',
      (tester) async {
    final choices = Choices();
    await open(tester, SubmitMaintenancePage(configurationService: choices));
    expect(field(tester, 'Issue category').initialValue, 'Pest treatment');
    choices.categories = [
      option('maintenance_category', 'pest', 'Insect treatment'),
      option('maintenance_category', 'glass', 'Glass repair')
    ];
    choices.areas = [option('common_area', 'lounge', 'Study lounge')];
    await refresh(tester);
    expect(field(tester, 'Issue category').initialValue, 'Insect treatment');
    expect(menu(tester, 'Issue category').items!.map((i) => i.value),
        ['Glass repair', 'Insect treatment']);
    expect(field(tester, 'Room / area').initialValue, 'Study lounge');
    choices.categories = [
      option('maintenance_category', 'glass', 'Glass repair')
    ];
    choices.areas = [];
    await refresh(tester);
    expect(field(tester, 'Issue category').initialValue, isNull);
    expect(field(tester, 'Room / area').initialValue, isNull);
    choices.categories
        .add(option('maintenance_category', 'pest', 'Insect treatment'));
    await refresh(tester);
    field(tester, 'Issue category').onChanged!('Insect treatment');
    await tester.pumpAndSettle();
    expect(field(tester, 'Issue category').initialValue, 'Insect treatment');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'maintenance preserves archived original selections while editing',
      (tester) async {
    final report = MaintenanceReport(
        id: 'old',
        category: 'Archived issue',
        location: 'Room 100',
        description: 'Original description',
        urgency: 'Low',
        status: 'Pending',
        createdAt: DateTime(2020));
    await open(tester,
        SubmitMaintenancePage(report: report, configurationService: Choices()));
    expect(field(tester, 'Issue category').initialValue, 'Archived issue');
    expect(field(tester, 'Room / area').initialValue, 'Room 100');
    await refresh(tester);
    expect(field(tester, 'Issue category').initialValue, 'Archived issue');
  });

  testWidgets('maintenance latest refresh wins over an older response',
      (tester) async {
    final choices = Choices();
    await open(tester, SubmitMaintenancePage(configurationService: choices));
    final stale = Completer<List<DormitoryOption>>();
    choices.next = stale.future;
    final oldRefresh = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pump();
    choices.categories = [];
    await refresh(tester);
    stale.complete([option('maintenance_category', 'pest', 'Pest treatment')]);
    await oldRefresh;
    await tester.pumpAndSettle();
    expect(menu(tester, 'Issue category').items, isEmpty);
    expect(field(tester, 'Issue category').initialValue, isNull);
  });

  testWidgets(
      'concern add/rename/archive/restore preserves selected identity and requires reselection',
      (tester) async {
    final choices = Choices();
    await open(
        tester,
        ConfidentialConcernPage(
            configurationService: choices,
            agreementService: const AcceptedModuleAgreements()));
    expect(field(tester, 'Report type').initialValue, 'noise');
    choices.concerns = [
      option('report_type', 'noise', 'Quiet hours concern'),
      option('report_type', 'privacy', 'Privacy concern')
    ];
    await refresh(tester);
    expect(field(tester, 'Report type').initialValue, 'noise');
    expect(find.text('Quiet hours concern'), findsOneWidget);
    choices.concerns.removeAt(0);
    await refresh(tester);
    expect(field(tester, 'Report type').initialValue, isNull);
    choices.concerns.add(option('report_type', 'noise', 'Quiet hours concern'));
    await refresh(tester);
    expect(menu(tester, 'Report type').items!.length, 2);
    field(tester, 'Report type').onChanged!('noise');
    await tester.pumpAndSettle();
    expect(field(tester, 'Report type').initialValue, 'noise');
  });

  testWidgets('concern latest refresh wins over an older response',
      (tester) async {
    final choices = Choices();
    await open(
        tester,
        ConfidentialConcernPage(
            configurationService: choices,
            agreementService: const AcceptedModuleAgreements()));
    final stale = Completer<List<DormitoryOption>>();
    choices.next = stale.future;
    final oldRefresh = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pump();
    choices.concerns = [];
    await refresh(tester);
    stale.complete([option('report_type', 'noise', 'Noise concern')]);
    await oldRefresh;
    await tester.pumpAndSettle();
    expect(menu(tester, 'Report type').items, isEmpty);
  });

  for (final concern in [false, true]) {
    for (final width in [390.0, 1200.0]) {
      testWidgets(
          '${concern ? 'concern' : 'maintenance'} loading/failure/retry/empty/Other at width $width',
          (tester) async {
        final choices = Choices();
        final pending = Completer<List<DormitoryOption>>();
        choices.next = pending.future;
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: concern
                    ? ConfidentialConcernPage(
                        configurationService: choices,
                        agreementService: const AcceptedModuleAgreements())
                    : SubmitMaintenancePage(configurationService: choices))));
        await tester.pump();
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        expect(
            field(tester, concern ? 'Report type' : 'Issue category').onChanged,
            isNull);
        pending.completeError(StateError('Offline'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Could not load'), findsOneWidget);
        choices.concerns = [];
        choices.categories = [];
        choices.areas = [];
        choices.rooms = [];
        await tester.tap(find.byIcon(Icons.refresh));
        await tester.pumpAndSettle();
        expect(find.textContaining('No report'), findsOneWidget);
        choices.categories = [option('maintenance_category', 'other', 'Other')];
        choices.rooms = ['Room 204'];
        choices.concerns = [option('report_type', 'other', 'Other')];
        await refresh(tester);
        field(tester, concern ? 'Report type' : 'Issue category')
            .onChanged!(concern ? 'other' : 'Other');
        await tester.pumpAndSettle();
        expect(
            find.text(concern
                ? 'Please specify the concern'
                : 'Please specify the issue category'),
            findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
