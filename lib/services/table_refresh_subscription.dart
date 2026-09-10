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
  }) {
    _refresh = refresh;
    _debounceDuration = debounceDuration;

    var builder = SupabaseConfig.client.channel('refresh-$name');
    for (final table in tables) {
      builder = builder.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) => _triggerDebouncedRefresh(),
      );
    }
    channel = builder.subscribe();
  }

  late final RealtimeChannel channel;
  late final void Function() _refresh;
  late final Duration _debounceDuration;
  Timer? _debounceTimer;

  void _triggerDebouncedRefresh() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      _refresh();
    });
  }

  Future<void> dispose() async {
    _debounceTimer?.cancel();
    await SupabaseConfig.client.removeChannel(channel);
  }
}
