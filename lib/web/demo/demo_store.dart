import 'package:flutter/foundation.dart';
import 'demo_catalog.dart';

/// Isolated, fictional local data. Nothing in this file calls a remote service.
/// Deliberately memory-only: reload resets the sample data and clears edits.
class DemoStore extends ChangeNotifier {
  DemoStore() { reset(); }

  final Map<String, List<Map<String, String>>> _tables = {};
  int _counter = 0;

  List<Map<String, String>> rows(String module) =>
      List<Map<String, String>>.unmodifiable(
        (_tables[module] ?? <Map<String, String>>[])
            .map((record) => Map<String, String>.unmodifiable(record)));

  int count(String module) => _tables[module]?.length ?? 0;

  Map<String, String>? lookup(String module, String id) {
    for (final row in _tables[module] ?? <Map<String, String>>[]) {
      if (row['id'] == id) return Map<String, String>.unmodifiable(row);
    }
    return null;
  }

  String label(String module, String id) =>
      lookup(module, id)?['name'] ?? (id.isEmpty ? 'Not assigned' : 'Unknown (removed)');

  int get occupancy => rows('tenants')
      .where((r) => r['status'] == 'Active' && (r['room'] ?? '').isNotEmpty)
      .length;

  int get capacity => rows('rooms').fold<int>(
      0, (total, row) => total + (int.tryParse(row['capacity'] ?? '') ?? 0));

  int occupiedIn(String roomId, {String? exceptId}) => rows('tenants')
      .where((r) => r['room'] == roomId && r['status'] == 'Active' && r['id'] != exceptId)
      .length;

  double get verifiedIncome => rows('payments')
      .where((r) => r['status'] == 'Verified')
      .fold<double>(0, (sum, r) => sum + (double.tryParse(r['amount'] ?? '') ?? 0));

  double get expenses => rows('expenses')
      .fold<double>(0, (sum, r) => sum + (double.tryParse(r['amount'] ?? '') ?? 0));

  int get paymentReviews => rows('payments')
      .where((r) => r['status'] == 'Pending verification').length;

  int get maintenanceOpen => rows('maintenance')
      .where((r) => r['status'] != 'Closed' && r['status'] != 'Resolved').length;

