import 'package:flutter/material.dart';
import '../../core/widgets/adaptive_shell.dart';
import '../../core/widgets/common_widgets.dart';
import '../../services/confidentiality_agreement_service.dart';
import '../../services/table_refresh_subscription.dart';
import 'confidentiality_agreements_page.dart';

/// Builds module content only after the server confirms current acceptance.
class ModuleAgreementGate extends StatefulWidget {
  const ModuleAgreementGate(
      {super.key, required this.service, required this.builder});
  final ConfidentialityAgreementService service;
  final WidgetBuilder builder;
  @override
  State<ModuleAgreementGate> createState() => _ModuleAgreementGateState();
}

class _ModuleAgreementGateState extends State<ModuleAgreementGate>
    with WidgetsBindingObserver {
  ModuleAgreementStatus? status;
  String? error;
  int generation = 0;
  late final TableRefreshSubscription subscription;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    subscription = TableRefreshSubscription(
        'agreement-${widget.service.module.key}-${identityHashCode(this)}',
        const [
          'confidentiality_agreement_versions',
          'confidentiality_agreement_acceptances'
        ],
        refresh,
        catchUpInterval: const Duration(seconds: 30));
    refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() => status = null);
      refresh();
    }
  }

  Future<void> refresh() async {
    final request = ++generation;
    try {
      final next = await widget.service.status();
      if (mounted && request == generation)
        setState(() {
          status = next;
          error = null;
        });
    } catch (_) {
      if (mounted && request == generation)
        setState(() {
          status = null;
          error =
              'Unable to verify agreement acceptance. Check your connection and retry.';
        });
    }
  }

  void decline() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      CarmelitaNavScope.maybeOf(context)?.selectLabel('Dashboard');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    subscription.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (status?.allowed == true) return widget.builder(context);
    final agreement = status?.agreement;
    if (agreement != null)
      return AgreementReviewPage(
          key: ValueKey(agreement['id']),
          version: agreement,
          canAccept: true,
          service: widget.service,
          onAccepted: refresh,
          onDecline: decline);
    return PageFrame(
        title: '${widget.service.module.title} agreement',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (status == null && error == null)
            const LinearProgressIndicator()
          else ...[
            Text(error ??
                'This module is unavailable until the owner publishes an agreement for your account. Other modules remain available.'),
            TextButton(onPressed: refresh, child: const Text('Retry')),
            TextButton(onPressed: decline, child: const Text('Back')),
          ],
        ]));
  }
}
