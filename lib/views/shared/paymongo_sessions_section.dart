import 'package:flutter/material.dart';
import '../../core/config/supabase_config.dart';
import '../../services/payment_collection_settings_service.dart';
import '../../services/paymongo_payment_service.dart';
import '../../services/table_refresh_subscription.dart';
import 'paymongo_payment_page.dart';

class PaymongoSessionsSection extends StatefulWidget {
  const PaymongoSessionsSection(
      {super.key,
      this.staff = false,
      this.service = const PaymongoPaymentService()});
  final bool staff;
  final PaymongoPaymentService service;
  @override
  State<PaymongoSessionsSection> createState() =>
      _PaymongoSessionsSectionState();
}

class _PaymongoSessionsSectionState extends State<PaymongoSessionsSection> {
  List<PaymongoPaymentSession> _sessions = [];
  bool _busy = false;
  String? _error;
  TableRefreshSubscription? _subscription;
  @override
  void initState() {
    super.initState();
    if (SupabaseConfig.isInitialized) {
      _load();
      _subscription = TableRefreshSubscription(
          'gateway-${widget.staff ? 'staff' : 'tenant'}',
          ['paymongo_payment_sessions'], () {
        if (mounted) _load();
      });
    }
  }

  @override
  void dispose() {
    _subscription?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final sessions = await widget.service.staffActive();
      if (mounted)
        setState(() {
          _sessions = sessions;
          _error = null;
        });
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Could not load automatic payment requests.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _act(PaymongoPaymentSession session, bool cancel) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (cancel)
        await widget.service.cancel(session.id);
      else
        await widget.service.refresh(session.id);
    } catch (error) {
      if (mounted)
        setState(() => _error = error is PaymentGatewayException
            ? error.message
            : 'Could not check payment status.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted && _error == null) await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_sessions.isEmpty && _error == null) return const SizedBox.shrink();
    return Card(
        child: ExpansionTile(
            initiallyExpanded: _sessions.any((s) => s.status == 'needs_review'),
            title: Text('Automatic payment requests (${_sessions.length})'),
            subtitle: const Text(
                'Active requests remain accessible after switching to manual.'),
            children: [
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Padding(padding: const EdgeInsets.all(12), child: Text(_error!)),
          Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                  onPressed: _busy ? null : _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh requests'))),
          ..._sessions.take(50).map((s) => Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '${s.billTitle ?? 'Bill payment'} — PHP ${s.amount.toStringAsFixed(2)}'),
                    if (widget.staff && s.tenantName != null)
                      Text(s.tenantName!),
                    Text(
                        '${s.isTest ? 'Test' : 'Live'} • ${s.status.replaceAll('_', ' ')}'),
                    if (s.issue != null) Text(s.issue!),
                    Wrap(spacing: 8, children: [
                      if (!widget.staff)
                        TextButton(
                            onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                    builder: (_) => PaymongoPaymentPage(
                                        initialSession: s,
                                        environment: s.environment))),
                            child: const Text('Open payment')),
                      TextButton(
                          onPressed: _busy ? null : () => _act(s, false),
                          child: const Text('Check status')),
                      if (s.isActive)
                        TextButton(
                            onPressed: _busy ? null : () => _act(s, true),
                            child: const Text('Cancel request')),
                    ]),
                  ]))),
        ]));
  }
}
