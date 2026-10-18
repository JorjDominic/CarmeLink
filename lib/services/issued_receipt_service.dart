import 'dart:math';
import '../core/config/supabase_config.dart';

class IssuedReceiptService {
  const IssuedReceiptService();
  static String requestId() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<List<Map<String, dynamic>>> list(String transactionId) async =>
      List<Map<String, dynamic>>.from(await SupabaseConfig.client
          .from('issued_payment_receipts')
          .select()
          .eq('transaction_id', transactionId)
          .order('created_at'));

  Future<void> record(
      {required String id,
      required String transactionId,
      required String number,
      required String date,
      String? photo}) async {
    await SupabaseConfig.client.rpc('record_issued_payment_receipt', params: {
      'p_id': id,
      'p_transaction_id': transactionId,
      'p_number': number,
      'p_issued_on': date,
      'p_photo_path': photo,
    });
  }

  Future<void> voidReceipt(String id, String reason) async {
    await SupabaseConfig.client.rpc('void_issued_payment_receipt',
        params: {'p_id': id, 'p_reason': reason});
  }
}
