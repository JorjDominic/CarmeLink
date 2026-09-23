import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../core/utils/user_error_message.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/room_service.dart';
import '../services/geofence_scheduler.dart';
import '../services/tenant_service.dart';
import 'guardian_controller.dart';
import 'messaging_controller.dart';
import 'owner_controller.dart';
import 'tenant_controller.dart';

class SessionController extends ChangeNotifier {
  SessionController._();

  static final SessionController instance = SessionController._();

  final AuthService _authService = SupabaseAuthService();

  AppUser? _currentUser;
  bool _loading = true;
  String? _error;
  bool _justSignedOut = false;
  bool _passwordRecovery = false;
  String? _emailAwaitingVerification;
  StreamSubscription<AuthState>? _authSubscription;

  AppUser? get currentUser => _currentUser;
  bool get loading => _loading;
  String? get error => _error;
  bool get justSignedOut => _justSignedOut;
  bool get passwordRecovery => _passwordRecovery;
  String? get emailAwaitingVerification => _emailAwaitingVerification;

  static bool isPasswordRecoveryUri(Uri uri) {
    final path = uri.path.toLowerCase().replaceAll(RegExp(r'/+$'), '');
    return path.endsWith('/reset-password') ||
        uri.fragment.toLowerCase().contains('/reset-password');
  }

  Future<void> initialize({bool passwordRecoveryRequested = false}) async {
    if (passwordRecoveryRequested) {
      _passwordRecovery = true;
      _currentUser = null;
    }

    _authSubscription ??=
        SupabaseConfig.client.auth.onAuthStateChange.listen((state) async {
      if (state.event == AuthChangeEvent.passwordRecovery) {
        _passwordRecovery = true;
        _currentUser = null;
        notifyListeners();
      } else if (state.event == AuthChangeEvent.signedOut) {
        GeofenceScheduler.instance.stop();
        _currentUser = null;
        _passwordRecovery = false;
        TenantController.instance.clear();
        MessagingController.instance.clear();
        RoomService.invalidateCache();
        TenantService.invalidateCache();
        notifyListeners();
      }
    });

    try {
      if (!passwordRecoveryRequested) {
        _currentUser = await _authService
            .restoreSession()
            .timeout(const Duration(seconds: 4));

        if (_currentUser?.role == UserRole.tenant) {
          unawaited(GeofenceScheduler.instance.start(_currentUser!.id));
        }
      }
    } catch (e) {
      debugPrint('Session restore failed or timed out: $e');

      try {
        await _authService.signOut().timeout(const Duration(seconds: 2));
      } catch (_) {}

      _currentUser = null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> signIn(String email, String password) async {
    _loading = true;
    _error = null;
    _emailAwaitingVerification = null;
    notifyListeners();

    try {
      _currentUser = await _authService.signIn(email, password);
      await _syncEmailVerification();
      _justSignedOut = false;

      if (_currentUser?.role == UserRole.tenant) {
        unawaited(GeofenceScheduler.instance.start(_currentUser!.id));
      } else {
        GeofenceScheduler.instance.stop();
      }

      return true;
    } on EmailVerificationRequiredException catch (e) {
      _emailAwaitingVerification = email.trim().toLowerCase();
      _error = e.message;
      return false;
    } catch (e) {
      _error = userErrorMessage(
        e,
        fallback: 'Unable to sign in. Please try again.',
      );
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> verifyEmailCode(String email, String code) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _currentUser = await _authService
          .verifyEmailCode(email, code)
          .timeout(const Duration(seconds: 15));

      await _syncEmailVerification();
      _emailAwaitingVerification = null;
      _justSignedOut = false;

      if (_currentUser?.role == UserRole.tenant) {
        unawaited(GeofenceScheduler.instance.start(_currentUser!.id));
      }

      return true;
    } on TimeoutException {
      _error = 'Verification timed out. Check your connection and try again.';
      return false;
    } catch (e) {
      _error = userErrorMessage(
        e,
        fallback: 'Unable to verify. Please try again.',
      );
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void cancelEmailVerification() {
    _emailAwaitingVerification = null;
    _error = null;
    notifyListeners();
  }

  Future<void> _syncEmailVerification() async {
    try {
      await SupabaseConfig.client
          .rpc('sync_current_email_verification')
          .timeout(const Duration(seconds: 5));
    } catch (error) {
      debugPrint('Could not sync email verification timestamp: $error');
    }
  }

  Future<void> signOut() async {
    GeofenceScheduler.instance.stop();
    await _authService.signOut();

    _currentUser = null;
    _error = null;
    _emailAwaitingVerification = null;
    _justSignedOut = true;

    TenantController.instance.clear();
    GuardianController.instance.clear();
    OwnerController.instance.clear();
    RoomService.invalidateCache();
    TenantService.invalidateCache();

    notifyListeners();
  }

  void completePasswordRecovery() {
    _passwordRecovery = false;
    notifyListeners();
  }
}
