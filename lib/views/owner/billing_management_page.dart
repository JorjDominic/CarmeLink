import '../../core/widgets/numbered_pagination.dart';
import '../../core/widgets/financial_summary.dart';
import '../../services/payment_service.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/widgets/configured_choice_field.dart';
import '../../services/dormitory_configuration_service.dart';

import '../../controllers/owner_controller.dart';
import '../../controllers/session_controller.dart';
import '../../core/utils/billing_management_policy.dart';
import '../../core/widgets/adaptive_shell.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/role_guard.dart';
import '../../models/models.dart';
import 'owner_pages.dart';
import '../shared/staff_payment_received_dialog.dart';
import '../shared/staff_security_deposits_section.dart';
import 'utility_charge_cart_dialog.dart';
import 'payment_collection_settings_card.dart';
import '../shared/paymongo_sessions_section.dart';

class BillingManagementPage extends StatefulWidget {
  const BillingManagementPage({super.key});

  @override
  State<BillingManagementPage> createState() => _BillingManagementPageState();
}

class _BillingManagementPageState extends State<BillingManagementPage> {
  final _query = TextEditingController();
  BillingBucket _bucket = BillingBucket.all;
  BillingStatusFilter _status = BillingStatusFilter.all;
  int _chargePage = 1;
  bool _refreshing = false;
  bool _showUpcoming = false;

  bool get _isOwner =>
      SessionController.instance.currentUser?.role == UserRole.owner;

  @override
  void initState() {
    super.initState();
    final controller = OwnerController.instance;
    if (!controller.paymentsLoadedOnce) {
      unawaited(controller.loadPayments());
    }
    if (!controller.tenantsLoadedOnce) {
      unawaited(controller.loadTenants());
    }
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _resetPage() {
    if (_chargePage != 1) setState(() => _chargePage = 1);
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await Future.wait([
        OwnerController.instance.loadPayments(force: true),
        OwnerController.instance.loadTenants(force: true),
      ]);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _openPaymentVerification() {
    final nav = CarmelitaNavScope.maybeOf(context);
    if (nav != null) {
      nav.selectLabel('Payment verification');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PaymentVerificationPage()),
    );
  }

  Future<void> _openUtilityCart() async {
    await showDialog<void>(
      context: context,
      builder: (_) => const UtilityChargeCartDialog(),
    );
    if (mounted) await _refresh();
  }

  Future<void> _openAdditionalCharge() async {
    if (!_isOwner) return;
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => const AdditionalChargeDialog(),
    );
    if (changed == true && mounted) await _refresh();
  }

