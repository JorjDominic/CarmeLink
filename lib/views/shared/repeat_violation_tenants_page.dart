import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../controllers/session_controller.dart';
import '../../core/widgets/common_widgets.dart';
import '../../models/models.dart';
import '../../models/staff_tenant_option.dart';
import '../../models/tenant_conduct_status.dart';
import '../../services/staff_conduct_queue_service.dart';
import '../../services/table_refresh_subscription.dart';
import 'conduct_case_pages.dart';

class RepeatViolationTenantsPage extends StatefulWidget {
  const RepeatViolationTenantsPage(
      {super.key,
      this.service = const StaffConductQueueService(),
      this.session});
  final StaffConductQueueService service;
  final ValueListenable<AppUser?>? session;
  @override
  State<RepeatViolationTenantsPage> createState() =>
      _RepeatViolationTenantsPageState();
}

class _RepeatViolationTenantsPageState
    extends State<RepeatViolationTenantsPage> {
  StaffConductQueueSnapshot? data;
  String query = '', filter = 'all';
  String? error;
  bool loading = true;
  int generation = 0;
  late final TableRefreshSubscription subscription;
  AppUser? get user => widget.session != null
      ? widget.session!.value
      : SessionController.instance.currentUser;
  bool get staff =>
      user?.role == UserRole.owner || user?.role == UserRole.caretaker;
  @override
  void initState() {
    super.initState();
    load();
    subscription = TableRefreshSubscription(
        'repeat-violation-tenants',
        [
          'conduct_cases',
          'conduct_case_events',
          'conduct_case_appeals',
          'profiles',
          'tenant_details'
        ],
        load);
  }

  Future<void> load() async {
    final request = ++generation;
    if (!staff) {
      if (mounted)
        setState(() {
          data = null;
          loading = false;
        });
      return;
    }
    try {
      final result = await widget.service.load();
      if (!mounted || request != generation) return;
      setState(() {
        data = result;
        loading = false;
        error = result.statuses == null
            ? 'Violation tracking could not be loaded. Please retry.'
            : null;
      });
    } catch (_) {
      if (mounted && request == generation)
        setState(() {
          data = null;
          loading = false;
          error = 'Unable to load tenant conduct records. Please retry.';
        });
    }
  }

  @override
  void dispose() {
    subscription.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!staff)
      return const PageFrame(
          title: 'Repeated violations',
          subtitle: 'Staff access required',
          child: SizedBox.shrink());
    final names = <String, StaffTenantOption>{
      for (final tenant in data?.tenants ?? <StaffTenantOption>[])
        tenant.id: tenant
    };
    final flagged = (data?.statuses?.values ?? <TenantConductStatus>[])
        .where((status) => status.needsReview)
        .toList()
      ..sort((a, b) {
        final priority = b.recentConfirmed.compareTo(a.recentConfirmed);
        return priority != 0 ? priority : b.confirmed.compareTo(a.confirmed);
      });
    final visible = flagged
        .where((status) =>
            (filter == 'all' || status.status == filter) &&
            (names[status.tenantId]?.name ?? '')
                .toLowerCase()
                .contains(query.toLowerCase().trim()))
        .toList();
    return PageFrame(
        title: 'Repeated violations',
        subtitle: 'Tenant conduct review for owners and caretakers',
        onRefresh: load,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text(
              'Repeated: 2+ confirmed incidents. Continuous: 3+ confirmed incidents within 90 days. Duplicate linked incidents count once. These flags do not change residency.'),
          const SizedBox(height: 12),
          TextField(
              decoration: const InputDecoration(
                  labelText: 'Search tenant', prefixIcon: Icon(Icons.search)),
              onChanged: (value) => setState(() => query = value)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final choice in const {
              'all': 'All flagged tenants',
              'repeated_violations': 'Repeated',
              'continuous_violations': 'Continuous'
            }.entries)
              ChoiceChip(
                  label: Text(choice.value),
                  selected: filter == choice.key,
                  onSelected: (_) => setState(() => filter = choice.key)),
          ]),
          const SizedBox(height: 12),
          if (loading)
            const LinearProgressIndicator()
          else if (error != null) ...[
            Text(error!),
            TextButton(onPressed: load, child: const Text('Retry'))
          ] else ...[
            Text(
                '${visible.length} tenants shown · ${flagged.length} flagged tenants'),
            if (visible.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                      'No tenants match these confirmed-violation criteria.')),
            PagedRecordList(key: ValueKey('$filter-$query'), children: [
              for (final status in visible)
                Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: CarmelitaCard(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(names[status.tenantId]?.name ?? 'Tenant',
                              style: Theme.of(context).textTheme.titleMedium),
                          Text(names[status.tenantId]?.locationLabel ??
                              'Unassigned'),
                          const SizedBox(height: 6),
                          StatusPill(status.label),
                          Text(
                              '${status.confirmed} confirmed incidents · ${status.recentConfirmed} within 90 days'),
                          TextButton.icon(
                              onPressed: () async {
                                await Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                        builder: (_) => StaffConductCasesPage(
                                            initialTenantId: status.tenantId)));
                                if (mounted) await load();
                              },
                              icon: const Icon(Icons.history),
                              label: const Text('View tenant cases')),
                        ]))),
            ]),
          ],
        ]));
  }
}
