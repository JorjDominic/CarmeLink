import 'package:flutter/material.dart';

import '../../services/payment_collection_settings_service.dart';
import '../shared/paymongo_payment_page.dart';

/// Mounted only in the owner's Billing page. The RPC separately enforces role.
class PaymentCollectionSettingsCard extends StatefulWidget {
  const PaymentCollectionSettingsCard({
    super.key,
    this.service = const PaymentCollectionSettingsService(),
  });

  final PaymentCollectionSettingsService service;

  @override
  State<PaymentCollectionSettingsCard> createState() =>
      _PaymentCollectionSettingsCardState();
}

class _PaymentCollectionSettingsCardState
    extends State<PaymentCollectionSettingsCard> {
  PaymentCollectionSettings? _settings;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final settings = await widget.service.load();
      if (mounted) setState(() => _settings = settings);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not load payment settings. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(PaymentCollectionMode mode) async {
    if (_busy || _settings?.mode == mode) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final settings = await widget.service.save(mode);
      if (mounted) {
        setState(() => _settings = settings);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment collection mode saved.')),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is PaymentGatewayException
            ? error.message
            : 'Could not change payment mode. Refresh the settings and try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.payment_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Tenant payment collection',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              IconButton(
                tooltip: 'Refresh payment settings',
                onPressed: _busy ? null : _load,
                icon: const Icon(Icons.refresh),
              ),
            ]),
            const Text('Only the owner can change this setting.'),
            const SizedBox(height: 12),
            if (settings != null)
              SegmentedButton<PaymentCollectionMode>(
                segments: [
                  const ButtonSegment(
                    value: PaymentCollectionMode.manual,
                    icon: Icon(Icons.upload_file_outlined),
                    label: Text('Manual'),
                  ),
                  ButtonSegment(
                    value: PaymentCollectionMode.paymongo,
                    enabled: settings.paymongoReady,
                    icon: const Icon(Icons.qr_code_2),
                    label: const Text('Automatic'),
                  ),
                ],
                selected: {settings.mode},
                onSelectionChanged:
                    _busy ? null : (values) => _save(values.single),
              ),
            if (_busy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: 12),
            const Text(
              'Manual: tenants submit a receipt photo for owner or caretaker review.',
            ),
            const Text(
              'Automatic: PayMongo QR Ph confirms supported wallet and bank app payments.',
            ),
            if (settings != null && !settings.paymongoReady) ...[
              const SizedBox(height: 8),
              const Text(
                'PayMongo is not connected yet. You can try the demo now; '
                'automatic collection becomes available after account and webhook setup.',
              ),
            ],
            const SizedBox(height: 8),
            if (settings?.paymongoReady == true &&
                settings?.environment == 'test')
              const Text(
                  'Sandbox connected: test confirmations leave actual bills unchanged.'),
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const PaymongoPaymentPage(demo: true))),
              icon: const Icon(Icons.science_outlined),
              label: const Text('Try payment demo (no keys needed)'),
            ),
            const Text(
              'Pending receipts remain available for review. Owners and caretakers '
              'can continue recording payments received in person.',
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
    );
  }
}
