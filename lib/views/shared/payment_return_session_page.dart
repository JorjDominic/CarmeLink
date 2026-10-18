import 'package:flutter/material.dart';
import '../../core/widgets/common_widgets.dart';
import '../../services/paymongo_payment_service.dart';
import 'paymongo_payment_page.dart';

/// Resolves through the authenticated gateway/RLS, never through URL status flags.
class PaymentReturnSessionPage extends StatefulWidget {
  const PaymentReturnSessionPage(
      {super.key,
      required this.sessionId,
      this.service = const PaymongoPaymentService()});
  final String sessionId;
  final PaymongoPaymentService service;
  @override
  State<PaymentReturnSessionPage> createState() =>
      _PaymentReturnSessionPageState();
}

class _PaymentReturnSessionPageState extends State<PaymentReturnSessionPage> {
  late Future<PaymongoPaymentSession> request =
      widget.service.refresh(widget.sessionId);
  @override
  Widget build(BuildContext context) => FutureBuilder<PaymongoPaymentSession>(
      future: request,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData) {
          return PaymongoPaymentPage(
              key: ValueKey(snapshot.data!.id),
              initialSession: snapshot.data,
              service: widget.service);
        }
        return PageFrame(
            title: 'Check payment',
            child: snapshot.hasError
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        const Text(
                            'Could not verify this payment. Check your connection and make sure you are signed in to the tenant account that created it.'),
                        TextButton(
                            onPressed: () {
                              final retry =
                                  widget.service.refresh(widget.sessionId);
                              setState(() {
                                request = retry;
                              });
                            },
                            child: const Text('Try again'))
                      ])
                : const Center(child: CircularProgressIndicator()));
      });
}
