import 'package:carmelitas_dormitory_system/core/widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/core/theme/app_theme.dart';
import 'package:carmelitas_dormitory_system/core/widgets/management_record_list.dart';
import 'package:carmelitas_dormitory_system/services/retention_policy_service.dart';
import 'package:carmelitas_dormitory_system/services/dormitory_configuration_service.dart';
import 'package:carmelitas_dormitory_system/views/shared/account_management_page.dart';
import 'package:carmelitas_dormitory_system/views/owner/guardian_link_management_page.dart';
import 'package:carmelitas_dormitory_system/views/owner/dormitory_configuration_page.dart';
import 'package:carmelitas_dormitory_system/views/shared/retention_settings_page.dart';

void main() {
  testWidgets('pagination stays clear of the floating create action',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: PageFrame(
            title: 'Accounts',
            floatingActionButton: FloatingActionButton.extended(
                onPressed: () {},
                icon: const Icon(Icons.add),
                label: const Text('Create account')),
            child: ManagementRecordList<int>(
                bottomClearance: 72,
                items: List.generate(13, (i) => i),
                itemLabel: 'accounts',
                itemBuilder: (i) => SizedBox(
                    height: 140, child: Text('Account ' + i.toString()))))));
    await tester.pumpAndSettle();
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
    scroll.position.jumpTo(scroll.position.maxScrollExtent);
    await tester.pumpAndSettle();
    final last = find.byTooltip('Last page');
    final fab = find.byType(FloatingActionButton);
    expect(tester.getRect(last).overlaps(tester.getRect(fab)), isFalse);
    await tester.tap(last);
    await tester.pumpAndSettle();
    expect(find.text('Account 12'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final width in [320.0, 390.0, 768.0, 1280.0]) {
    for (final scale in [1.0, 1.6]) {
      for (final kind in ['accounts', 'links', 'record groups']) {
        testWidgets(
            '$kind cards paginate, activate and refresh at $width scale $scale',
            (tester) async {
          tester.view.physicalSize = Size(width, 1100);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          var count = 13;
          var selected = -1;
          late StateSetter update;
          await tester.pumpWidget(MaterialApp(
              theme: AppTheme.light(),
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!),
              home: Scaffold(
                  body: SingleChildScrollView(
                      child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: StatefulBuilder(builder: (context, setState) {
                            update = setState;
                            return ManagementRecordList<int>(
                                items: List.generate(count, (i) => i),
                                itemLabel: kind,
                                itemBuilder: (i) {
                                  if (kind == 'accounts')
                                    return AccountRecordCard(
                                        account: {
                                          'full_name': 'Record $i',
                                          'email':
                                              'a.long.resident.email.address@carmelita.test',
                                          'phone': '+63 917 000 0001',
                                          'email_verification_status':
                                              'pending',
                                          'phone_verification_status':
                                              'verified'
                                        },
                                        roleLabel: 'Tenant',
                                        onTap: () => selected = i);
                                  if (kind == 'links')
                                    return GuardianLinkCard(link: {
                                      'guardian': {'full_name': 'Record $i'},
                                      'tenant': {
                                        'full_name':
                                            'A long resident name that must remain fully readable'
                                      },
                                      'relationship':
                                          'Parent or legal guardian',
                                      'is_primary': true
                                    }, onTap: () => selected = i);
                                  return RetentionSettingCard(
                                      setting: RetentionPolicySetting(
                                          recordKey: '$i',
                                          displayName: 'Record $i',
                                          description:
                                              'Sensitive evidence used by the existing approved workflow.',
                                          reviewStatus: 'draft',
                                          reviewNotes: '',
                                          enforcementEnabled: false,
                                          updatedAt: DateTime(2026, 10, 18),
                                          proposedRetentionDays: 365),
                                      onConfigure: () => selected = i,
                                      onHistory: () => selected = 100 + i);
                                });
                          }))))));
          await tester.pumpAndSettle();
          expect(find.text('Record 0'), findsOneWidget);
          expect(find.text('Record 6'), findsNothing);
          final last = find.byTooltip('Last page');
          await tester.ensureVisible(last);
          await tester.tap(last);
          await tester.pumpAndSettle();
          expect(find.text('Record 12'), findsOneWidget);
          expect(find.text('Record 0'), findsNothing);
          expect(find.text('Showing 13-13 of 13 $kind'), findsOneWidget);
          await tester.ensureVisible(find.text('Record 12'));
          await tester.tap(find.text('Record 12'));
          expect(selected, 12);
          if (kind == 'record groups') {
            await tester.ensureVisible(find.text('History'));
            await tester.tap(find.text('History'));
            expect(selected, 112);
            expect(find.text('Disabled'), findsOneWidget);
          }
          update(() => count = 2);
          await tester.pumpAndSettle();
          expect(find.text('Record 0'), findsOneWidget);
          expect(find.text('Record 12'), findsNothing);
          expect(find.byTooltip('Last page'), findsNothing);
          expect(tester.takeException(), isNull);
        });
      }
      testWidgets(
          'configuration cards preserve protected choices at $width scale $scale',
          (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var edits = 0, toggles = 0;
        await tester.pumpWidget(MaterialApp(
            theme: AppTheme.light(),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: Scaffold(
                body: SingleChildScrollView(
                    child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(children: [
                          for (final system in [true, false])
                            ConfigurationChoiceCard(
                                option: DormitoryOption(
                                    id: '$system',
                                    groupKey: 'maintenance_category',
                                    code: '$system',
                                    label:
                                        'A long maintenance category name for responsive review',
                                    isActive: true,
                                    isSystem: system,
                                    sortOrder: 0),
                                onEdit: () => edits++,
                                onToggle: () => toggles++),
                        ]))))));
        expect(find.text('Protected system choice'), findsOneWidget);
        expect(find.byTooltip('Edit'), findsOneWidget);
        await tester.tap(find.byTooltip('Edit'));
        await tester.tap(find.byTooltip('Archive choice'));
        expect(edits, 1);
        expect(toggles, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
