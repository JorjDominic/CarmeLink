// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

class WebBrowserHistoryLocation {
  const WebBrowserHistoryLocation({
    required this.inStaffPortal,
    this.entryId,
    this.label,
    this.group,
  });

  final bool inStaffPortal;
  final String? entryId;
  final String? label;
  final String? group;
}

class WebBrowserHistoryService {
  WebBrowserHistoryService._() {
    html.window.onPopState.listen((_) {
      _changes.add(current);
    });
  }

  static final WebBrowserHistoryService instance = WebBrowserHistoryService._();

  static const _entryKey = 'cl_entry';
  static const _labelKey = 'cl_workspace';
  static const _groupKey = 'cl_group';

  final _changes = StreamController<WebBrowserHistoryLocation>.broadcast();

  bool get supported => true;

  Stream<WebBrowserHistoryLocation> get changes => _changes.stream;

  bool get _isStaffPortal {
    final hash = html.window.location.hash.toLowerCase();
    return hash == '#/staff' || hash.startsWith('#/staff?');
  }

  WebBrowserHistoryLocation get current {
    final uri = Uri.parse(html.window.location.href);
    final query = uri.queryParameters;
    return WebBrowserHistoryLocation(
      inStaffPortal: _isStaffPortal,
      entryId: query[_entryKey],
      label: query[_labelKey],
      group: query[_groupKey],
    );
  }

  String _url({
    required String entryId,
    required String label,
    String? group,
  }) {
    final uri = Uri.parse(html.window.location.href);
    final query = Map<String, String>.from(uri.queryParameters)
      ..[_entryKey] = entryId
      ..[_labelKey] = label;
    if (group == null || group.trim().isEmpty) {
      query.remove(_groupKey);
    } else {
      query[_groupKey] = group.trim();
    }
    return uri.replace(queryParameters: query).toString();
  }

  void replace({
    required String entryId,
    required String label,
    String? group,
  }) {
    if (!_isStaffPortal) return;
    html.window.history.replaceState(
      html.window.history.state,
      html.document.title,
      _url(entryId: entryId, label: label, group: group),
    );
  }

  void push({
    required String entryId,
    required String label,
    String? group,
  }) {
    if (!_isStaffPortal) return;
    html.window.history.pushState(
      html.window.history.state,
      html.document.title,
      _url(entryId: entryId, label: label, group: group),
    );
  }
}
