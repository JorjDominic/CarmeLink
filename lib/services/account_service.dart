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
    try {
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
        throw AccountCreationException(_messageFrom(response.data));
      }
    } on FunctionException catch (error) {
      throw AccountCreationException(_messageFrom(error.details));
    }
  }

  String _messageFrom(dynamic details) {
    if (details is Map && details['error'] != null) {
      return details['error'].toString();
    }
    if (details is String && details.trim().isNotEmpty) return details;
    return 'The account could not be created. Please try again.';
  }
}

class AccountCreationException implements Exception {
  const AccountCreationException(this.message);
  final String message;

  @override
  String toString() => message;
}
