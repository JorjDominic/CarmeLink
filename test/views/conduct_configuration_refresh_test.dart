import 'package:carmelitas_dormitory_system/core/widgets/configured_choice_field.dart';
import 'package:carmelitas_dormitory_system/core/widgets/staff_tenant_picker.dart';
import 'package:carmelitas_dormitory_system/models/staff_tenant_option.dart';
import 'package:carmelitas_dormitory_system/services/conduct_case_service.dart';
import 'package:carmelitas_dormitory_system/services/dormitory_configuration_service.dart';
import 'package:carmelitas_dormitory_system/views/shared/conduct_case_create_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CaptureCase extends ConductCaseService {
  String? savedCategory;
  DateTime? savedIncident;
  @override
  Future<String> createCase(
      {required String tenantId,
      required String category,
      String? categoryDetail,
      required String title,
      required String description,
      required DateTime incidentAt,
      required String sourceModule,
      String? sourceRecordId,
      String? sourceDetail}) async {
    savedCategory = category;
    savedIncident = incidentAt;
    return 'local-case';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    // Enables the real catch-up subscription timer; no remote project.
    await Supabase.initialize(
        url: 'http://127.0.0.1:1',
        publishableKey: 'local-fixture',
        realtimeClientOptions: const RealtimeClientOptions(
            disconnectOnEmptyChannelsAfter: Duration.zero),
        authOptions: const FlutterAuthClientOptions(
            autoRefreshToken: false,
            detectSessionInUri: false,
            localStorage: EmptyLocalStorage()));
  });
  tearDownAll(() async => Supabase.instance.dispose());

  for (final width in [390.0, 1200.0]) {
    testWidgets('conduct live choices and incident default at width $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final service = CaptureCase();
      DormitoryOption choice(String label) => DormitoryOption(
          id: 'quiet',
          groupKey: 'conduct_category',
          code: 'quiet',
          label: label,
          isActive: true,
          isSystem: false,
          sortOrder: 0);
      List<DormitoryOption> choices = [choice('Quiet hours')];
      final before = DateTime.now();
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Builder(
                  builder: (context) => TextButton(
                      onPressed: () => showDialog<void>(
                          context: context,
                          builder: (_) => ConductCaseCreateDialog(
                              service: service,
                              tenants: const [
                                StaffTenantOption(
                                    id: 'tenant',
                                    name: 'Test tenant',
                                    residencyStatus: 'active')
                              ],
                              categoryOptionsLoader: (_) async =>
                                  List.of(choices))),
                      child: const Text('Open'))))));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(StaffTenantPickerField));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Test tenant'));
      await tester.pumpAndSettle();
      Future<void> select(String label) async {
        final input = find.descendant(
            of: find.byType(ConfiguredChoiceField),
            matching: find.byType(InputDecorator));
        await tester.ensureVisible(input);
        await tester.tap(input);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ListTile, label));
        await tester.pumpAndSettle();
      }

      Future<void> catchUp() async {
        await tester.pump(const Duration(seconds: 30));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();
      }

      await select('Quiet hours');
      choices = [choice('Quiet hours disturbance')];
      await catchUp();
      expect(find.text('Quiet hours disturbance'), findsOneWidget);
      choices = [];
      await catchUp();
      await tester.ensureVisible(find.text('Create draft'));
      await tester.tap(find.text('Create draft'));
      await tester.pumpAndSettle();
      expect(service.savedCategory, isNull);
      expect(find.text('Select an active case category.'), findsOneWidget);
      choices = [choice('Quiet hours disturbance')];
      await catchUp();
      await select('Quiet hours disturbance');
      await tester.enterText(
          find.widgetWithText(TextField, 'Case title'), 'Reported disturbance');
      await tester.enterText(
          find.widgetWithText(TextField, 'Incident description'),
          'Loud music after the quiet hours.');
      await tester.ensureVisible(find.text('Create draft'));
      await tester.tap(find.text('Create draft'));
      await tester.pumpAndSettle();
      expect(service.savedCategory, 'Quiet hours disturbance');
      expect(service.savedIncident, isNotNull);
      expect(service.savedIncident!.isBefore(before), isFalse);
      expect(service.savedIncident!.isAfter(DateTime.now()), isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 7));
    });
  }
}
