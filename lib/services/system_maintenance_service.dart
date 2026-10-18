import '../core/config/supabase_config.dart';

class SystemMaintenanceService {
  const SystemMaintenanceService();

  Future<Map<String, dynamic>> settings() async => await SupabaseConfig.client
      .from('system_maintenance_settings')
      .select()
      .single();

  Future<void> save(bool enabled, String message, String version) async {
    await SupabaseConfig.client.rpc('set_system_maintenance', params: {
      'p_enabled': enabled,
      'p_message': message,
      'p_expected_updated_at': version,
    });
  }

  Future<List<Map<String, dynamic>>> audit() async =>
      await SupabaseConfig.client
          .from('system_maintenance_audit')
          .select()
          .order('created_at', ascending: false)
          .limit(100);

  Future<List<Map<String, dynamic>>> backups() async =>
      await SupabaseConfig.client
          .from('system_configuration_backups')
          .select('id,created_at,created_by')
          .order('created_at', ascending: false)
          .limit(50);

  Future<void> backup() async {
    await SupabaseConfig.client.rpc('create_system_configuration_backup');
  }

  Future<Map<String, dynamic>> backupPayload(String id) async =>
      Map<String, dynamic>.from((await SupabaseConfig.client
          .from('system_configuration_backups')
          .select('payload')
          .eq('id', id)
          .single())['payload'] as Map);

  Future<void> restore(String id) async {
    await SupabaseConfig.client.rpc('restore_system_configuration_backup',
        params: {'p_backup_id': id});
  }
}
