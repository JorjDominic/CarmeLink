import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/web/demo/demo_catalog.dart';
import 'package:carmelitas_dormitory_system/web/demo/demo_store.dart';

void main() {
  late DemoStore store;

  setUp(() => store = DemoStore());
  tearDown(() => store.dispose());

  test('seeds ten rooms and fictional resident records', () {
    expect(store.count('rooms'), 10);
    expect(store.count('tenants'), 3);
    expect(store.capacity, 40);
    expect(store.occupancy, 3);
  });

  test('creates, reads, edits and deletes a module record', () {
    final before = store.count('announcements');
    expect(store.save('announcements', {
      'name': 'Sample notice', 'audience': 'All',
      'details': 'Demo notice', 'date': '2026-09-20', 'status': 'Draft',
    }), isNull);
    expect(store.count('announcements'), before + 1);
    final row = store.rows('announcements').last;
    expect(store.lookup('announcements', row['id']!)?['name'], 'Sample notice');
    expect(store.save('announcements', {...row, 'name': 'Revised notice'},
      editingId: row['id']), isNull);
    expect(store.lookup('announcements', row['id']!)?['name'], 'Revised notice');
    expect(store.delete('announcements', row['id']!), isNull);
    expect(store.count('announcements'), before);
  });

  test('payment review updates status and dashboard total', () {
    final pending = store.rows('payments').first;
    expect(store.paymentReviews, 1);
    expect(store.verifiedIncome, 3500);
    expect(store.updateStatus('payments', pending['id']!, 'Verified'), isNull);
    expect(store.paymentReviews, 0);
    expect(store.verifiedIncome, 7000);
  });

  test('room capacity cannot shrink below existing occupants', () {
    final room = store.rows('rooms').first;
    final error = store.save('rooms', {...room, 'capacity': '1'},
      editingId: room['id']);
    expect(error, contains('capacity'));
  });

  test('room cannot be removed while assigned to tenant', () {
    final room = store.rows('rooms').first;
    expect(store.delete('rooms', room['id']!), contains('linked'));
  });

  test('duplicate active bed assignments rejected', () {
    final resident = store.rows('tenants').first;
    final other = store.rows('tenants')[1];
    expect(store.save('tenants', {...other,
      'room': resident['room']!, 'bed': resident['bed']!},
      editingId: other['id']), contains('already assigned'));
  });

  test('invalid emails and negative monetary values rejected', () {
    final guardian = store.rows('guardians').first;
    expect(store.save('guardians', {...guardian, 'email': 'invalid'},
      editingId: guardian['id']), contains('valid email'));
    final payment = store.rows('payments').first;
    expect(store.save('payments', {...payment, 'amount': '-5'},
      editingId: payment['id']), contains('non-negative'));
  });

  test('contract end date must follow start date', () {
    final contract = store.rows('contracts').first;
    expect(store.save('contracts', {...contract,
      'start': '2027-01-01', 'end': '2026-01-01'},
      editingId: contract['id']), contains('end'));
  });

  test('status changes must use valid workflow option', () {
    final request = store.rows('curfew').first;
    expect(store.updateStatus('curfew', request['id']!, 'Approved'), isNull);
    expect(store.lookup('curfew', request['id']!)?['status'], 'Approved');
    expect(store.updateStatus('curfew', request['id']!, 'Anything'), 'Invalid status.');
  });

  test('caretaker catalogue excludes owner-only records and analytics', () {
    final caretaker = DemoCatalog.forRole('Caretaker');
    expect(caretaker.any((module) => module.ownerOnly), isFalse);
    expect(caretaker.any((module) => module.id == 'payments'), isTrue);
    expect(caretaker.any((module) => module.id == 'confidential'), isFalse);
    expect(DemoCatalog.forRole('Owner').length, DemoCatalog.modules.length);
  });

  test('CSV properly escapes commas and quotes', () {
    final notice = store.rows('announcements').first;
    expect(store.save('announcements', {...notice,
      'name': 'A "quoted", note'}, editingId: notice['id']), isNull);
    expect(store.exportCsv('announcements'), contains('"A ""quoted"", note"'));
  });

  test('reset clears demo changes and restores initial values', () {
    final payment = store.rows('payments').first;
    store.updateStatus('payments', payment['id']!, 'Verified');
    expect(store.paymentReviews, 0);
    store.reset();
    expect(store.paymentReviews, 1);
    expect(store.count('rooms'), 10);
  });
}
