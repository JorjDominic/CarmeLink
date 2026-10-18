/// Payment return links identify a request; they never assert payment success.
abstract final class PaymentReturnLink {
  static const path = '/payment/return';
  static const host = 'carmelitasdormitory.site';
  static final _uuid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
  static bool isSessionId(String value) => _uuid.hasMatch(value);

  static bool isReturnLocation(Uri uri) =>
      (uri.scheme == 'carmelink' &&
          uri.host == 'payment-return' &&
          (uri.path.isEmpty || uri.path == '/') &&
          uri.userInfo.isEmpty &&
          !uri.hasPort) ||
      (uri.scheme == 'https' &&
          uri.host == host &&
          uri.userInfo.isEmpty &&
          (!uri.hasPort || uri.port == 443) &&
          (uri.path == path ||
              uri.path == '$path/' ||
              (uri.path == '/' && Uri.tryParse(uri.fragment)?.path == path)));

  static String? sessionId(Uri uri) {
    if (!isReturnLocation(uri)) return null;
    try {
      final hashRoute = uri.scheme == 'https' &&
          uri.path == '/' &&
          Uri.tryParse(uri.fragment)?.path == path;
      if (uri.fragment.isNotEmpty && !hashRoute) return null;
      if (hashRoute && uri.queryParametersAll.containsKey('session_id'))
        return null;
      final query = hashRoute
          ? Uri.tryParse(uri.fragment)?.queryParametersAll
          : uri.queryParametersAll;
      final ids = query?['session_id'];
      if (ids == null || ids.length != 1 || !isSessionId(ids.single))
        return null;
      return ids.single;
    } on FormatException {
      return null;
    }
  }

  static Uri appUri(String id) {
    if (!isSessionId(id)) throw ArgumentError('Invalid payment request');
    return Uri(
        scheme: 'carmelink',
        host: 'payment-return',
        queryParameters: {'session_id': id});
  }

  static Uri websiteUri(String id) {
    if (!isSessionId(id)) throw ArgumentError('Invalid payment request');
    return Uri.https(host, path, {'session_id': id});
  }
}