  void reset() {
    _counter = 0;
    _tables.clear();
    for (final module in DemoCatalog.modules) {
      _tables[module.id] = [];
    }
    for (var number = 1; number <= 10; number++) {
      _seed('rooms', {'name': 'Room ${number.toString().padLeft(2, '0')}',
        'floor': number <= 5 ? 'Ground' : 'Second',
        'capacity': '4', 'status': 'Open', 'notes': 'Sample bed-space layout'});
    }
    final room1 = rows('rooms').first['id']!;
    final room2 = rows('rooms')[1]['id']!;
    final guardian1 = _seed('guardians', {'name': 'Sample Guardian A',
      'email': 'guardian.a@example.test', 'phone': '09000000001',
      'relationship': 'Mother'});
    final guardian2 = _seed('guardians', {'name': 'Sample Guardian B',
      'email': 'guardian.b@example.test', 'phone': '09000000002',
      'relationship': 'Father'});
    final tenant1 = _seed('tenants', {'name': 'Demo Resident A',
      'email': 'resident.a@example.test', 'phone': '09000000101', 'room': room1,
      'bed': '1', 'guardian': guardian1, 'status': 'Active'});
    final tenant2 = _seed('tenants', {'name': 'Demo Resident B',
      'email': 'resident.b@example.test', 'phone': '09000000102', 'room': room1,
      'bed': '2', 'guardian': guardian2, 'status': 'Active'});
    _seed('tenants', {'name': 'Demo Resident C', 'email': 'resident.c@example.test',
      'phone': '09000000103', 'room': room2, 'bed': '1',
      'guardian': guardian1, 'status': 'Active'});
    _seed('accounts', {'name': 'Demo Owner', 'email': 'owner@example.test',
      'role': 'Owner', 'status': 'Active'});
    _seed('accounts', {'name': 'Demo Caretaker', 'email': 'caretaker@example.test',
      'role': 'Caretaker', 'status': 'Active'});
    _seed('payments', {'name': 'Sample September rent', 'tenant': tenant1,
      'category': 'Rent', 'amount': '3500', 'due': '2026-09-25',
      'status': 'Pending verification', 'reference': 'DEMO-001', 'notes': ''});
    _seed('payments', {'name': 'Sample August rent', 'tenant': tenant2,
      'category': 'Rent', 'amount': '3500', 'due': '2026-08-25',
      'status': 'Verified', 'reference': 'DEMO-002', 'notes': ''});
    _seed('utilities', {'name': 'September electricity', 'room': room1,
      'type': 'Electricity', 'amount': '800', 'due': '2026-09-30', 'status': 'Due'});
    _seed('maintenance', {'name': 'Sample faucet issue', 'tenant': tenant1,
      'location': 'Room 01 bathroom', 'priority': 'Medium',
      'details': 'Demonstration issue; not a real report.',
      'assignee': 'Demo caretaker', 'status': 'Pending'});
    _seed('announcements', {'name': 'Welcome to the demo', 'audience': 'All',
      'details': 'This announcement is sample content only.',
      'date': '2026-09-20', 'status': 'Published'});
    _seed('curfew', {'name': 'Example late return', 'tenant': tenant2,
      'type': 'Late return', 'date': '2026-09-21', 'return': '22:00',
      'details': 'Sample request', 'status': 'Pending'});
    _seed('presence', {'name': 'Manual presence entry', 'tenant': tenant1,
      'location': 'Inside', 'time': '2026-09-20 15:00', 'source': 'Manual demo'});
    _seed('gate', {'name': 'Sample gate log', 'tenant': tenant1,
      'direction': 'Entry', 'time': '2026-09-20 14:55', 'notes': 'Demo entry'});
    _seed('visitors', {'name': 'Example Visitor', 'tenant': tenant1,
      'relationship': 'Family', 'date': '2026-09-23', 'status': 'Pending'});
    _seed('confidential', {'name': 'Sample private concern', 'tenant': tenant1,
      'details': 'Fictional report. Owner access only.',
      'status': 'New', 'notes': ''});
    _seed('discipline', {'name': 'Example incident', 'tenant': tenant2,
      'date': '2026-09-19', 'details': 'Fictional incident', 'status': 'Open'});
    _seed('appeals', {'name': 'Example appeal', 'tenant': tenant2,
      'details': 'Sample appeal statement', 'date': '2026-09-20',
      'status': 'Pending'});
    _seed('contracts', {'name': 'Sample tenancy agreement', 'tenant': tenant1,
      'start': '2026-08-01', 'end': '2027-07-31', 'amount': '3500',
      'status': 'Active'});
    _seed('expenses', {'name': 'Sample supplies', 'category': 'Supplies',
      'amount': '450', 'date': '2026-09-18', 'notes': 'Demo only'});
    _seed('messages', {'name': 'Welcome message', 'recipient': tenant1,
      'details': 'Sample local message; not delivered.',
      'date': '2026-09-20', 'status': 'Draft'});
    _seed('notifications', {'name': 'Sample curfew alert',
      'guardian': guardian1, 'tenant': tenant1, 'type': 'Curfew',
      'details': 'Sample guardian alert; not delivered.', 'status': 'Draft'});
    _seed('contacts', {'name': 'Example emergency contact',
      'relationship': 'Emergency contact', 'phone': '09000009999',
      'notes': 'Placeholder — replace with verified contact.'});
    _seed('inquiries', {'name': 'Sample prospective tenant',
      'email': 'inquiry@example.test', 'phone': '09000000202',
      'details': 'Would like to schedule a visit (fictional).', 'status': 'New'});
    notifyListeners();
  }

  String _seed(String module, Map<String, String> values) {
    final id = '${module}_${++_counter}';
    _tables[module]!.add({'id': id, ...values});
    return id;
  }

