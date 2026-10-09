import 'package:carmelitas_dormitory_system/services/tenant_service.dart';
import 'package:carmelitas_dormitory_system/views/shared/room_transfer_page.dart';
import 'package:carmelitas_dormitory_system/views/shared/signature_pad_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const bed =
      AvailableBed(id: 'bed-2', room: '202', label: 'Bed B', floor: '2');
  testWidgets('proposal requires a destination and documented reason',
      (tester) async {
    RoomTransferDraft? result;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () async {
                      result = await showDialog<RoomTransferDraft>(
                          context: context,
                          builder: (_) =>
                              const RoomTransferProposalDialog(beds: [bed]));
                    },
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prepare amendment'));
    await tester.pump();
    expect(result, isNull);
    expect(find.byType(RoomTransferProposalDialog), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Room 202 / Bed B').last);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextField), ' Tenant requested a quieter room ');
    await tester.tap(find.text('Prepare amendment'));
    await tester.pumpAndSettle();
    expect(result!.bedId, 'bed-2');
    expect(result!.reason, 'Tenant requested a quieter room');
    expect(result!.effectiveOn, DateUtils.dateOnly(DateTime.now()));
  });
  testWidgets('amendment signature uses explicit room-transfer consent',
      (tester) async {
    const consent =
        'I agree to this room transfer and the unchanged rent and deposit.';
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: SignaturePadDialog(
                signerName: 'Maria',
                contractNumber: 'CTR-1 / room amendment',
                agreementText: consent))));
    expect(find.text(consent), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Confirm Signature'))
            .onPressed,
        isNull);
  });
  testWidgets('proposal remains usable on a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: RoomTransferProposalDialog(beds: [bed]))));
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(
        find.byType(TextField), 'Tenant requested this move');
    expect(tester.takeException(), isNull);
    expect(find.text('Prepare amendment'), findsOneWidget);
  });
}
