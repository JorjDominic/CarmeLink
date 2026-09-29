import 'package:shared_preferences/shared_preferences.dart';

class WebWorkspacePersistenceState {
  const WebWorkspacePersistenceState({
    this.baseDestinationLabel,
    this.visiblePageLabel,
    this.expandedGroups = const <String>{},
  });

  final String? baseDestinationLabel;
  final String? visiblePageLabel;
  final Set<String> expandedGroups;
}

/// Browser workspace continuity only. This stores navigation presentation
/// state on the current device; it never changes role permissions or backend
/// records.
class WebWorkspacePersistenceService {
  const WebWorkspacePersistenceService();

  static const _prefix = 'carmelink.web.workspace.v1';

  String _roleKey(String roleLabel) => roleLabel
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');

  String _key(String roleLabel, String suffix) =>
      '$_prefix.${_roleKey(roleLabel)}.$suffix';

  Future<WebWorkspacePersistenceState> load(String roleLabel) async {
    final prefs = await SharedPreferences.getInstance();
    return WebWorkspacePersistenceState(
      baseDestinationLabel: prefs.getString(_key(roleLabel, 'base')),
      visiblePageLabel: prefs.getString(_key(roleLabel, 'visible')),
      expandedGroups:
          (prefs.getStringList(_key(roleLabel, 'groups')) ?? const <String>[])
              .toSet(),
    );
  }

  Future<void> saveDestination({
    required String roleLabel,
    required String baseDestinationLabel,
    required String visiblePageLabel,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(roleLabel, 'base'), baseDestinationLabel);
    await prefs.setString(_key(roleLabel, 'visible'), visiblePageLabel);
  }

  Future<void> saveExpandedGroups({
    required String roleLabel,
    required Set<String> groups,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final values = groups.toList()..sort();
    await prefs.setStringList(_key(roleLabel, 'groups'), values);
  }

  Future<void> clear(String roleLabel) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(roleLabel, 'base'));
    await prefs.remove(_key(roleLabel, 'visible'));
    await prefs.remove(_key(roleLabel, 'groups'));
  }
}
