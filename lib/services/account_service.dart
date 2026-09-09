import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';

class AccountService {
  const AccountService();

  Future<List<Map<String, dynamic>>> listAccounts() async {
    final data = await _invokeManage({'action': 'list'});
    return List<Map<String, dynamic>>.from(data['accounts'] as List);
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

  Future<void> updateAccount({
    required String id,
    required String fullName,
    required String email,
    required String phone,
  }) async {
    await _invokeManage({
      'action': 'update',
      'id': id,
      'full_name': fullName.trim(),
      'email': email.trim().toLowerCase(),
      'phone': phone.trim(),
    });
  }

  Future<void> sendPasswordReset(String id) async {
    await _invokeManage({'action': 'reset_password', 'id': id});
  }

  Future<void> deleteAccount(String id) async {
    await _invokeManage({'action': 'delete', 'id': id});
  }

  Future<Map<String, dynamic>> _invokeManage(Map<String, dynamic> body) async {
    try {
      final response = await SupabaseConfig.client.functions.invoke(
        'manage-user',
        body: body,
      );
      if (response.status < 200 || response.status >= 300) {
        throw AccountCreationException(_messageFrom(response.data));
      }
      return Map<String, dynamic>.from(response.data as Map);
    } on FunctionException catch (error) {
      throw AccountCreationException(_messageFrom(error.details));
    }
  }
}

class AccountCreationException implements Exception {
  const AccountCreationException(this.message);
  final String message;

  @override
  String toString() => message;
}
