// Real Supabase workflow; skipped unless an explicitly disposable local stack is configured.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:carmelitas_dormitory_system/core/utils/contract_occupancy_policy.dart';
import 'package:carmelitas_dormitory_system/services/contract_service.dart';
import 'package:carmelitas_dormitory_system/services/contract_document_service.dart';
import 'package:carmelitas_dormitory_system/services/contract_onboarding_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final env = Platform.environment;
  final ready = env['PHASE2_STAGING_DISPOSABLE'] == 'yes' &&
      [
        'PHASE2_STAGING_URL',
        'PHASE2_STAGING_KEY',
        'PHASE2_STAGING_PASSWORD',
        'PHASE2_STAGING_MANIFEST'
      ].every((key) => (env[key] ?? '').isNotEmpty);
  test(
      'solo and two/three/four occupants complete real signing, storage and activation',
      () async {
    final url = Uri.parse(env['PHASE2_STAGING_URL']!);
    expect(['127.0.0.1', 'localhost', '::1'], contains(url.host),
        reason:
            'Only an explicitly disposable local Supabase stack is allowed');
    final manifest =
        jsonDecode(File(env['PHASE2_STAGING_MANIFEST']!).readAsStringSync())
            as Map;
    expect(manifest['purpose'], 'phase2-disposable-validation');
    final groups = (manifest['groups'] as List).cast<Map>();
    expect(
        groups.map((g) => (g['tenants'] as List).length).toSet(), {1, 2, 3, 4});
    final previousOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
        url: url.toString(),
        publishableKey: env['PHASE2_STAGING_KEY']!,
        authOptions: FlutterAuthClientOptions(
            autoRefreshToken: false,
            detectSessionInUri: false,
            localStorage: EmptyLocalStorage()));
    final client = Supabase.instance.client;
    const contracts = ContractService();
    const documents = ContractDocumentService();
    const onboarding = ContractOnboardingService();
    Future<void> login(String email) async {
      await client.auth.signOut();
      await client.auth.signInWithPassword(
          email: email, password: env['PHASE2_STAGING_PASSWORD']!);
    }

    try {
      await login(manifest['owner_email'] as String);
      for (final group in groups) {
        final room = await client
            .from('rooms')
            .select('room_number')
            .eq('id', group['room_id'])
            .single();
        expect(room['room_number'].toString().startsWith('PHASE2-QA-'), isTrue);
        final tenants = (group['tenants'] as List).cast<Map>();
        for (final tenant in tenants) {
          final profile = await client
              .from('profiles')
              .select('full_name,role')
              .eq('id', tenant['id'])
              .single();
          expect(profile['role'], 'tenant');
          expect(
              profile['full_name'].toString().startsWith('Phase2 QA '), isTrue);
          final old = await client
              .from('tenant_contracts')
              .select('id')
              .eq('tenant_id', tenant['id']);
          expect(old, isEmpty,
              reason:
                  'Use fresh disposable actors; never existing tenant records');
        }
        final todayUtc8 = DateTime.now().toUtc().add(const Duration(hours: 8));
        final start = DateTime(todayUtc8.year, todayUtc8.month, todayUtc8.day);
        final drafts = await contracts.prepareOccupancy(
            roomId: group['room_id'] as String,
            mode: tenants.length == 1 ? 'solo' : 'shared',
            totalRentCents: 600000,
            members: [
              for (final tenant in tenants)
                {
                  'tenant_id': tenant['id'],
                  'bed_id': tenant['bed_id'],
                  'security_deposit': '0.00'
                }
            ],
            startsOn: start,
            endsOn: DateTime(start.year, start.month + 2, start.day - 1),
            notes: 'Disposable Phase2 QA workflow');
        expect(drafts.length, tenants.length);
        for (final draft in drafts) {
          await expectLater(contracts.activateContract(draft.id),
              throwsA(isA<PostgrestException>()));
          final rejected = await client
              .from('tenant_contracts')
              .select('status')
              .eq('id', draft.id)
              .single();
          expect(rejected['status'], 'draft');
          expect(
              await client
                  .from('billing_charges')
                  .select('id')
                  .eq('contract_id', draft.id),
              isEmpty);
          final generated = await documents.generateContract(draft);
          expect(String.fromCharCodes(generated.bytes.take(4)), '%PDF');
          expect(draft.occupancySnapshot!['room_number'], room['room_number']);
          final bytes = await _qaSignature();
          for (final requirement
              in await onboarding.listRequirements(draft.id)) {
            if (!requirement.isRequired) continue;
            final submitted = await onboarding.submitRequirement(
                requirement: requirement,
                filename: 'phase2-qa-document.png',
                mimeType: 'image/png',
                bytes: bytes,
                physicalCopyReceived: true,
                signatureCount: 3);
            await onboarding.reviewRequirement(
                requirementId: submitted.id,
                approve: true,
                notes: 'Disposable QA document reviewed');
          }
          final tenant = tenants.firstWhere((t) => t['id'] == draft.tenantId);
          await login(tenant['email'] as String);
          await onboarding.submitElectronicSignature(
              contractId: draft.id, signatureBytes: bytes);
          await expectLater(contracts.activateContract(draft.id),
              throwsA(isA<PostgrestException>()));
          await login(manifest['owner_email'] as String);
          final signer = (await onboarding.listSigners(draft.id))
              .firstWhere((s) => s.role == 'tenant');
          await onboarding.updateSigner(
              signer: signer,
              status: 'verified',
              signerName: tenant['name'] as String,
              notes: 'Disposable QA signature reviewed');
          await onboarding.submitOwnerElectronicSignature(
              contractId: draft.id, signatureBytes: await _qaSignature());
          final lessor = (await onboarding.listSigners(draft.id))
              .firstWhere((s) => s.role == 'lessor');
          await onboarding.updateSigner(
              signer: lessor,
              status: 'verified',
              signerName: manifest['owner_name'] as String,
              notes: 'Disposable QA owner signature reviewed');
          await documents.finalizeDigitalExecution(draft);
          final signed = (await documents.listDocuments(draft.id))
              .where((d) => d.isSigned)
              .single;
          expect(signed.reviewStatus, 'verified');
          expect(
              await documents.downloadDocument(signed.storagePath), isNotEmpty);
          final active = await contracts.activateContract(draft.id);
          expect(active.isActive, isTrue);
          final shares = allocateContractRent(
              600000, drafts.map((d) => d.tenantId).toList());
          expect((active.monthlyRent * 100).round(), shares[draft.tenantId]);
          final bills = await client
              .from('billing_charges')
              .select('original_amount,period_start')
              .eq('contract_id', draft.id)
              .eq('category', 'rent');
          expect(bills, isNotEmpty);
          expect(
              bills.every((b) =>
                  ((b['original_amount'] as num) * 100).round() ==
                  shares[draft.tenantId]),
              isTrue);
          expect(
              bills.map((b) => b['period_start']).toSet().length, bills.length);
          final assignment = await client
              .from('tenant_assignments')
              .select('bed_space_id')
              .eq('tenant_id', draft.tenantId)
              .eq('status', 'active')
              .single();
          expect(assignment['bed_space_id'], tenant['bed_id']);
        }
      }
    } finally {
      await client.auth.signOut();
      await Supabase.instance.dispose();
      HttpOverrides.global = previousOverrides;
      // Keep all test contracts, evidence and bills for review. No history deletion.
    }
  },
      skip: ready
          ? false
          : 'PENDING EXTERNAL VERIFICATION: disposable local Supabase Auth/Storage fixture not configured',
      timeout: const Timeout(Duration(minutes: 10)));
}

Future<Uint8List> _qaSignature() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawColor(const ui.Color(0xFFFFFFFF), ui.BlendMode.src);
  final paint = ui.Paint()
    ..color = const ui.Color(0xFF202020)
    ..strokeWidth = 3
    ..style = ui.PaintingStyle.stroke;
  final path = ui.Path()
    ..moveTo(10, 65)
    ..quadraticBezierTo(30, 5, 45, 60)
    ..lineTo(75, 25)
    ..quadraticBezierTo(100, 70, 140, 30);
  canvas.drawPath(path, paint);
  final picture = recorder.endRecording();
  final image = await picture.toImage(180, 90);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}
