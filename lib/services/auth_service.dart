import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../models/models.dart';

abstract class AuthService {
  Future<AppUser?> restoreSession();
  Future<AppUser> signIn(String email, String password);
  Future<void> signOut();
  Future<void> requestPasswordReset(String email);
  Future<void> changePassword(String currentPassword, String newPassword);
  Future<void> setRecoveredPassword(String newPassword);
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
        .single()
        .timeout(const Duration(seconds: 5));

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
        'caretaker' => UserRole.caretaker,
        'owner' => UserRole.owner,
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

  @override
  Future<void> changePassword(
      String currentPassword, String newPassword) async {
    final email = _client.auth.currentUser?.email;
    if (email == null) throw const AuthException('Your session has expired.');

    // Supabase updateUser only requires a session, so reauthenticate first to
    // ensure knowledge of the current password for this sensitive action.
    await _client.auth.signInWithPassword(
      email: email,
      password: currentPassword,
    );
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  @override
  Future<void> setRecoveredPassword(String newPassword) async {
    if (_client.auth.currentSession == null) {
      throw const AuthException('The recovery link is invalid or expired.');
    }
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }
}