  Future<void> _openChargeAction(Payment payment) async {
    if (!_isOwner || payment.isRent || payment.isDeposit) return;
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _BillingChargeActionDialog(payment: payment),
    );
    if (changed == true && mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) => RoleGuard(
        allowedRoles: const {UserRole.owner, UserRole.caretaker},
        child: AnimatedBuilder(
          animation: OwnerController.instance,
          builder: (context, _) {
            final controller = OwnerController.instance;
            final payments = controller.payments;
            final matching = BillingManagementPolicy.filter(
              payments,
              query: _query.text,
              bucket: _bucket,
              status: _status,
            );
            final futureCount =
                matching.where(BillingManagementPolicy.isFutureUnpaid).length;
            final hideFuture =
                _status == BillingStatusFilter.all && !_showUpcoming;
            final filtered = hideFuture
                ? matching
                    .where((p) => !BillingManagementPolicy.isFutureUnpaid(p))
                    .toList()
                : matching;
            final pageCount = ((filtered.length + 19) ~/ 20).clamp(1, 1 << 30);
            final page = _chargePage.clamp(1, pageCount);
            final visible = filtered.skip((page - 1) * 20).take(20).toList();
            final outstanding =
                BillingManagementPolicy.outstandingNow(payments);
            final utilities =
                BillingManagementPolicy.utilityOutstanding(payments);
            final pending =
                BillingManagementPolicy.pendingReviewCount(payments);
            final overdue = BillingManagementPolicy.overdueCount(payments);

            final narrowHeader = MediaQuery.sizeOf(context).width < 600;
            final billingActions = <Widget>[
              IconButton(
                  tooltip: 'Send payment due alerts to staff',
                  icon: const Icon(Icons.notifications_active_outlined),
                  onPressed: () async {
                    final count =
                        await controller.checkAndNotifyDuePayments(force: true);
                    if (context.mounted)
                      showAppSnackBar(
                          context,
                          count > 0
                              ? 'Dispatched due date alerts for $count charge(s).'
                              : 'No payments currently due or overdue.');
                  }),
              FilledButton.icon(
                onPressed: () => showStaffPaymentReceived(context),
                icon: const Icon(Icons.add_card_outlined),
                label: const Text('Record payment received'),
              ),
              IconButton(
                tooltip: 'Refresh billing',
                onPressed: _refreshing ? null : _refresh,
                icon: _refreshing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
            ];

            return PageFrame(
              title: 'Billing',
              subtitle:
                  'Rent, utilities, manually approved charges, balances, and payment review.',
              onRefresh: _refresh,
              actions: narrowHeader ? null : billingActions,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (narrowHeader) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: billingActions,
                    ),
                    const SizedBox(height: 16),
                  ],
                  _BillingSummaryGrid(
                    outstanding: outstanding,
                    utilityOutstanding: utilities,
                    pendingReview: pending,
                    overdue: overdue,
                  ),
                  const SizedBox(height: 18),
                  const StaffSecurityDepositsSection(),
                  const SizedBox(height: 18),
                  const PaymongoSessionsSection(staff: true),
                  if (_isOwner) ...[
                    const PaymentCollectionSettingsCard(),
                    const SizedBox(height: 18),
                  ],
                  _BillingActionsCard(
                    isOwner: _isOwner,
                    onUtilityCart: _openUtilityCart,
                    onAdditionalCharge: _openAdditionalCharge,
                    onPaymentVerification: _openPaymentVerification,
                  ),
                  const SizedBox(height: 18),
                  _BillingFilters(
                    controller: _query,
                    bucket: _bucket,
                    status: _status,
                    onQueryChanged: (_) {
                      _resetPage();
                      setState(() {});
                    },
                    onBucketChanged: (value) {
                      setState(() {
                        _bucket = value;
                        _chargePage = 1;
                      });
                    },
                    onStatusChanged: (value) {
                      setState(() {
                        _status = value;
                        _chargePage = 1;
                      });
                    },
                  ),
                  if (_status == BillingStatusFilter.all && futureCount > 0)
                    TextButton.icon(
                      key: const Key('staff-billing-upcoming-toggle'),
                      onPressed: () => setState(() {
                        _showUpcoming = !_showUpcoming;
                        _chargePage = 1;
                      }),
                      icon: Icon(_showUpcoming
                          ? Icons.expand_less
                          : Icons.expand_more),
                      label: Text(_showUpcoming
                          ? 'Hide upcoming bills'
                          : 'Show upcoming bills ($futureCount)'),
                    ),
                  const SizedBox(height: 14),
                  if (controller.paymentsLoading &&
                      !controller.paymentsLoadedOnce)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(28),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (controller.paymentsError != null &&
                      !controller.paymentsLoadedOnce)
                    _BillingError(
                      message: controller.paymentsError!,
                      onRetry: _refresh,
                    )
                  else if (filtered.isEmpty && hideFuture && futureCount > 0)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                          'No current bills match. Expand upcoming bills to view the future schedule.'),
                    )
                  else if (filtered.isEmpty)
                    const _BillingEmptyState()
                  else ...[
                    Text(
                      '${filtered.length} matching charge${filtered.length == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    for (final payment in visible) ...[
                      _BillingChargeCard(
                        payment: payment,
                        canManage: _isOwner &&
                            !payment.isRent &&
                            !payment.isDeposit &&
                            !payment.isVoided,
                        onManage: () => _openChargeAction(payment),
                        onReviewPayment:
                            payment.isPending ? _openPaymentVerification : null,
                      ),
                      const SizedBox(height: 9),
                    ],
                    NumberedPaginationBar(
                      currentPage: page,
                      totalItems: filtered.length,
                      pageSize: 20,
                      itemLabel: 'charges',
                      onPageChanged: (value) =>
                          setState(() => _chargePage = value),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      );
}

class _BillingSummaryGrid extends StatelessWidget {
  const _BillingSummaryGrid({
    required this.outstanding,
    required this.utilityOutstanding,
    required this.pendingReview,
    required this.overdue,
  });

  final double outstanding;
  final double utilityOutstanding;
  final int pendingReview;
  final int overdue;

  String _money(double value) => '₱${value.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Billing overview'),
        const SizedBox(height: 12),
        FinancialSummary(items: [
          (
            'Outstanding balance',
            _money(outstanding),
            Icons.account_balance_wallet_outlined,
            'Excludes deposits and future rent; includes issued charges'
          ),
          (
            'Utilities outstanding',
            _money(utilityOutstanding),
            Icons.bolt_outlined,
            'Electricity, water, internet, and utility'
          ),
          (
            'Pending verification',
            '$pendingReview',
            Icons.receipt_long_outlined,
            'Submitted payments awaiting staff review'
          ),
          (
            'Overdue charges',
            '$overdue',
            Icons.warning_amber_rounded,
            'Tenant-payable charges past their due date'
          ),
        ]),
      ]);
}

