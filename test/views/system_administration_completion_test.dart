import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/models/staff_tenant_option.dart';
import 'package:carmelitas_dormitory_system/models/tenant_conduct_status.dart';
import 'package:carmelitas_dormitory_system/services/conduct_case_service.dart';
import 'package:carmelitas_dormitory_system/services/confidentiality_agreement_service.dart';
import 'package:carmelitas_dormitory_system/services/staff_conduct_queue_service.dart';
import 'package:carmelitas_dormitory_system/services/system_maintenance_service.dart';
import 'package:carmelitas_dormitory_system/views/shared/system_maintenance_page.dart';
import 'package:carmelitas_dormitory_system/views/shared/repeat_violation_tenants_page.dart';

ValueNotifier<AppUser?> session(UserRole role) => ValueNotifier(AppUser(
    id: role.name,
    name: role.name,
    email: '${role.name}@example.test',
    role: role));

class Maintenance extends SystemMaintenanceService {
  bool enabled = false, failSave = false;
  int reads = 0, backupCalls = 0;
  String message = 'Scheduled maintenance message';
  final saves = <bool>[];
  final restored = <String>[];
  final records = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> settings() async {
    reads++;
    return {
      'enabled': enabled,
      'message': message,
      'updated_at': '2026-10-19T00:00:00Z'
    };
  }

  @override
  Future<List<Map<String, dynamic>>> audit() async => [];
  @override
  Future<List<Map<String, dynamic>>> backups() async => List.of(records);
  @override
  Future<void> save(bool value, String text, String version) async {
    if (failSave) throw StateError('Conflicting settings');
    saves.add(value);
    enabled = value;
    message = text;
  }

  @override
  Future<void> backup() async {
    backupCalls++;
    records.add({'id': 'backup-1', 'created_at': '2026-10-19T00:00:00Z'});
  }

  @override
  Future<void> restore(String id) async {
    restored.add(id);
  }
}

class Queue extends StaffConductQueueService {
  int calls = 0;
  bool unavailable = false;
  @override
  Future<StaffConductQueueSnapshot> load() async {
    calls++;
    final date = DateTime.utc(2026, 10, 19);
    return StaffConductQueueSnapshot(
        const [
          StaffTenantOption(
              id: 'a', name: 'Tenant A', residencyStatus: 'active'),
          StaffTenantOption(
              id: 'b', name: 'Tenant B', residencyStatus: 'active'),
          StaffTenantOption(
              id: 'c', name: 'Tenant C', residencyStatus: 'active'),
        ],
        [
          for (final id in ['one', 'two', 'three'])
            ConductCaseRecord(
                id: id,
                tenantId: 'a',
                category: 'safety',
                title: 'Closed case',
                description: 'Closed reviewed incident',
                incidentAt: date,
                status: 'resolved',
                createdAt: date,
                updatedAt: date)
        ],
        unavailable
            ? null
            : const {
                'a': TenantConductStatus('a', 'repeated_violations', 2, 2),
                'b': TenantConductStatus('b', 'continuous_violations', 3, 3),
                'c': TenantConductStatus('c', 'no_confirmed', 0, 0),
              });
  }
}

