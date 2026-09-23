String userErrorMessage(
  Object? error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  if (error == null) return fallback;

  final raw = error.toString().trim();
  if (raw.isEmpty) return fallback;

  final lower = raw.toLowerCase();

  const networkSignals = <String>[
    'socketexception',
    'clientexception',
    'failed host lookup',
    'failed to fetch',
    'network request failed',
    'network is unreachable',
    'connection refused',
    'connection reset',
    'xmlhttprequest error',
  ];

  if (networkSignals.any(lower.contains)) {
    return 'No internet connection. Check your connection and try again.';
  }

  if (lower.contains('timeoutexception') ||
      lower.contains('connection timed out')) {
    return 'The request timed out. Check your connection and try again.';
  }

  final authMessage = RegExp(
    r'(?:AuthApiException|AuthException|AuthRetryableFetchException)'
    r'\(message:\s*([^,\)]+)',
  ).firstMatch(raw);

  if (authMessage != null) {
    final message = authMessage.group(1)?.trim();
    if (message != null && message.isNotEmpty) return message;
  }

  final cleaned = raw
      .replaceFirst(RegExp(r'^Exception:\s*'), '')
      .replaceFirst(RegExp(r'^StateError:\s*'), '')
      .trim();

  final looksInternal = RegExp(
    r'^[A-Za-z0-9_]*(Exception|Error)\s*[:\(]',
  ).hasMatch(cleaned);

  if (cleaned.contains('\n#0 ') ||
      cleaned.contains('\n#1 ') ||
      cleaned.toLowerCase().contains('stack trace') ||
      looksInternal) {
    return fallback;
  }

  return cleaned.isEmpty ? fallback : cleaned;
}
