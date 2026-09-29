import '../core/config/supabase_config.dart';

class UserPreferencesService {
  const UserPreferencesService();

  Future<String> loadThemeMode() async {
    final response = await SupabaseConfig.client.rpc('get_my_user_preferences');
    final row = Map<String, dynamic>.from(response as Map);
    return row['theme_mode']?.toString() ?? 'light';
  }

  Future<void> saveThemeMode(String mode) async {
    await SupabaseConfig.client.rpc(
      'update_my_user_preferences',
      params: {'p_theme_mode': mode},
    );
  }
}
