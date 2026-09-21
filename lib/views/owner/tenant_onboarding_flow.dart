import 'package:flutter/material.dart';

import '../../core/widgets/common_widgets.dart';
import '../../services/guardian_link_service.dart';
import '../../services/tenant_service.dart';

Future<void> continueTenantOnboarding(
  BuildContext context, {
  required String tenantId,
  required String tenantName,
  bool fromSavedContract = true,
}) async {
  final proceed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.task_alt_rounded),
      title: Text(fromSavedContract ? 'Contract saved' : 'Continue onboarding'),
      content: Text(
        'Continue $tenantName\'s onboarding with room and bed assignment, then guardian linking.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Finish later'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Continue onboarding'),
        ),
      ],
    ),
  );
  if (proceed != true || !context.mounted) return;

  await _assignBedStep(context, tenantId: tenantId, tenantName: tenantName);
  if (!context.mounted) return;
  await _guardianStep(context, tenantId: tenantId, tenantName: tenantName);
}

Future<void> _assignBedStep(
  BuildContext context, {
  required String tenantId,
  required String tenantName,
}) async {
  const service = TenantService();
  try {
    final tenants = await service.loadTenants(forceRefresh: true);
    final tenant = tenants.where((item) => item.id == tenantId).firstOrNull;
    if (tenant?.assignmentId != null) {
      if (context.mounted) {
        showAppSnackBar(
          context,
          '$tenantName is already assigned to Room ${tenant!.room} • ${tenant.bedSpace}.',
        );
      }
      return;
    }
    final rooms = await service.loadAvailableBedsGroupedByRoom();
    if (!context.mounted) return;
    if (rooms.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('No available beds'),
          content: const Text(
            'Room assignment will remain incomplete. You can continue with guardian linking now.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      return;
    }
    final bed = await showModalBottomSheet<AvailableBed>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _BedAssignmentSheet(
        rooms: rooms,
        tenantName: tenantName,
      ),
    );
    if (bed == null || !context.mounted) return;
    await service.assignBed(tenantId, bed.id);
    if (context.mounted) {
      showAppSnackBar(
        context,
        '$tenantName assigned to Room ${bed.room} • ${bed.label}.',
      );
    }
  } catch (error) {
    if (context.mounted) {
      showAppSnackBar(context, tenantOnboardingError(error));
    }
  }
}

Future<void> _guardianStep(
  BuildContext context, {
  required String tenantId,
  required String tenantName,
}) async {
  const service = GuardianLinkService();
  try {
    final links = await service.listLinks();
    if (links.any((link) => link['tenant_id'] == tenantId)) {
      if (context.mounted) {
        showAppSnackBar(context, '$tenantName already has a guardian link.');
      }
      return;
    }
    final guardians = await service.listProfiles('guardian');
    if (!context.mounted) return;
    if (guardians.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Guardian account required'),
          content: const Text(
            'Create a guardian account first, then resume guardian linking from Operations.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Finish'),
            ),
          ],
        ),
      );
      return;
    }
    final linked = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _GuardianLinkStep(
        tenantId: tenantId,
        tenantName: tenantName,
        guardians: guardians,
        service: service,
      ),
    );
    if (linked == true && context.mounted) {
      showAppSnackBar(context, 'Guardian linked to $tenantName.');
    }
  } catch (error) {
    if (context.mounted) {
      showAppSnackBar(context, 'Guardian linking could not be loaded: $error');
    }
  }
}

String tenantOnboardingError(Object error) {
  final message = error.toString();
  if (message.contains('no longer available') ||
      message.contains('tenant_assignments_one_active_per_bed')) {
    return 'That bed was just assigned. Choose another bed from the tenant directory.';
  }
  if (message.contains('Staff access required') || message.contains('42501')) {
    return 'Your account is not authorized to assign beds.';
  }
  return 'Room assignment could not be completed. You can resume it from the tenant directory.';
}

class _BedAssignmentSheet extends StatelessWidget {
  const _BedAssignmentSheet({
    required this.rooms,
    required this.tenantName,
  });

  final List<RoomWithAvailableBeds> rooms;
  final String tenantName;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .82,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Assign room and bed',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text('Select an available bed for $tenantName.'),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: rooms
                      .map(
                        (room) => ExpansionTile(
                          initiallyExpanded: room == rooms.first,
                          title: Text('Room ${room.roomNumber}'),
                          subtitle: Text(
                            '${room.floor} • ${room.beds.length} available',
                          ),
                          children: room.beds
                              .map(
                                (bed) => ListTile(
                                  leading: const Icon(Icons.bed_outlined),
                                  title: Text(bed.label),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => Navigator.pop(context, bed),
                                ),
                              )
                              .toList(),
                        ),
                      )
                      .toList(),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Skip for now'),
                ),
              ),
            ],
          ),
        ),
      );
}

class _GuardianLinkStep extends StatefulWidget {
  const _GuardianLinkStep({
    required this.tenantId,
    required this.tenantName,
    required this.guardians,
    required this.service,
  });

  final String tenantId;
  final String tenantName;
  final List<Map<String, dynamic>> guardians;
  final GuardianLinkService service;

  @override
  State<_GuardianLinkStep> createState() => _GuardianLinkStepState();
}

class _GuardianLinkStepState extends State<_GuardianLinkStep> {
  final relationship = TextEditingController(text: 'Guardian');
  String? guardianId;
  bool primary = true;
  bool saving = false;
  String? error;

  @override
  void dispose() {
    relationship.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (guardianId == null || relationship.text.trim().isEmpty) {
      setState(() => error = 'Select a guardian and enter the relationship.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.service.createLink(
        guardianId: guardianId!,
        tenantId: widget.tenantId,
        relationship: relationship.text,
        isPrimary: primary,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Link guardian',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text('Choose the guardian for ${widget.tenantName}.'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: guardianId,
                decoration: const InputDecoration(labelText: 'Guardian'),
                items: widget.guardians
                    .map(
                      (guardian) => DropdownMenuItem(
                        value: guardian['id'] as String,
                        child: Text(guardian['full_name'] as String),
                      ),
                    )
                    .toList(),
                onChanged: saving
                    ? null
                    : (value) => setState(() => guardianId = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: relationship,
                enabled: !saving,
                decoration: const InputDecoration(labelText: 'Relationship'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Primary guardian'),
                value: primary,
                onChanged:
                    saving ? null : (value) => setState(() => primary = value),
              ),
              if (error != null)
                Text(error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: saving ? null : _save,
                  icon: saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.link),
                  label: Text(saving ? 'Linking...' : 'Link guardian'),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: const Text('Skip for now'),
                ),
              ),
            ],
          ),
        ),
      );
}
