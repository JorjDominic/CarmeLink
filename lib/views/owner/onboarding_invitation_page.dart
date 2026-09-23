import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/widgets/common_widgets.dart';
import '../../models/models.dart';
import '../../services/onboarding_invitation_service.dart';

/// Shows the list of onboarding invitations for [tenantId] and lets
/// authorized staff create a new QR invitation or revoke a pending one.
///
/// Typically opened from the Contracts Documents dialog via a button when
/// the tenant's data-entry form has not yet been submitted.
class OnboardingInvitationPage extends StatefulWidget {
  const OnboardingInvitationPage({
    super.key,
    required this.tenantId,
    required this.tenantName,
  });

  final String tenantId;
  final String tenantName;

  @override
  State<OnboardingInvitationPage> createState() =>
      _OnboardingInvitationPageState();
}

class _OnboardingInvitationPageState extends State<OnboardingInvitationPage> {
  final _service = const OnboardingInvitationService();
  late Future<List<OnboardingInvitation>> _future = _load();
  bool _working = false;

  Future<List<OnboardingInvitation>> _load() =>
      _service.listInvitations(tenantId: widget.tenantId);

  void _reload() => setState(() => _future = _load());

  Future<void> _create() async {
    setState(() => _working = true);
    try {
      final invitation = await _service.createInvitation(widget.tenantId);
      if (!mounted) return;
      _reload();
      await _showQr(invitation);
    } catch (error) {
      if (mounted)
        showAppSnackBar(context, 'Could not create invitation: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _revoke(OnboardingInvitation invitation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke invitation?'),
        content: const Text(
          'The QR code linked to this invitation will stop working immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _working = true);
    try {
      await _service.revokeInvitation(invitation.id);
      if (mounted) {
        showAppSnackBar(context, 'Invitation revoked.');
        _reload();
      }
    } catch (error) {
      if (mounted) showAppSnackBar(context, 'Revoke failed: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _showQr(OnboardingInvitation invitation) async {
    await showDialog<void>(
      context: context,
      builder: (_) =>
          _QrDialog(invitation: invitation, tenantName: widget.tenantName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final content = FutureBuilder<List<OnboardingInvitation>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return EmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Could not load invitations',
            message: snapshot.error.toString(),
            action:
                FilledButton(onPressed: _reload, child: const Text('Retry')),
          );
        }
        final invitations = snapshot.data ?? const [];
        final hasPending =
            invitations.any((inv) => inv.isPending && !inv.isExpired);
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(children: [
                Icon(Icons.qr_code_2_rounded,
                    color: Theme.of(context).colorScheme.onPrimaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'QR Onboarding Invitation',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(widget.tenantName),
                    ],
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            Text(
              'Send the QR code to ${widget.tenantName}. They scan it in the CarmeLink '
              'app to submit their personal, academic, and emergency contact '
              'details before you prepare their contract.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _working || hasPending ? null : _create,
              icon: const Icon(Icons.add_rounded),
              label: Text(
                hasPending
                    ? 'An active invitation already exists'
                    : 'Create QR invitation',
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Invitation history',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            if (invitations.isEmpty)
              const EmptyState(
                icon: Icons.qr_code_outlined,
                title: 'No invitations yet',
                message: 'Create the first QR invitation for this tenant.',
              )
            else
              ...invitations.map(
                (inv) => _InvitationCard(
                  invitation: inv,
                  working: _working,
                  onShowQr: () => _showQr(inv),
                  onRevoke: () => _revoke(inv),
                ),
              ),
          ],
        );
      },
    );

    if (compact) {
      return Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
            title: const Text('QR Onboarding'),
          ),
          body: content,
        ),
      );
    }

    return Dialog(
      child: SizedBox(
        width: 580,
        height: 680,
        child: Column(children: [
          ListTile(
            title: const Text('QR Onboarding Invitation'),
            subtitle: Text(widget.tenantName),
            trailing: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ),
          const Divider(height: 1),
          Expanded(child: content),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Invitation card
// ---------------------------------------------------------------------------

class _InvitationCard extends StatelessWidget {
  const _InvitationCard({
    required this.invitation,
    required this.working,
    required this.onShowQr,
    required this.onRevoke,
  });

  final OnboardingInvitation invitation;
  final bool working;
  final VoidCallback onShowQr;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final status = invitation.isExpired ? 'expired' : invitation.status;
    final statusColor = _statusColor(context, status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CarmelitaCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.qr_code_2_rounded),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Invitation created ${shortDate(invitation.createdAt)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withAlpha(80)),
                ),
                child: Text(
                  _statusLabel(status),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 6),
            Text(
              invitation.isCompleted
                  ? 'Completed ${shortDate(invitation.completedAt!)}'
                  : 'Expires ${shortDate(invitation.expiresAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (invitation.isPending && !invitation.isExpired) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 8, children: [
                TextButton.icon(
                  onPressed: working ? null : onShowQr,
                  icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                  label: const Text('Show QR'),
                ),
                TextButton.icon(
                  onPressed: working ? null : onRevoke,
                  icon: const Icon(Icons.block_outlined, size: 18),
                  label: const Text('Revoke'),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  static String _statusLabel(String status) => switch (status) {
        'completed' => 'Completed',
        'expired' => 'Expired',
        'revoked' => 'Revoked',
        _ => 'Active',
      };

  static Color _statusColor(BuildContext context, String status) =>
      switch (status) {
        'completed' => Colors.green,
        'expired' || 'revoked' => Theme.of(context).colorScheme.error,
        _ => Theme.of(context).colorScheme.primary,
      };
}

// ---------------------------------------------------------------------------
// QR code dialog
// ---------------------------------------------------------------------------

class _QrDialog extends StatelessWidget {
  const _QrDialog({required this.invitation, required this.tenantName});

  final OnboardingInvitation invitation;
  final String tenantName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('QR Onboarding Code'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Ask $tenantName to scan this code in the CarmeLink app to '
            'submit their onboarding information.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: QrImageView(
              data: invitation.deepLink,
              version: QrVersions.auto,
              size: 220,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Colors.black,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Expires ${shortDate(invitation.expiresAt)} · Single use',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

/// Opens the QR invitation manager as a dialog.
Future<void> showOnboardingInvitations(
  BuildContext context, {
  required String tenantId,
  required String tenantName,
}) async {
  await showDialog<void>(
    context: context,
    builder: (_) => OnboardingInvitationPage(
      tenantId: tenantId,
      tenantName: tenantName,
    ),
  );
}
