import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';

/// Subscribes to Postgres table changes with built-in debouncing
/// to prevent query cascades and Supabase resource exhaustion during batch changes.
class TableRefreshSubscription {
  TableRefreshSubscription(
    String name,
    Iterable<String> tables,
    void Function() refresh, {
    Duration debounceDuration = const Duration(milliseconds: 500),
    Duration? catchUpInterval = const Duration(seconds: 30),
  }) {
    _refresh = refresh;
    _debounceDuration = debounceDuration;
    _catchUpInterval = catchUpInterval;

    try {
      final client = SupabaseConfig.clientSafe;
      if (client == null) return;

      final expandedTables = <String>{};
      for (final table in tables) {
        expandedTables.addAll(_expandedTables(table));
      }

      var builder = client.channel('refresh-$name');
      for (final table in expandedTables) {
        builder = builder.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          callback: (_) => _triggerDebouncedRefresh(),
        );
      }
      channel = builder.subscribe();
      final catchUpInterval = _catchUpInterval;
      if (catchUpInterval != null) {
        _catchUpTimer = Timer.periodic(
          catchUpInterval,
          (_) => _triggerDebouncedRefresh(),
        );
      }
    } catch (_) {
      // Ignored when offline or uninitialized
    }
  }

  static Iterable<String> _expandedTables(String table) sync* {
    yield table;

    // The app now reads billing from billing_charge_summaries, whose live
    // rows are backed by billing_charges and payment_transactions. Keep the
    // legacy payments listener for compatibility, but also listen to the
    // authoritative billing tables so older page subscriptions stay live.
    if (table == 'payments') {
      yield 'billing_charges';
      yield 'payment_transactions';
      yield 'billing_charge_actions';
    }
  }

  RealtimeChannel? channel;
  late final void Function() _refresh;
  late final Duration _debounceDuration;
  late final Duration? _catchUpInterval;
  Timer? _debounceTimer;
  Timer? _catchUpTimer;

  void _triggerDebouncedRefresh() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      _refresh();
    });
  }

  Future<void> dispose() async {
    _debounceTimer?.cancel();
    _catchUpTimer?.cancel();
    final c = channel;
    if (c != null) {
      try {
        final client = SupabaseConfig.clientSafe;
        if (client != null) {
          await client.removeChannel(c);
        }
      } catch (_) {}
    }
  }
}
