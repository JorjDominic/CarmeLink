import 'package:flutter/material.dart';

import '../../controllers/owner_controller.dart';
import '../../models/models.dart';
import '../../services/table_refresh_subscription.dart';
import '../../core/widgets/common_widgets.dart';
import 'notification_destination.dart';

class StaffCurfewRequestsPage extends StatefulWidget {
  const StaffCurfewRequestsPage({super.key});

  @override
  State<StaffCurfewRequestsPage> createState() =>
      _StaffCurfewRequestsPageState();
}

class _StaffCurfewRequestsPageState extends State<StaffCurfewRequestsPage> {
  final _processing = <String>{};
  late final TableRefreshSubscription _subscription;

  @override
  void initState() {
    super.initState();
    OwnerController.instance.loadCurfewRequests(force: true);
    _subscription = TableRefreshSubscription(
      'staff-curfew-acknowledgments',
      ['curfew_requests', 'guardian_tenant_links'],
      () => OwnerController.instance.loadCurfewRequests(force: true),
    );
  }

  @override
  void dispose() {
    _subscription.dispose();
    super.dispose();
  }

  Future<void> _decide(CurfewRequest request, bool accept) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(accept ? 'Acknowledge request?' : 'Decline request?'),
        content: Text(
          '${request.requestTypeLabel} for ${request.tenantName ?? 'tenant'}'
          '\n${request.destination}\n${request.reason}'
          '\n\n${accept ? 'Acknowledgment authorizes the requested departure and return period.' : 'This request will not authorize an absence.'}',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(accept ? 'Acknowledge' : 'Decline')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _processing.add(request.id));
    try {
      await OwnerController.instance.decideCurfewRequest(
        requestId: request.id,
        approve: accept,
      );
      if (mounted)
        showAppSnackBar(
            context, accept ? 'Request acknowledged.' : 'Request declined.');
    } catch (error) {
      if (mounted)
        showAppSnackBar(context, 'Could not record acknowledgment: $error');
      await OwnerController.instance.loadCurfewRequests(force: true);
    } finally {
      if (mounted) setState(() => _processing.remove(request.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = OwnerController.instance;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => PageFrame(
        title: 'Requests',
        subtitle: 'Late returns and overnight leave without a linked guardian',
        actions: [
          IconButton(
            tooltip: 'Refresh requests',
            onPressed: () => controller.loadCurfewRequests(force: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
                'Staff acknowledges late returns. A linked guardian acknowledges overnight leave; staff acts as the fallback when no guardian is linked.'),
            const SizedBox(height: 16),
            if (controller.curfewLoading) const LinearProgressIndicator(),
            if (controller.curfewError != null) Text(controller.curfewError!),
            if (!controller.curfewLoading && controller.curfewRequests.isEmpty)
              const Text('No curfew requests recorded.'),
            for (final request in controller.curfewRequests.where((request) =>
                NotificationTarget.recordIdOf(context, 'curfew') == null ||
                request.id == NotificationTarget.recordIdOf(context, 'curfew')))
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          '${request.tenantName ?? 'Tenant'} • ${request.requestTypeLabel}',
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(request.statusLabel),
                      Text('Destination: ${request.destination}'),
                      Text('Reason: ${request.reason}'),
                      Text('Departure: ${request.departureTime}'),
                      Text('Expected return: ${request.expectedReturnTime}'),
                      if (request.canReviewStaff) ...[
                        if (request.isOvernightLeave)
                          const Text(
                              'Routed to staff as the guardian fallback.'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            FilledButton(
                                onPressed: _processing.contains(request.id)
                                    ? null
                                    : () => _decide(request, true),
                                child: const Text('Acknowledge')),
                            OutlinedButton(
                                onPressed: _processing.contains(request.id)
                                    ? null
                                    : () => _decide(request, false),
                                child: const Text('Decline')),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
