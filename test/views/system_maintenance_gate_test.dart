import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';
import 'package:carmelitas_dormitory_system/services/system_maintenance_service.dart';
import 'package:carmelitas_dormitory_system/views/shared/system_maintenance_gate.dart';

class Availability extends SystemMaintenanceService {
  bool enabled = true, fail = false;
  Completer<Map<String, dynamic>>? pending;
  @override
  Future<Map<String, dynamic>> settings() async {
    if (fail) throw StateError('Offline');
    if (pending != null) return await pending!.future;
    return {'enabled': enabled, 'message': 'Scheduled system update'};
  }
}

AppUser user(String id, UserRole role) =>
    AppUser(id: id, name: id, email: '$id@example.test', role: role);

void main() {
  for (final width in [320.0, 1280.0]) {
    testWidgets(
        'maintenance blocks resident routes and retry restores access at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final session = ValueNotifier<AppUser?>(user('tenant', UserRole.tenant));
      final service = Availability();
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => SystemMaintenanceGate(
              service: service, session: session, child: child!),
          home: const Scaffold(body: Text('Resident workspace'))));
      await tester.pumpAndSettle();
      expect(find.text('Resident workspace'), findsNothing);
      expect(find.text('Scheduled system update'), findsOneWidget);
      expect(tester.takeException(), isNull);
      service.enabled = false;
      await tester.tap(find.text('Check again'));
      await tester.pumpAndSettle();
      expect(find.text('Resident workspace'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    });
  }
  testWidgets(
      'staff retain access and stale resident responses cannot cross sessions',
      (tester) async {
    final session = ValueNotifier<AppUser?>(user('tenant', UserRole.tenant));
    final service = Availability()..pending = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(MaterialApp(
        home: SystemMaintenanceGate(
            session: session,
            service: service,
            child: const Text('Workspace'))));
    session.value = user('owner', UserRole.owner);
    await tester.pump();
    service.pending!.complete({'enabled': true, 'message': 'Old response'});
    await tester.pumpAndSettle();
    expect(find.text('Workspace'), findsOneWidget);
    expect(find.text('Old response'), findsNothing);
    session.value = user('caretaker', UserRole.caretaker);
    await tester.pumpAndSettle();
    expect(find.text('Workspace'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
  testWidgets(
      'guardian availability failure shows retry without exposing workspace',
      (tester) async {
    final session =
        ValueNotifier<AppUser?>(user('guardian', UserRole.guardian));
    final service = Availability()..fail = true;
    await tester.pumpWidget(MaterialApp(
        home: SystemMaintenanceGate(
            session: session,
            service: service,
            child: const Text('Guardian workspace'))));
    await tester.pumpAndSettle();
    expect(find.text('Unable to check system availability'), findsOneWidget);
    expect(find.text('Guardian workspace'), findsNothing);
    service.fail = false;
    service.enabled = false;
    await tester.tap(find.text('Check again'));
    await tester.pumpAndSettle();
    expect(find.text('Guardian workspace'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
}
