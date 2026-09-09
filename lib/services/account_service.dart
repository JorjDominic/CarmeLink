import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';

class AccountService {
  const AccountService();

  Future<List<Map<String, dynamic>>> listAccounts() async {
    final rows = await SupabaseConfig.client
        .from('profiles')
        .select('id, full_name, role, phone, created_at')
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> createAccount({
    required String fullName,
    required String email,
    required String phone,
    required String role,
    required String temporaryPassword,
  }) async {
    final response = await SupabaseConfig.client.functions.invoke(
      'create-user',
      body: {
        'full_name': fullName.trim(),
        'email': email.trim().toLowerCase(),
        'phone': phone.trim(),
        'role': role,
        'password': temporaryPassword,
      },
    );
    if (response.status < 200 || response.status >= 300) {
      final data = response.data;
      throw FunctionException(
        status: response.status,
        details: data,
        reasonPhrase: data is Map ? data['error']?.toString() : null,
      );
    }
  }
}
