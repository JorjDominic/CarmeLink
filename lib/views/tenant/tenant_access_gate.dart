import 'package:flutter/material.dart';

import '../../controllers/session_controller.dart';
import '../../controllers/tenant_access_controller.dart';
import '../../core/widgets/common_widgets.dart';
import '../../services/contract_document_service.dart';
import '../shared/shared_views.dart';
import 'onboarding_form_page.dart';
import 'tenant_requirements_page.dart';

class TenantAccessGate extends StatefulWidget {
  const TenantAccessGate({super.key});

  @override
  State<TenantAccessGate> createState() => _TenantAccessGateState();
}

class _TenantAccessGateState extends State<TenantAccessGate> {
  final _access = TenantAccessController.instance;
  bool _signingOut = false;
  bool _openingContract = false;

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
    if (mounted) await _access.refresh();
  }

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    try {
      await SessionController.instance.signOut();
    } catch (error) {
      if (mounted) showAppSnackBar(context, 'Could not sign out: $error');
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  Future<void> _viewContract() async {
    final contract = _access.status?.contract;
    if (contract == null || _openingContract) return;

    setState(() => _openingContract = true);
    try {
      const service = ContractDocumentService();
      final documents = await service.listDocuments(contract.id);
      final signed = documents.where((item) => item.isSigned).firstOrNull;
      final generated = documents.where((item) => item.isGenerated).firstOrNull;
      final document = signed ?? generated;
      if (document == null) {
        if (mounted) {
          showAppSnackBar(
            context,
            'Your contract record is ready, but the PDF has not been generated yet.',
          );
        }
        return;
      }

      final bytes = await service.downloadDocument(document.storagePath);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => ContractDocumentPreviewDialog(
          title: document.isSigned
              ? 'Executed contract'
              : 'Contract #${contract.contractNumber}',
          mimeType: document.mimeType,
          bytes: bytes,
        ),
      );
    } catch (error) {
      if (mounted) {
        showAppSnackBar(context, 'Could not open your contract: $error');
      }
    } finally {
      if (mounted) setState(() => _openingContract = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _access,
        builder: (context, _) => Scaffold(
          appBar: AppBar(
            title: Text(switch (_access.state) {
              TenantAccessState.loading => 'CarmeLink',
              TenantAccessState.error => 'Account access',
              _ => 'Setup',
            }),
            actions: [
              IconButton(
                tooltip: 'Profile',
                onPressed: () => _open(const ProfilePage()),
                icon: const Icon(Icons.person_outline_rounded),
              ),
              IconButton(
                tooltip: 'Sign out',
                onPressed: _signingOut ? null : _signOut,
                icon: const Icon(Icons.logout_rounded),
              ),
            ],
          ),
          body: SafeArea(child: _body(context)),
        ),
      );

  Widget _body(BuildContext context) {
    if (_access.state == TenantAccessState.loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading your account...'),
          ],
        ),
      );
    }

    if (_access.state == TenantAccessState.error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 52),
              const SizedBox(height: 16),
              Text('We could not confirm your access',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'For your account’s protection, tenant features stay locked until your onboarding status can be checked.',
                textAlign: TextAlign.center,
              ),
              if (_access.error != null) ...[
                const SizedBox(height: 8),
                Text(_access.error!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _access.refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    final status = _access.status!;
    final progress = status.completedSteps / 4;
    final waitingForStaff = status.profileComplete &&
        status.contract != null &&
        !status.requirements.any((item) =>
            item.isRequired &&
            (item.status == 'missing' || item.status == 'rejected')) &&
        !status.signers.any((item) =>
            item.isRequired &&
            (item.status == 'pending' || item.status == 'rejected'));

    return RefreshIndicator(
      onRefresh: _access.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.fact_check_outlined,
                    size: 38,
                    color: Theme.of(context).colorScheme.onPrimaryContainer),
                const SizedBox(height: 16),
                Text(
                  waitingForStaff
                      ? 'Your application is being reviewed'
                      : 'Finish onboarding to unlock CarmeLink',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  waitingForStaff
                      ? 'No action is needed right now. Core tenant features will unlock automatically after staff approval.'
                      : 'Complete the items below. Payments, reports, curfew, messages, and other tenant services remain unavailable until approval.',
                ),
                const SizedBox(height: 18),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(99),
                ),
                const SizedBox(height: 8),
                Text('${status.completedSteps} of 4 steps complete'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Your contract',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          _ContractCard(
            status: status,
            opening: _openingContract,
            onOpen: status.contract == null ? null : _viewContract,
          ),
          const SizedBox(height: 24),
          Text('Your checklist',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          _ChecklistTile(
            icon: Icons.contact_emergency_outlined,
            title: 'Personal and emergency details',
            state: status.profileComplete && !status.hasPendingInvitation
                ? _StepState.complete
                : _StepState.action,
            subtitle: status.profileComplete && !status.hasPendingInvitation
                ? 'Details completed'
                : 'Add the contact information required for your residency.',
            buttonLabel: 'Complete details',
            onPressed: () => _open(const OnboardingFormPage()),
          ),
          _ChecklistTile(
            icon: Icons.upload_file_outlined,
            title: 'Required documents',
            state: _documentState(status),
            subtitle: _documentText(status),
            buttonLabel: 'Open documents',
            onPressed: status.contract == null
                ? null
                : () => _open(const TenantRequirementsPage()),
          ),
          _ChecklistTile(
            icon: Icons.draw_outlined,
            title: 'Required signatures',
            state: _signatureState(status),
            subtitle: _signatureText(status),
            buttonLabel: 'Review and sign',
            onPressed: status.contract == null
                ? null
                : () => _open(const TenantRequirementsPage()),
          ),
          _ChecklistTile(
            icon: Icons.verified_user_outlined,
            title: 'Dormitory approval',
            state: status.contractActive
                ? _StepState.complete
                : _StepState.waiting,
            subtitle: status.contract == null
                ? 'Staff still needs to prepare your tenancy contract.'
                : status.contractActive
                    ? 'Your contract is active.'
                    : 'Staff will activate your account after verification.',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _access.refresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh status'),
          ),
          const SizedBox(height: 12),
          Text(
            'Need help? Contact the dormitory manager if a submitted item has not been reviewed or your information is incorrect.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  _StepState _documentState(TenantOnboardingStatus status) {
    if (status.documentsVerified) return _StepState.complete;
    if (status.contract == null) return _StepState.waiting;
    final requiresAction = status.requiredRequirements.any(
      (item) => item.status == 'missing' || item.status == 'rejected',
    );
    return requiresAction ? _StepState.action : _StepState.waiting;
  }

  String _documentText(TenantOnboardingStatus status) {
    if (status.documentsVerified) return 'All required documents are verified.';
    if (status.contract == null)
      return 'Available after staff drafts your contract.';
    final verified =
        status.requiredRequirements.where((i) => i.isVerified).length;
    final total = status.requiredRequirements.length;
    final pending = status.requiredRequirements.any((i) => i.isPendingReview);
    return pending
        ? '$verified of $total verified. Submitted documents are under review.'
        : '$verified of $total verified. Upload or resubmit the remaining items.';
  }

  _StepState _signatureState(TenantOnboardingStatus status) {
    if (status.signaturesVerified) return _StepState.complete;
    if (status.contract == null) return _StepState.waiting;
    final requiresAction = status.requiredSigners.any(
      (item) => item.status == 'pending' || item.status == 'rejected',
    );
    return requiresAction ? _StepState.action : _StepState.waiting;
  }

  String _signatureText(TenantOnboardingStatus status) {
    if (status.signaturesVerified)
      return 'All required signatures are verified.';
    if (status.contract == null)
      return 'Available after staff drafts your contract.';
    final signed = status.requiredSigners
        .where((item) => item.status == 'signed' || item.isVerified)
        .length;
    return signed > 0
        ? 'Submitted signatures are waiting for staff verification.'
        : 'Review the agreement and provide the required signature.';
  }
}

enum _StepState { action, waiting, complete }

class _ContractCard extends StatelessWidget {
  const _ContractCard({
    required this.status,
    required this.opening,
    this.onOpen,
  });

  final TenantOnboardingStatus status;
  final bool opening;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final contract = status.contract;
    final scheme = Theme.of(context).colorScheme;

    return CarmelitaCard(
      padding: const EdgeInsets.all(16),
      child: contract == null
          ? Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.description_outlined),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Contract is being prepared'),
                      SizedBox(height: 4),
                      Text(
                          'It will appear here after dormitory staff creates it.'),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: scheme.primary.withAlpha(24),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.description_outlined,
                          color: scheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Contract #${contract.contractNumber}',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${shortDate(contract.startsOn)} – ${shortDate(contract.endsOn)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    StatusPill(contract.status.toUpperCase()),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: opening ? null : onOpen,
                    icon: opening
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.visibility_outlined),
                    label: Text(
                      opening ? 'Opening contract…' : 'View contract',
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ChecklistTile extends StatelessWidget {
  const _ChecklistTile({
    required this.icon,
    required this.title,
    required this.state,
    required this.subtitle,
    this.buttonLabel,
    this.onPressed,
  });

  final IconData icon;
  final String title;
  final _StepState state;
  final String subtitle;
  final String? buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (color, label, stateIcon) = switch (state) {
      _StepState.complete => (
          const Color(0xFF2E7D32),
          'Complete',
          Icons.check_circle_rounded
        ),
      _StepState.waiting => (
          const Color(0xFF1565C0),
          'In review',
          Icons.schedule_rounded
        ),
      _StepState.action => (
          scheme.error,
          'Action needed',
          Icons.error_outline_rounded
        ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CarmelitaCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withAlpha(24),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(subtitle),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(stateIcon, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 10),
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: color)),
            if (buttonLabel != null && state == _StepState.action) ...[
              const SizedBox(height: 12),
              FilledButton(
                onPressed: onPressed,
                child: Text(buttonLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
