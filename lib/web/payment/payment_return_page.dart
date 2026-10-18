import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/utils/payment_return_link.dart';

/// Public landing page. Private payment data is checked only inside the app.
class PaymentReturnPage extends StatefulWidget {
  const PaymentReturnPage({super.key, required this.uri, this.openApp});
  final Uri uri;
  final Future<bool> Function(Uri)? openApp;
  @override
  State<PaymentReturnPage> createState() => _PaymentReturnPageState();
}

class _PaymentReturnPageState extends State<PaymentReturnPage> {
  bool busy = false;
  String? error;
  Future<void> open(String id) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final uri = PaymentReturnLink.appUri(id);
      final opened = await (widget.openApp?.call(uri) ??
          launchUrl(uri, mode: LaunchMode.externalApplication));
      if (!opened && mounted)
        setState(() => error =
            'Could not open CarmeLink. Open the installed app manually and check Payments.');
    } catch (_) {
      if (mounted)
        setState(() => error =
            'Could not open CarmeLink. Open the installed app manually and check Payments.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = PaymentReturnLink.sessionId(widget.uri);
    return Scaffold(
        appBar: AppBar(title: const Text('CarmeLink')),
        body: SafeArea(
            child: Center(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Card(
                            child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                          Icons.account_balance_wallet_outlined,
                                          size: 40),
                                      const SizedBox(height: 16),
                                      Text('Return to CarmeLink',
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineSmall),
                                      const SizedBox(height: 12),
                                      Text(id == null
                                          ? 'This payment return link is incomplete or invalid. Open CarmeLink and check Payments.'
                                          : 'Open CarmeLink to verify this payment and view its latest status. If asked, sign in to the tenant account used for payment.'),
                                      const SizedBox(height: 12),
                                      const Text(
                                          'This page does not confirm that payment succeeded. CarmeLink checks the payment provider before updating your bill.'),
                                      if (id != null) ...[
                                        const SizedBox(height: 20),
                                        FilledButton.icon(
                                            onPressed:
                                                busy ? null : () => open(id),
                                            icon: const Icon(Icons.open_in_new),
                                            label: Text(busy
                                                ? 'Opening…'
                                                : 'Return to CarmeLink'))
                                      ],
                                      const SizedBox(height: 12),
                                      const Text(
                                          'If the app does not open, switch to it manually and open Payments. An installed app version supporting payment return links is required.'),
                                      if (error != null) ...[
                                        const SizedBox(height: 12),
                                        Text(error!)
                                      ],
                                    ]))))))));
  }
}
