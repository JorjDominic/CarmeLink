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
  WebBrowserHistoryService._();

  static final WebBrowserHistoryService instance = WebBrowserHistoryService._();

  bool get supported => false;

  Stream<WebBrowserHistoryLocation> get changes =>
      const Stream<WebBrowserHistoryLocation>.empty();

  WebBrowserHistoryLocation get current =>
      const WebBrowserHistoryLocation(inStaffPortal: false);

  void replace({
    required String entryId,
    required String label,
    String? group,
  }) {}

  void push({
    required String entryId,
    required String label,
    String? group,
  }) {}
}
