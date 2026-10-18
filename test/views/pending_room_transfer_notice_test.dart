import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/services/room_transfer_service.dart';
import 'package:carmelitas_dormitory_system/views/shared/pending_room_transfer_notice.dart';

RoomTransfer transfer(String status, {bool acknowledged = false}) =>
    RoomTransfer({
      'id': 'transfer',
      'tenant_id': 'tenant',
      'status': status,
      'source_room': '101',
      'source_bed': 'Bed A',
      'destination_room': '202',
      'destination_bed': 'Bed B',
      'effective_on': '2026-10-20',
      'reason': 'A quieter room requested by the tenant',
      'document_sha256': 'hash',
      'room_transfer_notice_acknowledgments': acknowledged
          ? [
              {'tenant_id': 'tenant', 'document_sha256': 'hash'}
            ]
          : [],
    });

class Transfers extends RoomTransferService {
  bool fail = false;
  List<RoomTransfer> rows = [];
  @override
  Future<List<RoomTransfer>> list({String? tenantId}) async {
    if (fail) throw StateError('Offline');
    return rows;
  }
}

void main() {
  test('acknowledgment is tied to tenant and current amendment', () {
    final t = transfer('awaiting_signatures', acknowledged: true);
    expect(t.noticeAcknowledged, true);
    t.row['room_transfer_notice_acknowledgments'] = {
      'tenant_id': 'tenant',
      'document_sha256': 'hash'
    };
    expect(t.noticeAcknowledged, true);
    t.row['document_sha256'] = 'different';
    expect(t.noticeAcknowledged, false);
  });
  for (final width in [320.0, 1280.0]) {
    testWidgets('published transfers remain visible at $width', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final service = Transfers()
        ..rows = [
          transfer('draft'),
          transfer('awaiting_signatures'),
          transfer('completed'),
          transfer('cancelled')
        ];
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: PendingRoomTransferNotice(
                      tenantId: 'tenant', service: service)))));
      await tester.pumpAndSettle();
      expect(find.text('Room transfer awaiting your review'), findsOneWidget);
      expect(find.text('Review room transfer'), findsOneWidget);
      expect(find.text('101 / Bed A → 202 / Bed B'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'failed notice lookup offers retry instead of claiming no pending move',
      (tester) async {
    final service = Transfers()..fail = true;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: PendingRoomTransferNotice(
                tenantId: 'tenant', service: service))));
    await tester.pumpAndSettle();
    expect(find.text('Could not check room transfer notices.'), findsOneWidget);
    service.fail = false;
    service.rows = [transfer('awaiting_signatures', acknowledged: true)];
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Room transfer awaiting signatures'), findsOneWidget);
  });
}