class _BillingActionsCard extends StatelessWidget {
  const _BillingActionsCard({
    required this.isOwner,
    required this.onUtilityCart,
    required this.onAdditionalCharge,
    required this.onPaymentVerification,
  });

  final bool isOwner;
  final VoidCallback onUtilityCart;
  final VoidCallback onAdditionalCharge;
  final VoidCallback onPaymentVerification;

  @override
  Widget build(BuildContext context) => CarmelitaCard(
        emphasis: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Billing actions',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              isOwner
                  ? 'Utilities may be issued to occupied tenants. Other charges are manual and audited; they are never created automatically from conduct or inspection records.'
                  : 'Caretakers may issue utility allocations and review payment proof. Owner approval is required for non-utility additional charges.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: [
                FilledButton.icon(
                  key: const Key('phase7-utility-cart'),
                  onPressed: onUtilityCart,
                  icon: const Icon(Icons.shopping_cart_checkout_outlined),
                  label: const Text('Issue utilities'),
                ),
                if (isOwner)
                  OutlinedButton.icon(
                    key: const Key('phase7-additional-charge'),
                    onPressed: onAdditionalCharge,
                    icon: const Icon(Icons.add_card_outlined),
                    label: const Text('Add other charge'),
                  ),
                OutlinedButton.icon(
                  key: const Key('phase7-payment-verification'),
                  onPressed: onPaymentVerification,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Payment verification'),
                ),
              ],
            ),
          ],
        ),
      );
}

class _BillingFilters extends StatelessWidget {
  const _BillingFilters({
    required this.controller,
    required this.bucket,
    required this.status,
    required this.onQueryChanged,
    required this.onBucketChanged,
    required this.onStatusChanged,
  });

  final TextEditingController controller;
  final BillingBucket bucket;
  final BillingStatusFilter status;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<BillingBucket> onBucketChanged;
  final ValueChanged<BillingStatusFilter> onStatusChanged;

  String _bucketLabel(BillingBucket value) => switch (value) {
        BillingBucket.all => 'All',
        BillingBucket.rent => 'Rent',
        BillingBucket.utilities => 'Utilities',
        BillingBucket.other => 'Other charges',
      };

  String _statusLabel(BillingStatusFilter value) => switch (value) {
        BillingStatusFilter.all => 'All statuses',
        BillingStatusFilter.due => 'Due / unpaid',
        BillingStatusFilter.overdue => 'Overdue',
        BillingStatusFilter.pending => 'Pending verification',
        BillingStatusFilter.verified => 'Verified',
        BillingStatusFilter.upcoming => 'Upcoming',
        BillingStatusFilter.voided => 'Voided',
      };

