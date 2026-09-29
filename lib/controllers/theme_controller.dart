import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/user_preferences_service.dart';

class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final ThemeController instance = ThemeController._();
  static const _localThemeKey = 'carmelink_theme_mode';

  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;

  Future<void> loadLocalPreference() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final stored = preferences.getString(_localThemeKey);
      if (stored == null) return;
      _applyThemeMode(_fromStorage(stored));
    } catch (_) {
      // Keep the default light theme if local storage is unavailable.
    }
  }

  Future<void> loadForCurrentUser() async {
    // Local storage provides a fast/offline fallback. The authenticated
    // backend preference remains authoritative when it is reachable.
    await loadLocalPreference();
    try {
      final stored = await const UserPreferencesService().loadThemeMode();
      final mode = _fromStorage(stored);
      _applyThemeMode(mode);
      await _saveLocal(mode);
    } catch (_) {
      // Keep the locally cached preference when the network/RPC is unavailable.
    }
  }

  void setThemeMode(ThemeMode mode) {
    _applyThemeMode(mode);
    unawaited(_persist(mode));
  }

  void _applyThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
  }

  Future<void> _persist(ThemeMode mode) async {
    await _saveLocal(mode);
    try {
      await const UserPreferencesService().saveThemeMode(_toStorage(mode));
    } catch (_) {
      // Local preference remains usable even if the authenticated save fails.
    }
  }

  Future<void> _saveLocal(ThemeMode mode) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_localThemeKey, _toStorage(mode));
    } catch (_) {
      // Appearance changes still apply for the current process.
    }
  }

  ThemeMode _fromStorage(String value) => switch (value.trim().toLowerCase()) {
        'system' => ThemeMode.system,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.light,
      };

  String _toStorage(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'system',
        ThemeMode.dark => 'dark',
        ThemeMode.light => 'light',
      };
}
