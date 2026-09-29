import 'dart:async';

import 'package:flutter/material.dart';

import '../../controllers/owner_controller.dart';
import '../../controllers/session_controller.dart';
import '../../core/utils/billing_management_policy.dart';
import '../../core/widgets/adaptive_shell.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/role_guard.dart';
import '../../models/models.dart';
import 'owner_pages.dart';
import 'utility_charge_cart_dialog.dart';

class BillingManagementPage extends StatefulWidget {
  const BillingManagementPage({super.key});

  @override
  State<BillingManagementPage> createState() => _BillingManagementPageState();
}

class _BillingManagementPageState extends State<BillingManagementPage> {
  final _query = TextEditingController();
  BillingBucket _bucket = BillingBucket.all;
  BillingStatusFilter _status = BillingStatusFilter.all;
  int _visibleCount = 20;
  bool _refreshing = false;

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
    if (_visibleCount != 20) setState(() => _visibleCount = 20);
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
      builder: (_) => const _AdditionalChargeDialog(),
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
            final filtered = BillingManagementPolicy.filter(
              payments,
              query: _query.text,
              bucket: _bucket,
              status: _status,
            );
            final visible = filtered.take(_visibleCount).toList();
            final outstanding =
                BillingManagementPolicy.outstandingNow(payments);
            final utilities =
                BillingManagementPolicy.utilityOutstanding(payments);
            final pending =
                BillingManagementPolicy.pendingReviewCount(payments);
            final overdue = BillingManagementPolicy.overdueCount(payments);

            return PageFrame(
              title: 'Billing & charges',
              subtitle:
                  'Rent, utilities, manually approved charges, balances, and payment review.',
              onRefresh: _refresh,
              actions: [
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
              ],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BillingSummaryGrid(
                    outstanding: outstanding,
                    utilityOutstanding: utilities,
                    pendingReview: pending,
                    overdue: overdue,
                  ),
                  const SizedBox(height: 18),
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
                        _visibleCount = 20;
                      });
                    },
                    onStatusChanged: (value) {
                      setState(() {
                        _status = value;
                        _visibleCount = 20;
                      });
                    },
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
                  else if (filtered.isEmpty)
                    const _BillingEmptyState()
                  else ...[
                    Text(
                      'Showing ${visible.length} of ${filtered.length} matching charge${filtered.length == 1 ? '' : 's'}',
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
                    if (visible.length < filtered.length)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => setState(() => _visibleCount += 20),
                          icon: const Icon(Icons.expand_more_rounded),
                          label: Text(
                            'Load more (${filtered.length - visible.length} remaining)',
                          ),
                        ),
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
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 900
              ? 4
              : constraints.maxWidth >= 520
                  ? 2
                  : 1;
          const spacing = 10.0;
          final width =
              (constraints.maxWidth - spacing * (columns - 1)) / columns;
          final cards = <Widget>[
            MetricCard(
              label: 'Outstanding now',
              value: _money(outstanding),
              detail: 'Excludes deposits and future upcoming charges',
              icon: Icons.account_balance_wallet_outlined,
            ),
            MetricCard(
              label: 'Utilities outstanding',
              value: _money(utilityOutstanding),
              detail: 'Electricity, water, internet, and utility',
              icon: Icons.bolt_outlined,
            ),
            MetricCard(
              label: 'Pending verification',
              value: '$pendingReview',
              detail: 'Submitted payments awaiting staff review',
              icon: Icons.receipt_long_outlined,
            ),
            MetricCard(
              label: 'Overdue charges',
              value: '$overdue',
              detail: 'Tenant-payable charges past their due date',
              icon: Icons.warning_amber_rounded,
            ),
          ];
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: cards
                .map((card) => SizedBox(width: width, child: card))
                .toList(),
          );
        },
      );
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
                      '${payment.tenantName ?? 'Tenant'} • ${_categoryLabel(payment.category)}',
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
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _BillingFact(
                label: 'Charge',
                value: _money(payment.amount),
              ),
              _BillingFact(
                label: deposit ? 'Payable balance' : 'Balance',
                value: deposit ? '₱0.00' : _money(payment.outstandingAmount),
              ),
              _BillingFact(
                label: 'Due',
                value: shortDate(payment.dueDate),
              ),
              if (period != null)
                _BillingFact(label: 'Billing period', value: period),
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

class _BillingFact extends StatelessWidget {
  const _BillingFact({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 2),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      );
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

class _AdditionalChargeDialog extends StatefulWidget {
  const _AdditionalChargeDialog();

  @override
  State<_AdditionalChargeDialog> createState() =>
      _AdditionalChargeDialogState();
}

class _AdditionalChargeDialogState extends State<_AdditionalChargeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  final _notes = TextEditingController();
  String? _tenantId;
  String _category = 'other';
  late DateTime _dueDate;
  bool _saving = false;

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
    if (!_formKey.currentState!.validate() || _tenantId == null) return;
    setState(() => _saving = true);
    try {
      await OwnerController.instance.createAdditionalCharge(
        tenantId: _tenantId!,
        title: _title.text.trim(),
        category: _category,
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
      showAppSnackBar(context, 'Could not create charge: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenants = OwnerController.instance.tenants;
    return AlertDialog(
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
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _tenantId = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: const [
                    DropdownMenuItem(value: 'damage', child: Text('Damage')),
                    DropdownMenuItem(value: 'fine', child: Text('Fine')),
                    DropdownMenuItem(
                        value: 'late_fee', child: Text('Late fee')),
                    DropdownMenuItem(
                        value: 'cleaning', child: Text('Cleaning')),
                    DropdownMenuItem(
                        value: 'replacement', child: Text('Replacement')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) {
                          if (value != null) setState(() => _category = value);
                        },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Charge title'),
                  validator: (value) => (value?.trim().length ?? 0) < 2
                      ? 'Enter a charge title'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₱ ',
                  ),
                  validator: (value) =>
                      (double.tryParse(value?.trim() ?? '') ?? 0) <= 0
                          ? 'Enter a valid amount'
                          : null,
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: const Text('Due date'),
                  subtitle: Text(shortDate(_dueDate)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _saving ? null : _pickDueDate,
                ),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _reason,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Approval reason (required)',
                  ),
                  validator: (value) => (value?.trim().length ?? 0) < 3
                      ? 'Enter an approval reason'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notes,
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
