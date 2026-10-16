import 'package:carmelitas_dormitory_system/core/utils/conduct_case_policy.dart';
import 'package:carmelitas_dormitory_system/controllers/owner_controller.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/core/widgets/configured_choice_field.dart';
import 'package:carmelitas_dormitory_system/core/widgets/staff_tenant_picker.dart';
import 'package:carmelitas_dormitory_system/models/staff_tenant_option.dart';
import 'package:carmelitas_dormitory_system/services/conduct_case_service.dart';
import 'package:carmelitas_dormitory_system/services/dormitory_configuration_service.dart';
import 'package:carmelitas_dormitory_system/views/shared/conduct_case_create_dialog.dart';
import 'package:carmelitas_dormitory_system/views/owner/billing_management_page.dart';
import 'package:carmelitas_dormitory_system/views/owner/utility_charge_cart_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class RecordingConductService extends ConductCaseService {
  String? category, detail;

  @override
  Future<String> createCase({
    required String tenantId,
    required String category,
    String? categoryDetail,
    required String title,
    required String description,
    required DateTime incidentAt,
    required String sourceModule,
    String? sourceRecordId,
    String? sourceDetail,
  }) async {
    this.category = category;
    detail = categoryDetail;
    return 'case';
  }
}

DormitoryOption choice(String code, String label) => DormitoryOption(
      id: code,
      groupKey: 'conduct_category',
      code: code,
      label: label,
      isActive: true,
      isSystem: false,
      sortOrder: 0,
    );

void main() {
  void seedTenant() {
    OwnerController.instance.setTenantsForTesting(const [
      TenantDirectoryEntry(
          id: 'tenant',
          name: 'Test tenant',
          room: '101',
          bedSpace: 'A',
          phone: '',
          guardianName: '',
          guardianPhone: ''),
    ]);
    addTearDown(OwnerController.instance.clear);
  }

  Future<void> openFinancialDialog(WidgetTester tester, Widget dialog) async {
    tester.view.physicalSize = const Size(1100, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
      builder: (context) => TextButton(
        onPressed: () =>
            showDialog<void>(context: context, builder: (_) => dialog),
        child: const Text('Open'),
      ),
    ))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'custom additional-charge label maps to Other with a readable specification',
      (tester) async {
    seedTenant();
    await openFinancialDialog(
        tester,
        AdditionalChargeDialog(
            categoryOptionsLoader: (_) async => [
                  const DormitoryOption(
                      id: 'custom',
                      groupKey: 'additional_charge_category',
                      code: 'custom',
                      label: 'Pest treatment',
                      categoryCode: 'other',
                      isActive: true,
                      isSystem: false,
                      sortOrder: 0),
                ]));
    await tester
        .tap(find.widgetWithText(DropdownButtonFormField<String>, 'Category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pest treatment').last);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextFormField>(
                find.byKey(const Key('additional-charge-specific-category')))
            .controller!
            .text,
        'Pest treatment');
    expect(
        tester
            .widget<TextFormField>(
                find.widgetWithText(TextFormField, 'Charge title'))
            .controller!
            .text,
        'Pest treatment');
  });

  testWidgets(
      'utility cart requires an active choice and retains its custom label',
      (tester) async {
    seedTenant();
    await openFinancialDialog(
        tester,
        UtilityChargeCartDialog(
            categoryOptionsLoader: (_) async => [
                  const DormitoryOption(
                      id: 'custom',
                      groupKey: 'utility_category',
                      code: 'custom',
                      label: 'Drinking water delivery',
                      categoryCode: 'utility',
                      isActive: true,
                      isSystem: false,
                      sortOrder: 0),
                ]));
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Source bill total'), '120');
    await tester.tap(find.text('Add to cart'));
    await tester.pumpAndSettle();
    expect(find.text('Select an active utility category'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
    await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String>, 'Utility type'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Drinking water delivery').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to cart'));
    await tester.pumpAndSettle();
    expect(
        find.widgetWithText(
            ListTile, 'Drinking water delivery • Individual tenant'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  Future<void> open(WidgetTester tester, RecordingConductService service,
      Future<List<DormitoryOption>> Function(String) loader) async {
    tester.view.physicalSize = const Size(1100, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (context) {
        return TextButton(
          onPressed: () => showDialog<bool>(
            context: context,
            builder: (_) => ConductCaseCreateDialog(
              service: service,
              categoryOptionsLoader: loader,
              tenants: const [
                StaffTenantOption(
                    id: 'tenant',
                    name: 'Test tenant',
                    residencyStatus: 'active'),
              ],
            ),
          ),
          child: const Text('Open'),
        );
      })),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(StaffTenantPickerField));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Test tenant'));
    await tester.pumpAndSettle();
  }

  Future<void> select(WidgetTester tester, String label) async {
    await tester.tap(find.descendant(
        of: find.byType(ConfiguredChoiceField),
        matching: find.byType(InputDecorator)));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, label));
    await tester.pumpAndSettle();
  }

  for (final catchAll in [false, true]) {
    testWidgets(
        'saves a configured ${catchAll ? 'catch-all with detail' : 'custom violation label'}',
        (tester) async {
      final service = RecordingConductService();
      final label =
          catchAll ? 'Other conduct concerns' : 'Quiet hours disturbance';
      await open(tester, service, (group) async {
        expect(group, 'conduct_category');
        return [choice('new-option', label)];
      });
      await select(tester, label);
      await tester.enterText(
          find.widgetWithText(TextField, 'Case title'), 'Reported disturbance');
      await tester.enterText(
          find.widgetWithText(TextField, 'Incident description'),
          'Loud music was reported after quiet hours.');
      if (catchAll) {
        await tester.tap(find.text('Create draft'));
        await tester.pumpAndSettle();
        expect(service.category, isNull);
        await tester.enterText(
            find.widgetWithText(TextField, 'Please specify category'),
            'Repeated noise');
      }
      await tester.tap(find.text('Create draft'));
      await tester.pumpAndSettle();
      expect(service.category, label);
      expect(service.detail, catchAll ? 'Repeated noise' : null);
      expect(conductCategoryDisplayLabel(service.category!, service.detail),
          catchAll ? '$label — Repeated noise' : label);
      expect(find.byType(ConductCaseCreateDialog), findsNothing);
    });
  }

  testWidgets(
      'failed category loading blocks creation and retry loads current choices',
      (tester) async {
    final service = RecordingConductService();
    var fail = true;
    await open(tester, service, (_) async {
      if (fail) throw StateError('offline');
      return [choice('updated', 'Updated violation category')];
    });
    expect(find.text('Could not load choices.'), findsOneWidget);
    await tester.tap(find.text('Create draft'));
    await tester.pumpAndSettle();
    expect(find.text('Select an active case category.'), findsOneWidget);
    expect(service.category, isNull);
    fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    await select(tester, 'Updated violation category');
    expect(find.text('Updated violation category'), findsOneWidget);
  });
}