  @override
  Widget build(BuildContext context) => CarmelitaCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              onChanged: onQueryChanged,
              decoration: const InputDecoration(
                labelText: 'Search billing',
                hintText: 'Tenant, charge, category, status, or reference',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: BillingBucket.values
                    .map(
                      (value) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(_bucketLabel(value)),
                          selected: value == bucket,
                          onSelected: (_) => onBucketChanged(value),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: DropdownButtonFormField<BillingStatusFilter>(
                initialValue: status,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  prefixIcon: Icon(Icons.filter_alt_outlined),
                ),
                items: BillingStatusFilter.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(_statusLabel(value)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) onStatusChanged(value);
                },
              ),
            ),
          ],
        ),
      );
}

class _BillingChargeCard extends StatelessWidget {
  const _BillingChargeCard({
    required this.payment,
    required this.canManage,
    required this.onManage,
    this.onReviewPayment,
  });

  final Payment payment;
  final bool canManage;
  final VoidCallback onManage;
  final VoidCallback? onReviewPayment;

  String _money(double value) => '₱${value.toStringAsFixed(2)}';

  String _categoryLabel(String value) {
    final normalized = value.trim().toLowerCase();
    return switch (normalized) {
      'late_fee' => 'Late fee',
      'electricity' => 'Electricity',
      'water' => 'Water',
      'internet' => 'Internet',
      'utility' => 'Utility',
      'rent' => 'Rent',
      'deposit' => 'Deposit record',
      'damage' => 'Damage',
      'cleaning' => 'Cleaning',
      'replacement' => 'Replacement',
      'fine' => 'Fine',
      _ => normalized.isEmpty
          ? 'Other'
          : '${normalized[0].toUpperCase()}${normalized.substring(1)}',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deposit = payment.isDeposit;
    final period = payment.periodStart != null && payment.periodEnd != null
        ? '${shortDate(payment.periodStart!)} – ${shortDate(payment.periodEnd!)}'
        : null;

    return CarmelitaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  BillingManagementPolicy.isUtility(payment)
                      ? Icons.bolt_outlined
                      : payment.isRent
                          ? Icons.home_outlined
                          : deposit
                              ? Icons.savings_outlined
                              : Icons.receipt_long_outlined,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payment.label,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${payment.tenantName ?? 'Tenant'} • ${payment.specificCategory != null && payment.category == 'other' ? payment.categoryLabel : _categoryLabel(payment.category)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusPill(deposit ? 'Not payable' : payment.status),
            ],
          ),
          const SizedBox(height: 12),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1.1),
              1: FlexColumnWidth(1.7)
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.top,
            children: [
              for (final fact in <(String, String)>[
                ('Charge', _money(payment.amount)),
                (
                  deposit ? 'Payable balance' : 'Balance',
                  deposit ? '\u20b10.00' : _money(payment.outstandingAmount)
                ),
                ('Due', shortDate(payment.dueDate)),
                if (period != null) ('Billing period', period),
              ])
                TableRow(
                    decoration: BoxDecoration(
                        border: Border(
                            bottom: BorderSide(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant
                                    .withValues(alpha: .5)))),
                    children: [
                      Padding(
                          padding: const EdgeInsets.fromLTRB(0, 8, 12, 8),
                          child: Text(fact.$1,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant))),
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(fact.$2,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600))),
                    ]),
            ],
          ),
          if (deposit) ...[
            const SizedBox(height: 10),
            Text(
              'Deposit records are shown for history only and are excluded from this screen\'s tenant-payable totals and actions.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (payment.notes?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 9),
            Text(payment.notes!.trim(), style: theme.textTheme.bodySmall),
          ],
          if (payment.depositAppliedAmount > 0) ...[
            const SizedBox(height: 8),
            Text(
                'Covered by security deposit: ₱${payment.depositAppliedAmount.toStringAsFixed(2)}',
                style: theme.textTheme.bodySmall),
          ],
          if (onReviewPayment != null || canManage) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onReviewPayment != null)
                  FilledButton.tonalIcon(
                    onPressed: onReviewPayment,
                    icon: const Icon(Icons.fact_check_outlined, size: 18),
                    label: const Text('Review payment'),
                  ),
                if (canManage)
                  OutlinedButton.icon(
                    onPressed: onManage,
                    icon: const Icon(Icons.tune_outlined, size: 18),
                    label: const Text('Manage charge'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BillingEmptyState extends StatelessWidget {
  const _BillingEmptyState();

  @override
  Widget build(BuildContext context) => CarmelitaCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 38,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 10),
                const Text(
                  'No matching charges',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Change the search or filters to review another billing set.',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
}

class _BillingError extends StatelessWidget {
  const _BillingError({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => CarmelitaCard(
        child: Column(
          children: [
            const Icon(Icons.cloud_off_outlined, size: 34),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => unawaited(onRetry()),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
}

class AdditionalChargeDialog extends StatefulWidget {
  final Future<List<DormitoryOption>> Function(String group)?
      categoryOptionsLoader;
  final PaymentService? paymentService;
  const AdditionalChargeDialog(
      {super.key, this.categoryOptionsLoader, this.paymentService});

  @override
  State<AdditionalChargeDialog> createState() => _AdditionalChargeDialogState();
}

class _AdditionalChargeDialogState extends State<AdditionalChargeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  final _notes = TextEditingController();
  final _specificCategory = TextEditingController();
  String? _tenantId;
  String _category = 'other';
  DormitoryOption? _categoryOption;
  late DateTime _dueDate;
  bool _saving = false;
  bool _submitted = false;
  final _requestId = PaymentService.createRequestId();

  @override
  void initState() {
    super.initState();
    final tenants = OwnerController.instance.tenants;
    if (tenants.isNotEmpty) _tenantId = tenants.first.id;
    final now = DateTime.now();
    _dueDate =
        DateTime(now.year, now.month, now.day).add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _reason.dispose();
    _notes.dispose();
    _specificCategory.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null && mounted) setState(() => _dueDate = picked);
  }

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate() || _tenantId == null)
      return;
    setState(() {
      _saving = true;
      _submitted = true;
    });
    try {
      final submit = widget.paymentService?.createAdditionalCharge ??
          OwnerController.instance.createAdditionalCharge;
      await submit(
        requestId: _requestId,
        tenantId: _tenantId!,
        title: _title.text.trim(),
        category: _category,
        specificCategory:
            _category == 'other' ? _specificCategory.text.trim() : null,
        amount: double.parse(_amount.text.trim()),
        dueDate: _dueDate,
        reason: _reason.text.trim(),
        notes: _notes.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnackBar(context,
          'Charge save was not confirmed. Retry with the same details, or close and refresh Billing to check whether it was saved. $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenants = OwnerController.instance.tenants;
    return AlertDialog(
      scrollable: true,
      title: const Text('Add other charge'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Owner-approved manual charge. This action does not create or modify a conduct case, inspection, contract, or rent schedule.',
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _tenantId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Tenant'),
                  items: tenants
                      .map(
                        (tenant) => DropdownMenuItem(
                          value: tenant.id,
                          child: Text(
                            '${tenant.name} • ${tenant.room}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  validator: (value) =>
                      value == null ? 'Select a tenant' : null,
                  onChanged: _saving || _submitted
                      ? null
                      : (value) => setState(() => _tenantId = value),
                ),
                const SizedBox(height: 12),
                ConfiguredChoiceField(
                  group: 'additional_charge_category',
                  loadOptions: widget.categoryOptionsLoader,
                  label: 'Category',
                  value: _categoryOption?.code,
                  enabled: !_saving && !_submitted,
                  validator: (value) =>
                      value == null ? 'Select an active category' : null,
                  onChanged: (option) => setState(() {
                    final changed = _categoryOption?.code != option?.code;
                    _categoryOption = option;
                    _category = option?.categoryCode ?? 'other';
                    if (changed) {
                      _specificCategory.text = _category == 'other' &&
                              option != null &&
                              !option.isCatchAll
                          ? option.label
                          : '';
                      if (_title.text.isEmpty &&
                          option != null &&
                          !option.isCatchAll) _title.text = option.label;
                    }
                  }),
                ),
                const SizedBox(height: 12),
                if (_category == 'other') ...[
                  TextFormField(
                      key: const Key('additional-charge-specific-category'),
                      controller: _specificCategory,
                      enabled: !_saving && !_submitted,
                      maxLength: 120,
                      decoration:
                          const InputDecoration(labelText: 'Specify Category'),
                      validator: (value) => (value?.trim().length ?? 0) < 2
                          ? 'Specify a category'
                          : null),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _title,
                  maxLength: 150,
                  enabled: !_saving && !_submitted,
                  decoration: const InputDecoration(labelText: 'Charge title'),
                  validator: (value) => (value?.trim().length ?? 0) < 2
                      ? 'Enter a charge title'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amount,
                  enabled: !_saving && !_submitted,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₱ ',
                  ),
                  validator: (value) {
                    final amount = double.tryParse(value?.trim() ?? '');
                    if (amount == null || !amount.isFinite || amount <= 0)
                      return 'Enter a valid amount';
                    if (amount > 9999999999.99 ||
                        !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value!.trim()))
                      return 'Enter an amount with at most two decimals';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: const Text('Due date'),
                  subtitle: Text(shortDate(_dueDate)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _saving || _submitted ? null : _pickDueDate,
                ),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _reason,
                  maxLength: 500,
                  enabled: !_saving && !_submitted,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Reason (Required)',
                  ),
                  validator: (value) => (value?.trim().length ?? 0) < 3
                      ? 'Enter an approval reason'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notes,
                  enabled: !_saving && !_submitted,
                  minLines: 2,
                  maxLines: 4,
                  decoration:
                      const InputDecoration(labelText: 'Notes (optional)'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: Text(_saving ? 'Creating…' : 'Create charge'),
        ),
      ],
    );
  }
}

class _BillingChargeActionDialog extends StatefulWidget {
  const _BillingChargeActionDialog({required this.payment});
  final Payment payment;

  @override
  State<_BillingChargeActionDialog> createState() =>
      _BillingChargeActionDialogState();
}

class _BillingChargeActionDialogState
    extends State<_BillingChargeActionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  String _action = 'due_date_extension';
  late DateTime _newDueDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _newDueDate = widget.payment.dueDate.add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _newDueDate,
      firstDate: widget.payment.dueDate.add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null && mounted) setState(() => _newDueDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await OwnerController.instance.applyChargeAction(
        chargeId: widget.payment.id,
        actionType: _action,
        reason: _reason.text.trim(),
        amount: _action == 'credit' || _action == 'debit'
            ? double.parse(_amount.text.trim())
            : null,
        newDueDate: _action == 'due_date_extension' ? _newDueDate : null,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnackBar(context, 'Could not update charge: $error');
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        scrollable: true,
        title: Text('Manage ${widget.payment.label}'),
        content: SizedBox(
          width: 440,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Only this issued non-rent charge is adjusted. Original facts and previous payment transactions remain in the audit history.',
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _action,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(labelText: 'Audited action'),
                  items: const [
                    DropdownMenuItem(
                      value: 'due_date_extension',
                      child: Text('Extend due date'),
                    ),
                    DropdownMenuItem(
                      value: 'credit',
                      child: Text('Reduce balance'),
                    ),
                    DropdownMenuItem(
                      value: 'debit',
                      child: Text('Increase balance'),
                    ),
                    DropdownMenuItem(
                      value: 'void',
                      child: Text('Void incorrect unpaid charge'),
                    ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) {
                          if (value != null) setState(() => _action = value);
                        },
                ),
                const SizedBox(height: 12),
                if (_action == 'due_date_extension')
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: const Text('New due date'),
                    subtitle: Text(shortDate(_newDueDate)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _saving ? null : _pickDate,
                  ),
                if (_action == 'credit' || _action == 'debit')
                  TextFormField(
                    controller: _amount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Adjustment amount',
                      prefixText: '₱ ',
                    ),
                    validator: (value) =>
                        (double.tryParse(value?.trim() ?? '') ?? 0) <= 0
                            ? 'Enter a valid amount'
                            : null,
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _reason,
                  minLines: 2,
                  maxLines: 4,
                  decoration:
                      const InputDecoration(labelText: 'Reason (required)'),
                  validator: (value) =>
                      (value?.trim().length ?? 0) < 3 ? 'Enter a reason' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: Text(_saving ? 'Saving…' : 'Confirm'),
          ),
        ],
      );
}
