import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';

class TableRefreshSubscription {
  TableRefreshSubscription(
      String name, Iterable<String> tables, void Function() refresh) {
    var builder = SupabaseConfig.client
        .channel('ui-refresh-$name-${DateTime.now().microsecondsSinceEpoch}');
    for (final table in tables) {
      builder = builder.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) => refresh(),
      );
    }
    channel = builder.subscribe();
  }

  late final RealtimeChannel channel;

  Future<void> dispose() => SupabaseConfig.client.removeChannel(channel);
}
