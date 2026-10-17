import 'package:supabase_flutter/supabase_flutter.dart';

/// Only a server SQL rejection proves that an attachment was not committed.
/// Proxy failures, truncated replies and connection errors leave the outcome
/// unknown; deleting the uploaded evidence then could break a saved record.
bool isConfirmedDatabaseRejection(Object error) {
  if (error is! PostgrestException) return false;
  final code = error.code ?? '';
  return RegExp(r'^[0-9A-Z]{5}$').hasMatch(code) &&
      !code.startsWith('08') &&
      code != '40003'; // statement_completion_unknown
}
