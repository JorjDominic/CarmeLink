import 'package:flutter/material.dart';

import '../../core/widgets/common_widgets.dart';
import '../../services/security_deposit_service.dart';
import '../../services/table_refresh_subscription.dart';
import 'security_deposit_card.dart';

class StaffSecurityDepositsSection extends StatefulWidget {
  const StaffSecurityDepositsSection({super.key, this.loadRecords});
  final Future<List<SecurityDepositRecord>> Function()? loadRecords;

  @override
  State<StaffSecurityDepositsSection> createState() =>
      _StaffSecurityDepositsSectionState();
}

class _StaffSecurityDepositsSectionState
    extends State<StaffSecurityDepositsSection> {
  late Future<List<SecurityDepositRecord>> _records;
  late final TableRefreshSubscription _subscription;
  String _query = '';
  int _visible = 6;

  @override
  void initState() {
    super.initState();
    _records = _load();
    _subscription = TableRefreshSubscription(
      'staff-deposits-${identityHashCode(this)}',
      const ['tenant_contracts', 'security_deposit_receipts', 'profiles'],
      _reload,
    );
  }

  Future<List<SecurityDepositRecord>> _load() =>
      (widget.loadRecords ?? const SecurityDepositService().listStaffRecords)();

  void _reload() {
    if (mounted) setState(() => _records = _load());
  }

  @override
  void dispose() {
    _subscription.dispose();
    super.dispose();
  }

  Future<void> _open(SecurityDepositRecord record) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .85),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(record.tenantName,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            SecurityDepositCard(contractId: record.contractId, embedded: true),
          ]),
        ),
      ),
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) => CarmelitaCard(
        child: Material(
          type: MaterialType.transparency,
          child: FutureBuilder<List<SecurityDepositRecord>>(
            future: _records,
            builder: (context, snapshot) {
              final records = snapshot.data ?? const <SecurityDepositRecord>[];
              final matched = records
                  .where((r) =>
                      '${r.tenantName} ${r.contractNumber} ${r.status}'
                          .toLowerCase()
                          .contains(_query))
                  .toList();
              final received =
                  records.fold<double>(0, (sum, r) => sum + r.receivedAmount);
              final held =
                  records.fold<double>(0, (sum, r) => sum + r.heldAmount);
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      const Icon(Icons.savings_outlined),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text('Security deposits',
                              style: Theme.of(context).textTheme.titleMedium)),
                      IconButton(
                          onPressed: _reload,
                          tooltip: 'Refresh security deposits',
                          icon: const Icon(Icons.refresh)),
                    ]),
                    const Text(
                        'Held separately from rent and utilities. Open a record for receipt details.'),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const LinearProgressIndicator(),
                    if (snapshot.hasError) ...[
                      const Text('Could not load security deposits.'),
                      TextButton(
                          onPressed: _reload, child: const Text('Retry')),
                    ] else if (snapshot.connectionState !=
                        ConnectionState.waiting) ...[
                      const SizedBox(height: 8),
                      Text(
                          '${records.length} contracts · Received ₱${received.toStringAsFixed(2)} · Held ₱${held.toStringAsFixed(2)}'),
                      ExpansionTile(
                        key: const ValueKey('staff-security-deposit-list'),
                        tilePadding: EdgeInsets.zero,
                        title: const Text('View security deposits'),
                        children: [
                          TextField(
                              decoration: const InputDecoration(
                                  labelText:
                                      'Search tenant, contract or deposit status',
                                  prefixIcon: Icon(Icons.search)),
                              onChanged: (value) => setState(() {
                                    _query = value.trim().toLowerCase();
                                    _visible = 6;
                                  })),
                          if (matched.isEmpty)
                            Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(records.isEmpty
                                    ? 'No contract deposits yet.'
                                    : 'No matching deposits.')),
                          for (final record in matched.take(_visible))
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(record.tenantName.isEmpty
                                  ? record.contractNumber
                                  : record.tenantName),
                              subtitle: Text(
                                  '${record.contractNumber} · ${record.status}\n'
                                  'Required ₱${record.requiredAmount.toStringAsFixed(2)} · Received ₱${record.receivedAmount.toStringAsFixed(2)}'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _open(record),
                            ),
                          if (matched.length > _visible)
                            TextButton(
                              onPressed: () => setState(() => _visible += 6),
                              child: Text(
                                  'Show more deposits (${matched.length - _visible} remaining)'),
                            ),
                        ],
                      ),
                    ],
                  ]);
            },
          ),
        ),
      );
}
