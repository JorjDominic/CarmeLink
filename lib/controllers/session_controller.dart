import 'package:flutter/foundation.dart';
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

  AppUser? get currentUser => _currentUser;
  bool get loading => _loading;
  String? get error => _error;
  bool get justSignedOut => _justSignedOut;

  Future<void> initialize() async {
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
}
