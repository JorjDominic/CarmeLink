import 'package:flutter/material.dart';

import '../../core/utils/conduct_case_appeal_policy.dart';
import '../../core/widgets/common_widgets.dart';
import '../../services/conduct_case_appeal_service.dart';
import '../../services/table_refresh_subscription.dart';

String _appealDateTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour == 0
      ? 12
      : local.hour > 12
          ? local.hour - 12
          : local.hour;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'PM' : 'AM';
  return '${local.month}/${local.day}/${local.year} • '
      '$hour:$minute $suffix';
}

class ConductCaseAppealPanel extends StatefulWidget {
  const ConductCaseAppealPanel({
    required this.caseId,
    required this.caseStatus,
    required this.staffMode,
    super.key,
  });

  final String caseId;
  final String caseStatus;
  final bool staffMode;

  @override
  State<ConductCaseAppealPanel> createState() => _ConductCaseAppealPanelState();
}

class _ConductCaseAppealPanelState extends State<ConductCaseAppealPanel> {
  final service = const ConductCaseAppealService();
  late final TableRefreshSubscription subscription;
  List<ConductCaseAppealRecord> appeals = const [];
  bool loading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
    subscription = TableRefreshSubscription(
      'conduct-case-appeals-${widget.caseId}',
      const ['conduct_case_appeals'],
      () {
        if (mounted) _load(showSpinner: false);
      },
    );
  }

  @override
  void didUpdateWidget(covariant ConductCaseAppealPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.caseId != widget.caseId) {
      _load();
    }
  }

  @override
  void dispose() {
    subscription.dispose();
    super.dispose();
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner && mounted) {
      setState(() {
        loading = true;
        errorMessage = null;
      });
    }

    try {
      final latest = await service.listForCase(widget.caseId);
      if (!mounted) return;
      setState(() {
        appeals = latest;
        loading = false;
        errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMessage = conductCaseAppealError(error);
      });
    }
  }

  bool get _hasOpenAppeal =>
      appeals.any((appeal) => conductAppealIsOpen(appeal.status));

  Future<void> _submit() async {
    final statement = TextEditingController();
    final support = TextEditingController();
    var saving = false;

    final submitted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Submit conduct appeal'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Explain why you are contesting this conduct decision. '
                    'Submitting an appeal does not automatically reverse the '
                    'case outcome.',
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: statement,
                    enabled: !saving,
                    minLines: 4,
                    maxLines: 7,
                    maxLength: 4000,
                    decoration: const InputDecoration(
                      labelText: 'Appeal statement',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: support,
                    enabled: !saving,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 4000,
                    decoration: const InputDecoration(
                      labelText: 'Supporting information (optional)',
                      hintText:
                          'Add dates, context, references, or other details '
                          'for administrative review.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  saving ? null : () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final statementError =
                          validateConductAppealStatement(statement.text);
                      if (statementError != null) {
                        showAppSnackBar(dialogContext, statementError);
                        return;
                      }

                      final supportError =
                          validateConductAppealSupportingInformation(
                        support.text,
                      );
                      if (supportError != null) {
                        showAppSnackBar(dialogContext, supportError);
                        return;
                      }

                      setDialogState(() => saving = true);
                      try {
                        await service.submitAppeal(
                          caseId: widget.caseId,
                          statement: statement.text,
                          supportingInformation: support.text,
                        );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (error) {
                        if (dialogContext.mounted) {
                          showAppSnackBar(
                            dialogContext,
                            conductCaseAppealError(error),
                          );
                          setDialogState(() => saving = false);
                        }
                      }
                    },
              child: Text(saving ? 'Submitting…' : 'Submit appeal'),
            ),
          ],
        ),
      ),
    );

    statement.dispose();
    support.dispose();

    if (submitted == true && mounted) {
      await _load(showSpinner: false);
    }
  }

  Future<void> _withdraw(ConductCaseAppealRecord appeal) async {
    try {
      await service.withdrawAppeal(appeal);
      if (mounted) await _load(showSpinner: false);
    } catch (error) {
      if (mounted) {
        showAppSnackBar(context, conductCaseAppealError(error));
      }
    }
  }

  Future<void> _startReview(ConductCaseAppealRecord appeal) async {
    try {
      await service.startReview(appeal);
      if (mounted) await _load(showSpinner: false);
    } catch (error) {
      if (mounted) {
        showAppSnackBar(context, conductCaseAppealError(error));
      }
    }
  }

  Future<void> _decide(
    ConductCaseAppealRecord appeal,
    String decision,
  ) async {
    final notes = TextEditingController();
    var saving = false;

    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(
            decision == 'accepted' ? 'Accept appeal' : 'Deny appeal',
          ),
          content: SizedBox(
            width: 580,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (decision == 'accepted') ...[
                  const Text(
                    'Accepting the appeal records the administrative decision '
                    'only. It does not automatically rewrite the conduct case, '
                    'remove a warning, cancel a charge, or change tenancy.',
                  ),
                  const SizedBox(height: 14),
                ],
                TextField(
                  controller: notes,
                  enabled: !saving,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 4000,
                  decoration: const InputDecoration(
                    labelText: 'Decision notes',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  saving ? null : () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final validation =
                          validateConductAppealDecisionNotes(notes.text);
                      if (validation != null) {
                        showAppSnackBar(dialogContext, validation);
                        return;
                      }

                      setDialogState(() => saving = true);
                      try {
                        await service.decideAppeal(
                          appeal: appeal,
                          decision: decision,
                          notes: notes.text,
                        );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (error) {
                        if (dialogContext.mounted) {
                          showAppSnackBar(
                            dialogContext,
                            conductCaseAppealError(error),
                          );
                          setDialogState(() => saving = false);
                        }
                      }
                    },
              child: Text(
                saving
                    ? 'Saving…'
                    : decision == 'accepted'
                        ? 'Accept'
                        : 'Deny',
              ),
            ),
          ],
        ),
      ),
    );

    notes.dispose();
    if (changed == true && mounted) {
      await _load(showSpinner: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eligible = conductCaseAllowsAppeal(widget.caseStatus);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          'Appeals',
          subtitle: widget.staffMode
              ? '${appeals.length} submitted for this case'
              : 'Contest an applicable conduct decision',
          trailing: !widget.staffMode && eligible && !_hasOpenAppeal
              ? TextButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.rate_review_outlined),
                  label: const Text('Submit appeal'),
                )
              : null,
        ),
        const SizedBox(height: 10),
        if (loading)
          const CarmelitaCard(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (errorMessage != null)
          CarmelitaCard(child: Text(errorMessage!))
        else if (appeals.isEmpty)
          EmptyState(
            icon: Icons.rate_review_outlined,
            title: 'No appeals',
            message: widget.staffMode
                ? 'No appeal has been submitted for this conduct case.'
                : eligible
                    ? 'You may submit an appeal for this conduct decision.'
                    : 'This case is not currently eligible for an appeal.',
          )
        else
          ...appeals.map(
            (appeal) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CarmelitaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _appealDateTime(appeal.submittedAt),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        StatusPill(
                          conductAppealStatusLabel(appeal.status),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(appeal.appealStatement),
                    if (appeal.supportingInformation.trim().isNotEmpty) ...[
                      const Divider(height: 22),
                      Text(
                        'Supporting information',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(appeal.supportingInformation),
                    ],
                    if (appeal.decisionNotes.trim().isNotEmpty) ...[
                      const Divider(height: 22),
                      Text(
                        'Decision',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(appeal.decisionNotes),
                    ],
                    const SizedBox(height: 10),
                    if (widget.staffMode && conductAppealIsOpen(appeal.status))
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (appeal.status == 'submitted')
                            OutlinedButton.icon(
                              onPressed: () => _startReview(appeal),
                              icon: const Icon(Icons.manage_search_outlined),
                              label: const Text('Start review'),
                            ),
                          FilledButton.icon(
                            onPressed: () => _decide(
                              appeal,
                              'accepted',
                            ),
                            icon: const Icon(Icons.check_outlined),
                            label: const Text('Accept'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _decide(
                              appeal,
                              'denied',
                            ),
                            icon: const Icon(Icons.close_outlined),
                            label: const Text('Deny'),
                          ),
                        ],
                      )
                    else if (!widget.staffMode &&
                        tenantCanWithdrawConductAppeal(appeal.status))
                      TextButton.icon(
                        onPressed: () => _withdraw(appeal),
                        icon: const Icon(Icons.undo_outlined),
                        label: const Text('Withdraw'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        if (!widget.staffMode && eligible && _hasOpenAppeal) ...[
          const SizedBox(height: 4),
          Text(
            'A conduct appeal is already awaiting staff review.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