void main() {
  test('confidentiality applies to tenants; guardian geofencing stays separate',
      () {
    expect(AgreementModule.confidentiality.includesAudience('tenant'), isTrue);
    expect(
        AgreementModule.confidentiality.includesAudience('guardian'), isFalse);
    expect(AgreementModule.geofencing.includesAudience('guardian'), isTrue);
    expect(
        AgreementModule.confidentiality.includesAudience('caretaker'), isFalse);
  });
  for (final width in [320.0, 1280.0]) {
    testWidgets('owner saves message without toggling mode at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final account = session(UserRole.owner), service = Maintenance();
      await tester.pumpWidget(MaterialApp(
          home: SystemMaintenancePage(service: service, session: account)));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byType(TextField), 'Updated maintenance notice');
      await tester.ensureVisible(find.text('Save message'));
      await tester.tap(find.text('Save message'));
      await tester.pumpAndSettle();
      expect(service.saves, [false]);
      expect(service.enabled, isFalse);
      expect(service.message, 'Updated maintenance notice');
      expect(find.text('Maintenance message saved.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      account.dispose();
    });
    testWidgets(
        'tenant register lists people once despite closed case history at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final account = session(UserRole.caretaker), queue = Queue();
      await tester.pumpWidget(MaterialApp(
          home: RepeatViolationTenantsPage(service: queue, session: account)));
      await tester.pumpAndSettle();
      expect(find.text('Tenant A'), findsOneWidget);
      expect(find.text('Tenant B'), findsOneWidget);
      expect(find.text('Tenant C'), findsNothing);
      await tester.tap(find.text('Continuous'));
      await tester.pumpAndSettle();
      expect(find.text('Tenant A'), findsNothing);
      expect(find.text('Tenant B'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'No match');
      await tester.pumpAndSettle();
      expect(find.text('Tenant B'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      account.dispose();
    });
  }
  testWidgets('owner creates a snapshot and explicitly confirms restore',
      (tester) async {
    final account = session(UserRole.owner), service = Maintenance();
    await tester.pumpWidget(MaterialApp(
        home: SystemMaintenancePage(service: service, session: account)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Create configuration backup'));
    await tester.tap(find.text('Create configuration backup'));
    await tester.pumpAndSettle();
    expect(service.backupCalls, 1);
    expect(find.text('Download'), findsOneWidget);
    await tester.ensureVisible(find.text('Restore'));
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    expect(service.restored, isEmpty);
    await tester.tap(find.widgetWithText(FilledButton, 'Restore'));
    await tester.pumpAndSettle();
    expect(service.restored, ['backup-1']);
    await tester.pumpWidget(const SizedBox());
    account.dispose();
  });
  testWidgets('caretaker can inspect maintenance without owner controls',
      (tester) async {
    final account = session(UserRole.caretaker), service = Maintenance();
    await tester.pumpWidget(MaterialApp(
        home: SystemMaintenancePage(service: service, session: account)));
    await tester.pumpAndSettle();
    expect(find.text('Maintenance mode: Off'), findsOneWidget);
    expect(find.text('Start maintenance'), findsNothing);
    expect(find.text('Save message'), findsNothing);
    expect(find.text('Create configuration backup'), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    await tester.pumpWidget(const SizedBox());
    account.dispose();
  });
  testWidgets('failed settings save does not show success or change mode',
      (tester) async {
    final account = session(UserRole.owner),
        service = Maintenance()..failSave = true;
    await tester.pumpWidget(MaterialApp(
        home: SystemMaintenancePage(service: service, session: account)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Start maintenance'));
    await tester.tap(find.text('Start maintenance'));
    await tester.pumpAndSettle();
    expect(service.enabled, isFalse);
    expect(
        find.textContaining('Could not confirm the action.'), findsOneWidget);
    expect(find.text('Maintenance started.'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    account.dispose();
  });
  testWidgets('tenant cannot load staff maintenance or tenant flag register',
      (tester) async {
    final account = session(UserRole.tenant),
        service = Maintenance(),
        queue = Queue();
    await tester.pumpWidget(MaterialApp(
        home: SystemMaintenancePage(service: service, session: account)));
    await tester.pumpAndSettle();
    expect(service.reads, 0);
    expect(find.text('Staff access required'), findsOneWidget);
    await tester.pumpWidget(MaterialApp(
        home: RepeatViolationTenantsPage(service: queue, session: account)));
    await tester.pumpAndSettle();
    expect(queue.calls, 0);
    expect(find.text('Tenant A'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    account.dispose();
  });
  testWidgets(
      'unavailable tracking is distinct from an empty flag register and retries',
      (tester) async {
    final account = session(UserRole.owner),
        queue = Queue()..unavailable = true;
    await tester.pumpWidget(MaterialApp(
        home: RepeatViolationTenantsPage(service: queue, session: account)));
    await tester.pumpAndSettle();
    expect(find.textContaining('could not be loaded'), findsOneWidget);
    expect(find.text('Tenant A'), findsNothing);
    queue.unavailable = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Tenant A'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    account.dispose();
  });
}
