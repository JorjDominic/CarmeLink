import 'dart:io';

import 'package:carmelitas_dormitory_system/core/utils/database_write_outcome.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
      'SQL rejections allow cleanup but unknown commit outcomes retain evidence',
      () {
    for (final code in ['P0001', '42501', '23505', '40001']) {
      expect(
          isConfirmedDatabaseRejection(
              PostgrestException(message: 'Rejected', code: code)),
          isTrue);
    }
    for (final code in [
      null,
      '200',
      '503',
      '504',
      'PGRST000',
      '08006',
      '08007',
      '40003'
    ]) {
      expect(
          isConfirmedDatabaseRejection(
              PostgrestException(message: 'Unknown outcome', code: code)),
          isFalse);
    }
    expect(isConfirmedDatabaseRejection(const SocketException('Lost response')),
        isFalse);
    expect(
        isConfirmedDatabaseRejection(
            const FormatException('Truncated response')),
        isFalse);
  });
}