  /// Returns a validation message; null means the operation may proceed.
  String? validate(String module, Map<String, String> input, {String? editingId}) {
    final spec = DemoCatalog.byId(module);
    for (final field in spec.fields) {
      final value = (input[field.key] ?? '').trim();
      if (field.isRequired && value.isEmpty) return '${field.label} is required.';
      if (value.isEmpty) continue;
      if (field.kind == DemoFieldKind.email &&
          !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
        return 'Enter a valid email address.';
      }
      if (field.kind == DemoFieldKind.number &&
          (double.tryParse(value) == null || double.parse(value) < 0)) {
        return '${field.label} must be a non-negative number.';
      }
      if (field.kind == DemoFieldKind.date && DateTime.tryParse(value) == null) {
        return '${field.label} needs a valid date.';
      }
      if (field.kind == DemoFieldKind.choice && !field.options.contains(value)) {
        return 'Choose a valid ${field.label.toLowerCase()}.';
      }
      if (field.kind == DemoFieldKind.reference &&
          lookup(field.reference!, value) == null) {
        return 'Select an existing ${field.label.toLowerCase()}.';
      }
    }
    if (module == 'rooms') {
      final capacity = int.tryParse(input['capacity'] ?? '') ?? 0;
      if (capacity < 1 || capacity > 4) return 'Room capacity must be 1–4 beds.';
      if (editingId != null && capacity < occupiedIn(editingId)) {
        return 'Cannot reduce capacity below the current number of residents.';
      }
      if (editingId != null && input['status'] != 'Open' &&
          occupiedIn(editingId) > 0) {
        return 'Move active residents before closing a room.';
      }
      if (rows('rooms').any((r) => r['name']!.toLowerCase() ==
          input['name']!.trim().toLowerCase() && r['id'] != editingId)) {
        return 'Room number already exists.';
      }
    }
    if (module == 'tenants') {
      final roomId = input['room'] ?? '';
      final bed = input['bed'] ?? '';
      if (roomId.isEmpty != bed.isEmpty) return 'Choose both a room and bed, or neither.';
      if (roomId.isNotEmpty && input['status'] == 'Active') {
        final room = lookup('rooms', roomId)!;
        if (room['status'] != 'Open') return 'This room is not open for assignment.';
        if (int.parse(bed) > int.parse(room['capacity']!)) {
          return 'Bed number exceeds room capacity.';
        }
        if (occupiedIn(roomId, exceptId: editingId) >= int.parse(room['capacity']!)) {
          return 'Room has reached its capacity.';
        }
        if (rows('tenants').any((r) => r['id'] != editingId &&
            r['status'] == 'Active' && r['room'] == roomId && r['bed'] == bed)) {
          return 'That bed is already assigned.';
        }
      }
      if (rows('tenants').any((r) => r['email']?.toLowerCase() ==
          input['email']?.toLowerCase() && r['id'] != editingId)) {
        return 'Tenant email already exists.';
      }
    }
    if (module == 'contracts') {
      final start = DateTime.tryParse(input['start'] ?? '');
      final end = DateTime.tryParse(input['end'] ?? '');
      if (start != null && end != null && end.isBefore(start)) {
        return 'Contract end cannot precede its start date.';
      }
    }
    if (module == 'accounts' && rows('accounts').any((r) =>
        r['email']?.toLowerCase() == input['email']?.toLowerCase() && r['id'] != editingId)) {
      return 'Account email already exists.';
    }
    return null;
  }

  /// Only call after UI role checks; this is a local demo, not authorization.
  String? save(String module, Map<String, String> values, {String? editingId}) {
    final issue = validate(module, values, editingId: editingId);
    if (issue != null) return issue;
    final list = _tables[module]!;
    if (editingId == null) {
      _seed(module, values);
    } else {
      final index = list.indexWhere((r) => r['id'] == editingId);
      if (index < 0) return 'Record is no longer available.';
      list[index] = {'id': editingId, ...values};
    }
    notifyListeners();
    return null;
  }

  String? delete(String module, String id) {
    if (lookup(module, id) == null) return 'Record is already missing.';
    for (final spec in DemoCatalog.modules) {
      for (final field in spec.fields) {
        if (field.reference == module && rows(spec.id).any((row) => row[field.key] == id)) {
          return 'This record is linked to ${spec.title.toLowerCase()}. Remove or reassign its links first.';
        }
      }
    }
    _tables[module]!.removeWhere((r) => r['id'] == id);
    notifyListeners();
    return null;
  }

  String? updateStatus(String module, String id, String status) {
    final spec = DemoCatalog.byId(module);
    if (!spec.statusOptions.contains(status)) return 'Invalid status.';
    final old = lookup(module, id);
    if (old == null) return 'Record not found.';
    return save(module, {...old, 'status': status}, editingId: id);
  }

  String exportCsv(String module) {
    final spec = DemoCatalog.byId(module);
    final keys = ['id', ...spec.fields.map((f) => f.key)];
    String cell(String raw) => '"${raw.replaceAll('"', '""')}"';
    return [
      keys.map(cell).join(','),
      ...rows(module).map((row) => keys.map((key) => cell(row[key] ?? '')).join(',')),
    ].join('\r\n');
  }
}
