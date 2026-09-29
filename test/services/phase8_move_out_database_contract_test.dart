import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Phase 8 migration keeps contract and occupancy closure as a handoff',
      () {
    final sql = File(
      'supabase/migrations/20260930001500_phase8_move_out_settlement.sql',
    ).readAsStringSync();
    final lower = sql.toLowerCase();

    for (final table in [
      'move_out_cases',
      'move_out_clearance_items',
      'move_out_deductions',
      'move_out_settlements',
    ]) {
      expect(lower.contains('create table public.$table'), isTrue);
    }

    for (final rpc in [
      'create_move_out_case',
      'schedule_move_out_final_inspection',
      'set_move_out_clearance_item',
      'set_move_out_deposit_received',
      'add_move_out_deduction',
      'review_move_out_deduction',
      'record_move_out_settlement_outcome',
      'acknowledge_move_out_settlement',
      'mark_move_out_ready_for_closure',
    ]) {
      expect(lower.contains('function public.$rpc'), isTrue, reason: rpc);
    }

    expect(lower.contains("'move_out','scheduled'"), isTrue);
    expect(lower.contains("status='settlement_completed'"), isTrue);
    expect(lower.contains("status='ready_for_closure'"), isTrue);
    expect(lower.contains("time zone 'asia/manila'"), isTrue);
    expect(lower.contains("status='proposed'"), isTrue);
    expect(lower.contains('before settlement'), isTrue);
    expect(lower.contains('move_out_refund_proofs'), isTrue);

    expect(
        RegExp(r'update\s+public\.tenant_contracts').hasMatch(lower), isFalse);
    expect(RegExp(r'update\s+public\.tenant_assignments').hasMatch(lower),
        isFalse);
    expect(
        RegExp(r'delete\s+from\s+public\.tenant_assignments').hasMatch(lower),
        isFalse);
    expect(RegExp(r'insert\s+into\s+public\.billing_charges').hasMatch(lower),
        isFalse);
  });
}
