import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/widgets/common_widgets.dart';
import '../../models/models.dart';
import '../../services/onboarding_invitation_service.dart';

/// Shows the tenant's onboarding profile status (emergency contact & academic details)
/// and allows authorized staff to edit details directly or issue QR onboarding invitations.
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
  late Future<List<OnboardingInvitation>> _futureInvitations = _loadInvitations();
  late Future<Map<String, dynamic>?> _futureDetails = _loadDetails();
  bool _working = false;

  Future<List<OnboardingInvitation>> _loadInvitations() =>
      _service.listInvitations(tenantId: widget.tenantId);

  Future<Map<String, dynamic>?> _loadDetails() =>
      _service.getMyTenantDetails(widget.tenantId);

  void _reload() {
    setState(() {
      _futureInvitations = _loadInvitations();
      _futureDetails = _loadDetails();
    });
  }

  Future<void> _create() async {
    setState(() => _working = true);
    try {
      await _service.createInvitation(widget.tenantId);
      if (!mounted) return;
      _reload();
      if (mounted) {
        showAppSnackBar(context, 'QR invitation created.');
      }
    } catch (error) {
      if (mounted) {
        showAppSnackBar(context, 'Could not create invitation: $error');
      }
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

  Future<void> _openEditDetailsDialog(Map<String, dynamic>? current) async {
    final nameCtrl = TextEditingController(
      text: current?['emergency_contact_name']?.toString() ?? '',
    );
    final phoneCtrl = TextEditingController(
      text: current?['emergency_contact_phone']?.toString() ?? '',
    );
    final relCtrl = TextEditingController(
      text: current?['emergency_contact_relationship']?.toString() ?? '',
    );
    final schoolCtrl = TextEditingController(
      text: current?['school_name']?.toString() ?? '',
    );
    final courseCtrl = TextEditingController(
      text: current?['course_or_program']?.toString() ?? '',
    );
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Details — ${widget.tenantName}'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Emergency contact information is required before activating the tenant contract.',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Emergency contact name *',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) => (v == null || v.trim().length < 2)
                      ? 'Please enter contact name'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Emergency contact phone *',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (v) => (v == null || v.trim().length < 7)
                      ? 'Please enter valid phone'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: relCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Relationship (e.g., Parent, Guardian) *',
                    prefixIcon: Icon(Icons.family_restroom_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().length < 2)
                      ? 'Please enter relationship'
                      : null,
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Academic background (Optional)',
                  style: Theme.of(ctx).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: schoolCtrl,
                  decoration: const InputDecoration(
                    labelText: 'School / University',
                    prefixIcon: Icon(Icons.school_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: courseCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Course / Program',
                    prefixIcon: Icon(Icons.book_outlined),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Save Details'),
          ),
        ],
      ),
    );

    if (saved == true) {
      setState(() => _working = true);
      try {
        await _service.submitTenantDetailsDirectly(
          targetTenantId: widget.tenantId,
          emergencyContactName: nameCtrl.text.trim(),
          emergencyContactPhone: phoneCtrl.text.trim(),
          emergencyContactRelationship: relCtrl.text.trim(),
          schoolName: schoolCtrl.text.trim(),
          courseOrProgram: courseCtrl.text.trim(),
        );
        if (mounted) {
          showAppSnackBar(context, 'Tenant details saved successfully.');
          _reload();
        }
      } catch (e) {
        if (mounted) showAppSnackBar(context, 'Could not save details: $e');
      } finally {
        if (mounted) setState(() => _working = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final content = FutureBuilder<
        (List<OnboardingInvitation>, Map<String, dynamic>?)>(
      future: Future.wait([
        _futureInvitations,
        _futureDetails,
      ]).then((results) => (
            results[0] as List<OnboardingInvitation>,
            results[1] as Map<String, dynamic>?,
          )),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return EmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Could not load details',
            message: snapshot.error.toString(),
            action:
                FilledButton(onPressed: _reload, child: const Text('Retry')),
          );
        }

        final invitations = snapshot.data?.$1 ?? const [];
        final details = snapshot.data?.$2;

        final ecName =
            details?['emergency_contact_name']?.toString().trim() ?? '';
        final ecPhone =
            details?['emergency_contact_phone']?.toString().trim() ?? '';
        final ecRel =
            details?['emergency_contact_relationship']?.toString().trim() ?? '';
        final school = details?['school_name']?.toString().trim() ?? '';
        final course = details?['course_or_program']?.toString().trim() ?? '';

        final isComplete =
            ecName.length >= 2 && ecPhone.length >= 7 && ecRel.length >= 2;

        final activeInvitation = invitations
            .where((inv) => inv.isPending && !inv.isExpired)
            .firstOrNull;

        final scheme = Theme.of(context).colorScheme;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Tenant Header Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(children: [
                Icon(Icons.assignment_ind_rounded,
                    color: scheme.onPrimaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tenant Onboarding & Profile',
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
            const SizedBox(height: 18),

            // Profile status card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isComplete
                    ? Colors.green.withAlpha(20)
                    : Colors.amber.withAlpha(25),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isComplete
                      ? Colors.green.withAlpha(90)
                      : Colors.amber.withAlpha(120),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isComplete
                            ? Icons.check_circle_rounded
                            : Icons.warning_amber_rounded,
                        color: isComplete ? Colors.green : Colors.amber.shade800,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isComplete
                              ? 'Emergency Contact & Profile Completed'
                              : 'Emergency Contact & Profile Pending',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isComplete
                                ? Colors.green.shade800
                                : Colors.amber.shade900,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _working
                            ? null
                            : () => _openEditDetailsDialog(details),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: Text(isComplete ? 'Edit' : 'Enter manually'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (isComplete) ...[
                    Text(
                      'Emergency Contact: $ecName ($ecRel) • $ecPhone',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (school.isNotEmpty || course.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Academic: ${[school, course].where((s) => s.isNotEmpty).join(' • ')}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ] else ...[
                    Text(
                      'The tenant can complete this directly in their CarmeLink app upon logging in, or you can enter their details manually using the button above.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Optional QR section
            Text(
              'Optional: QR Invitation Link',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'If the tenant prefers scanning or opening a link, you can provide the invitation code below.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),

            if (activeInvitation != null) ...[
              Card(
                elevation: 0,
                color: scheme.surfaceContainerHighest.withAlpha(120),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: scheme.outlineVariant.withAlpha(100),
                  ),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(20),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: QrImageView(
                          data: activeInvitation.deepLink,
                          version: QrVersions.auto,
                          size: 180,
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
                      const SizedBox(height: 12),
                      Text(
                        'Expires ${shortDate(activeInvitation.expiresAt)} · Single use',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: activeInvitation.deepLink),
                              );
                              showAppSnackBar(
                                context,
                                'Onboarding link copied to clipboard.',
                              );
                            },
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            label: const Text('Copy link'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _working
                                ? null
                                : () => _revoke(activeInvitation),
                            style: FilledButton.styleFrom(
                              foregroundColor: scheme.error,
                            ),
                            icon: const Icon(Icons.block_outlined, size: 18),
                            label: const Text('Revoke'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              FilledButton.icon(
                onPressed: _working ? null : _create,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Generate QR invitation'),
              ),
            ],

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
                title: 'No invitations created',
                message:
                    'Tenants can submit their profile directly without a QR code.',
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
            title: const Text('Tenant Onboarding'),
          ),
          body: content,
        ),
      );
    }

    return Dialog(
      child: SizedBox(
        width: 580,
        height: 700,
        child: Column(children: [
          ListTile(
            title: const Text('Tenant Onboarding & Profile'),
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
                  onPressed: onShowQr,
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
          Text(
            'Expires ${shortDate(invitation.expiresAt)} · Single use',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
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

/// Opens the onboarding manager as a dialog.
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
