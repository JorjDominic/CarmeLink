import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../models/models.dart';

abstract class AuthService {
  Future<AppUser?> restoreSession();
  Future<AppUser> signIn(String email, String password);
  Future<void> signOut();
  Future<void> requestPasswordReset(String email);
}

class SupabaseAuthService implements AuthService {
  SupabaseClient get _client => SupabaseConfig.client;

  @override
  Future<AppUser?> restoreSession() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    return _loadProfile(user);
  }

  @override
  Future<AppUser> signIn(String email, String password) async {
    if (email.trim().isEmpty || password.isEmpty) {
      throw const AuthException('Enter both email and password.');
    }

    final response = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    final user = response.user;
    if (user == null) throw const AuthException('Unable to sign in.');

    try {
      return await _loadProfile(user);
    } catch (_) {
      await _client.auth.signOut();
      rethrow;
    }
  }

  Future<AppUser> _loadProfile(User authUser) async {
    final row = await _client
        .from('profiles')
        .select('id, full_name, role, phone')
        .eq('id', authUser.id)
        .single();

    return AppUser(
      id: row['id'] as String,
      name: row['full_name'] as String,
      email: authUser.email ?? '',
      role: _parseRole(row['role'] as String),
      phone: (row['phone'] as String?) ?? '',
    );
  }

  UserRole _parseRole(String role) => switch (role) {
        'tenant' => UserRole.tenant,
        'guardian' => UserRole.guardian,
        'owner_caretaker' => UserRole.ownerCaretaker,
        _ => throw const AuthException('This account has an invalid role.'),
      };

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<void> requestPasswordReset(String email) async {
    if (!email.contains('@')) {
      throw const AuthException('Enter a valid email address.');
    }
    await _client.auth.resetPasswordForEmail(email.trim());
  }
}
