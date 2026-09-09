import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../models/models.dart';
import '../services/auth_service.dart';

class SessionController extends ChangeNotifier {
  SessionController._();
  static final SessionController instance = SessionController._();
  final AuthService _authService = SupabaseAuthService();
  AppUser? _currentUser;
  bool _loading = true;
  String? _error;
  bool _justSignedOut = false;
  bool _passwordRecovery = false;
  StreamSubscription<AuthState>? _authSubscription;

  AppUser? get currentUser => _currentUser;
  bool get loading => _loading;
  String? get error => _error;
  bool get justSignedOut => _justSignedOut;
  bool get passwordRecovery => _passwordRecovery;

  Future<void> initialize() async {
    _authSubscription ??=
        SupabaseConfig.client.auth.onAuthStateChange.listen((state) async {
      if (state.event == AuthChangeEvent.passwordRecovery) {
        _passwordRecovery = true;
        _currentUser = await _authService.restoreSession();
        notifyListeners();
      } else if (state.event == AuthChangeEvent.signedOut) {
        _currentUser = null;
        _passwordRecovery = false;
        notifyListeners();
      }
    });
    try {
      _currentUser = await _authService.restoreSession();
    } catch (_) {
      await _authService.signOut();
      _currentUser = null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> signIn(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _currentUser = await _authService.signIn(email, password);
      _justSignedOut = false;
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _currentUser = null;
    _error = null;
    _justSignedOut = true;
    notifyListeners();
  }

  void completePasswordRecovery() {
    _passwordRecovery = false;
    notifyListeners();
  }
}
