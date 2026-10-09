import 'dart:async';

import 'package:flutter/material.dart';

import '../../controllers/owner_controller.dart';
import '../../core/widgets/common_widgets.dart';
import '../../models/models.dart';
import '../../services/curfew_service.dart';
import '../../services/table_refresh_subscription.dart';
import 'notification_destination.dart';

class StaffCurfewRequestsPage extends StatefulWidget {
  const StaffCurfewRequestsPage({super.key, this.initialRequestId});

  final String? initialRequestId;

  @override
  State<StaffCurfewRequestsPage> createState() =>
      _StaffCurfewRequestsPageState();
}

class _StaffCurfewRequestsPageState extends State<StaffCurfewRequestsPage> {
  final _processing = <String>{};
  final _service = const CurfewService();
  String _requestTypeFilter = 'all';
  Timer? _clockTimer;
  late final TableRefreshSubscription _subscription;

  CurfewRequest? _targetRequest;
  bool _targetLoading = false;
  String? _targetError;
  bool _showAll = false;
  String? _targetId;

  bool get _hasTarget => _targetId != null && _targetId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final explicit = widget.initialRequestId?.trim();
    if (explicit != null && explicit.isNotEmpty) _targetId = explicit;
    _targetLoading = _hasTarget;
    _refresh();
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    _subscription = TableRefreshSubscription(
      'staff-curfew-acknowledgments',
      const ['curfew_requests', 'guardian_tenant_links'],
      () {
        if (mounted) _refresh(showSpinner: false);
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final inherited = NotificationTarget.recordIdOf(context, 'curfew')?.trim();
    final explicit = widget.initialRequestId?.trim();
    final resolved =
        explicit != null && explicit.isNotEmpty ? explicit : inherited;
    if (resolved != null && resolved.isNotEmpty && resolved != _targetId) {
      _targetId = resolved;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_showAll) _loadTarget();
      });
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _subscription.dispose();
    super.dispose();
  }

  Future<void> _refresh({bool showSpinner = true}) async {
    final controller = OwnerController.instance;
    await controller.loadCurfewRequests(force: true);
    if (_hasTarget && !_showAll) {
      await _loadTarget(showSpinner: showSpinner);
    }
  }

  Future<void> _loadTarget({bool showSpinner = true}) async {
    final id = _targetId?.trim();
    if (id == null || id.isEmpty) return;
    if (showSpinner && mounted) {
      setState(() {
        _targetLoading = true;
        _targetError = null;
      });
    }
    try {
      final request = await _service.getStaffRequestById(id);
      if (!mounted) return;
      setState(() {
        _targetRequest = request;
        _targetLoading = false;
        _targetError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _targetRequest = null;
        _targetLoading = false;
        _targetError = error.toString().replaceFirst('Exception: ', '');
      });
    }
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
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(accept ? 'Acknowledge' : 'Decline'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _processing.add(request.id));
    try {
      final updated = await OwnerController.instance.decideCurfewRequest(
        requestId: request.id,
        approve: accept,
      );
      if (!mounted) return;
      if (_targetRequest?.id == updated.id) {
        setState(() => _targetRequest = updated);
      }
      showAppSnackBar(
        context,
        accept ? 'Request acknowledged.' : 'Request declined.',
      );
    } catch (error) {
      if (mounted) {
        showAppSnackBar(context, 'Could not record acknowledgment: $error');
      }
      await _refresh(showSpinner: false);
    } finally {
      if (mounted) setState(() => _processing.remove(request.id));
    }
  }

  Future<DateTime?> _pickDateTime({
    required DateTime initial,
    required DateTime earliest,
    required DateTime latest,
  }) async {
    final firstDay = DateTime(earliest.year, earliest.month, earliest.day);
    final lastDay = DateTime(latest.year, latest.month, latest.day);
    final initialDay = DateTime(initial.year, initial.month, initial.day);
    final safeDay = initialDay.isBefore(firstDay)
        ? firstDay
        : initialDay.isAfter(lastDay)
            ? lastDay
            : initialDay;
    final date = await showDatePicker(
      context: context,
      initialDate: safeDay,
      firstDate: firstDay,
      lastDate: lastDay,
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _recordReturn(CurfewRequest request) async {
    if (_processing.contains(request.id)) return;
    final now = DateTime.now();
    if (request.departureTime.isAfter(now)) {
      showAppSnackBar(context, 'Departure has not started yet.');
      return;
    }
    final time = await _pickDateTime(
      initial: request.actualReturnTime ?? now,
      earliest: request.departureTime,
      latest: now,
    );
    if (time == null || !mounted) return;
    if (time.isBefore(request.departureTime) || time.isAfter(DateTime.now())) {
      showAppSnackBar(context,
          'Return time must be after departure and not in the future.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(request.actualReturnTime == null
            ? 'Confirm actual return?'
            : 'Correct recorded return?'),
        content: Text(
          'Have you verified ${request.tenantName ?? 'the tenant'} returned '
          'at ${_dateTime(time)}? This is a staff-confirmed record, '
          'not an automatic geofence confirmation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save return'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _processing.add(request.id));
    try {
      final updated = await _service.recordVerifiedReturn(
        requestId: request.id,
        actualReturnTime: time,
      );
      if (!mounted) return;
      if (_targetRequest?.id == updated.id) {
        setState(() => _targetRequest = updated);
      }
      await _refresh(showSpinner: false);
      if (mounted) showAppSnackBar(context, 'Verified return recorded.');
    } catch (error) {
      if (mounted) showAppSnackBar(context, 'Could not save return: $error');
    } finally {
      if (mounted) setState(() => _processing.remove(request.id));
    }
  }

  Future<void> _editExpectedReturn(CurfewRequest request) async {
    if (_processing.contains(request.id)) return;
    final time = await _pickDateTime(
      initial: request.expectedReturnTime,
      earliest: request.departureTime,
      latest: DateTime.now().add(const Duration(days: 365)),
    );
    if (time == null || !mounted) return;
    if (!time.isAfter(request.departureTime)) {
      showAppSnackBar(context, 'Expected return must be after departure.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Update expected return?'),
        content: Text('Change the late-return deadline to ${_dateTime(time)}? '
            'The tenant and linked guardian will be notified. '
            'This does not record an actual return.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save schedule'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _processing.add(request.id));
    try {
      final updated = await _service.updateLateReturnExpectedTime(
        requestId: request.id,
        expectedReturnTime: time,
      );
      if (!mounted) return;
      if (_targetRequest?.id == updated.id) {
        setState(() => _targetRequest = updated);
      }
      await _refresh(showSpinner: false);
      if (mounted) showAppSnackBar(context, 'Expected return updated.');
    } catch (error) {
      if (mounted)
        showAppSnackBar(context, 'Could not update schedule: $error');
    } finally {
      if (mounted) setState(() => _processing.remove(request.id));
    }
  }

  String _dateTime(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour == 0
        ? 12
        : local.hour > 12
            ? local.hour - 12
            : local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.month}/${local.day}/${local.year} • $hour:$minute $period';
  }

  Widget _requestCard(CurfewRequest request) {
    return CarmelitaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${request.tenantName ?? 'Tenant'} • ${request.requestTypeLabel}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              StatusPill(request.isOverdue ? 'Overdue' : request.statusLabel),
            ],
          ),
          const SizedBox(height: 10),
          Text('Destination: ${request.destination}'),
          Text('Reason: ${request.reason}'),
          Text('Departure: ${_dateTime(request.departureTime)}'),
          Text('Expected return: ${_dateTime(request.expectedReturnTime)}'),
          if (request.guardianDecision != null) ...[
            const SizedBox(height: 8),
            Text(
              'Guardian decision: ${request.guardianDecision == 'approved' ? 'Approved' : 'Declined'}',
            ),
          ],
          if ((request.guardianRemarks ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Guardian notes: ${request.guardianRemarks}'),
          ],
          if (request.staffDecision != null)
            Text(
                'Staff decision: ${request.staffDecision == 'approved' ? 'Approved' : 'Declined'}'),
          if ((request.staffNotes ?? '').trim().isNotEmpty)
            Text('Staff notes: ${request.staffNotes}'),
          if (request.actualReturnTime != null)
            Text('Verified return: ${_dateTime(request.actualReturnTime!)}'),
          if (request.isOverdue) ...[
            const SizedBox(height: 8),
            const Text(
                'Expected return has passed; no return has been recorded yet.'),
          ],
          if (request.canReviewStaff) ...[
            if (request.isOvernightLeave) ...[
              const SizedBox(height: 8),
              const Text('Routed to staff as the guardian fallback.'),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: _processing.contains(request.id)
                      ? null
                      : () => _decide(request, true),
                  child: const Text('Acknowledge'),
                ),
                OutlinedButton(
                  onPressed: _processing.contains(request.id)
                      ? null
                      : () => _decide(request, false),
                  child: const Text('Decline'),
                ),
              ],
            ),
          ] else if (!request.isApproved && !request.isCompleted) ...[
            const SizedBox(height: 10),
            Text(
              'This request no longer needs a staff decision. The record remains available for review.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (request.status == 'approved') ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _processing.contains(request.id) ||
                          (request.actualReturnTime == null &&
                              request.departureTime.isAfter(DateTime.now()))
                      ? null
                      : () => _recordReturn(request),
                  icon: const Icon(Icons.assignment_turned_in_outlined),
                  label: Text(request.actualReturnTime == null
                      ? 'Record return'
                      : 'Edit recorded return'),
                ),
                if (request.isLateReturn && request.actualReturnTime == null)
                  OutlinedButton.icon(
                    onPressed: _processing.contains(request.id)
                        ? null
                        : () => _editExpectedReturn(request),
                    icon: const Icon(Icons.edit_calendar_outlined),
                    label: const Text('Edit expected return'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _targetBody() {
    if (_targetLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final request = _targetRequest;
    if (_targetError != null || request == null) {
      return EmptyState(
        icon: Icons.event_busy_outlined,
        title: 'Curfew request unavailable',
        message: _targetError ??
            'This curfew request is no longer available to your account.',
        action: FilledButton.icon(
          onPressed: () => setState(() => _showAll = true),
          icon: const Icon(Icons.list_alt_outlined),
          label: const Text('View all curfew requests'),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            TextButton.icon(
              onPressed: () => setState(() => _showAll = true),
              icon: const Icon(Icons.arrow_back),
              label: const Text('All requests'),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Refresh request',
              onPressed: () => _loadTarget(),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _requestCard(request),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = OwnerController.instance;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => PageFrame(
        title: 'Requests',
        subtitle: _hasTarget && !_showAll
            ? 'Curfew request details'
            : 'Late returns and overnight leave requests',
        actions: [
          IconButton(
            tooltip: 'Refresh requests',
            onPressed: () => _refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
        child: _hasTarget && !_showAll
            ? _targetBody()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Staff acknowledges late returns. A linked guardian acknowledges overnight leave; staff acts as the fallback when no guardian is linked.',
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final filter in const [
                        'all',
                        'late_return',
                        'overnight_leave'
                      ])
                        ChoiceChip(
                          label: Text(switch (filter) {
                            'late_return' => 'Late Return',
                            'overnight_leave' => 'Overnight Leave',
                            _ => 'All Requests',
                          }),
                          selected: _requestTypeFilter == filter,
                          onSelected: (_) =>
                              setState(() => _requestTypeFilter = filter),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (controller.curfewLoading) const LinearProgressIndicator(),
                  if (controller.curfewError != null) ...[
                    const SizedBox(height: 8),
                    CarmelitaCard(child: Text(controller.curfewError!)),
                  ],
                  if (!controller.curfewLoading &&
                      controller.curfewRequests.isEmpty)
                    const EmptyState(
                      icon: Icons.nightlight_outlined,
                      title: 'No curfew requests recorded',
                      message:
                          'Late-return and overnight-leave requests will appear here.',
                    ),
                  if (!controller.curfewLoading &&
                      controller.curfewRequests.isNotEmpty &&
                      !controller.curfewRequests.any((request) =>
                          _requestTypeFilter == 'all' ||
                          request.requestType == _requestTypeFilter))
                    const EmptyState(
                      icon: Icons.filter_alt_off_outlined,
                      title: 'No matching requests',
                      message: 'Try another request type filter.',
                    ),
                  for (final request in controller.curfewRequests.where(
                    (request) =>
                        _requestTypeFilter == 'all' ||
                        request.requestType == _requestTypeFilter,
                  )) ...[
                    _requestCard(request),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
      ),
    );
  }
}
