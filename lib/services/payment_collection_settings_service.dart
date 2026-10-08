import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';

enum PaymentCollectionMode { manual, paymongo }

class PaymentCollectionSettings {
  const PaymentCollectionSettings({
    this.mode = PaymentCollectionMode.manual,
    this.paymongoReady = false,
    this.environment = 'test',
  });

  final PaymentCollectionMode mode;
  final bool paymongoReady;
  final String environment;

  factory PaymentCollectionSettings.fromJson(Map<String, dynamic> row) =>
      PaymentCollectionSettings(
        mode: row['mode'] == 'paymongo'
            ? PaymentCollectionMode.paymongo
            : PaymentCollectionMode.manual,
        paymongoReady: row['paymongo_ready'] == true,
        environment: row['environment'] == 'live' ? 'live' : 'test',
      );
}

class PaymentCollectionSettingsService {
  const PaymentCollectionSettingsService();

  Future<PaymentCollectionSettings> load() async {
    final row = await invokePaymentGateway({'action': 'settings'});
    return PaymentCollectionSettings.fromJson(
        Map<String, dynamic>.from(row['settings']));
  }

  Future<PaymentCollectionSettings> save(PaymentCollectionMode mode) async {
    final row =
        await invokePaymentGateway({'action': 'set_mode', 'mode': mode.name});
    return PaymentCollectionSettings.fromJson(
        Map<String, dynamic>.from(row['settings']));
  }
}

class PaymentGatewayException implements Exception {
  const PaymentGatewayException(this.message);
  final String message;
  @override
  String toString() => message;
}

Future<Map<String, dynamic>> invokePaymentGateway(
    Map<String, dynamic> body) async {
  try {
    final response = await SupabaseConfig.client.functions
        .invoke('paymongo-payments', body: body);
    final data = Map<String, dynamic>.from(response.data as Map);
    if (data['error'] is String) throw PaymentGatewayException(data['error']);
    return data;
  } on PaymentGatewayException {
    rethrow;
  } catch (error) {
    if (error is FunctionException && error.details is Map) {
      final message = (error.details as Map)['error'];
      if (message is String) throw PaymentGatewayException(message);
    }
    throw const PaymentGatewayException(
        'Payment service is unavailable. Please try again.');
  }
}
