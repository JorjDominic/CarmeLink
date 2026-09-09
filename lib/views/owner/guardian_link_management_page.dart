import 'package:flutter/material.dart';

import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/role_guard.dart';
import '../../models/models.dart';
import '../../services/guardian_link_service.dart';

class GuardianLinkManagementPage extends StatefulWidget {
  const GuardianLinkManagementPage({super.key});

  @override
  State<GuardianLinkManagementPage> createState() =>
      _GuardianLinkManagementPageState();
}

class _GuardianLinkManagementPageState
    extends State<GuardianLinkManagementPage> {
  final service = const GuardianLinkService();
  late Future<List<Map<String, dynamic>>> links = service.listLinks();

  void reload() => setState(() => links = service.listLinks());

  Future<void> openEditor([Map<String, dynamic>? link]) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _GuardianLinkEditor(link: link),
    );
    if (changed == true && mounted) {
      reload();
      showAppSnackBar(
        context,
        link == null ? 'Guardian linked.' : 'Guardian link updated.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => RoleGuard(
        allowedRoles: const {UserRole.owner},
        child: PageFrame(
          title: 'Guardian links',
          subtitle: 'Connect guardians to tenant accounts',
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => openEditor(),
            icon: const Icon(Icons.link),
            label: const Text('Add link'),
          ),
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: links,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text('Unable to load links: ${snapshot.error}'),
                );
              }
              final rows = snapshot.data ?? const [];
              if (rows.isEmpty) {
                return const EmptyState(
                  icon: Icons.family_restroom_outlined,
                  title: 'No guardian links',
                  message: 'Add a guardian-to-tenant relationship.',
                );
              }
              return Column(
                children: rows.map((link) {
                  final guardian = link['guardian'] as Map<String, dynamic>?;
                  final tenant = link['tenant'] as Map<String, dynamic>?;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: CarmelitaCard(
                      onTap: () => openEditor(link),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.family_restroom_outlined),
                        title: Text(
                          '${guardian?['full_name'] ?? 'Guardian'} to '
                          '${tenant?['full_name'] ?? 'Tenant'}',
                        ),
                        subtitle: Text(
                          link['relationship'] as String? ?? 'Guardian',
                        ),
                        trailing: link['is_primary'] == true
                            ? const StatusPill('Primary')
                            : const Icon(Icons.chevron_right),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      );
}

class _GuardianLinkEditor extends StatefulWidget {
  const _GuardianLinkEditor({this.link});

  final Map<String, dynamic>? link;

  @override
  State<_GuardianLinkEditor> createState() => _GuardianLinkEditorState();
}

class _GuardianLinkEditorState extends State<_GuardianLinkEditor> {
  final service = const GuardianLinkService();
  late final TextEditingController relationship;
  late final Future<List<List<Map<String, dynamic>>>> options;
  String? guardianId;
  String? tenantId;
  bool isPrimary = false;
  bool loading = false;
  String? error;

  bool get editing => widget.link != null;

  @override
  void initState() {
    super.initState();
    guardianId = widget.link?['guardian_id'] as String?;
    tenantId = widget.link?['tenant_id'] as String?;
    relationship = TextEditingController(
      text: widget.link?['relationship'] as String? ?? 'Guardian',
    );
    isPrimary = widget.link?['is_primary'] as bool? ?? false;
    options = Future.wait([
      service.listProfiles('guardian'),
      service.listProfiles('tenant'),
    ]);
  }

  @override
  void dispose() {
    relationship.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (guardianId == null ||
        tenantId == null ||
        relationship.text.trim().isEmpty) {
      setState(() {
        error = 'Select a guardian and tenant, then enter the relationship.';
      });
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      if (editing) {
        await service.updateLink(
          id: widget.link!['id'] as String,
          tenantId: tenantId!,
          relationship: relationship.text,
          isPrimary: isPrimary,
        );
      } else {
        await service.createLink(
          guardianId: guardianId!,
          tenantId: tenantId!,
          relationship: relationship.text,
          isPrimary: isPrimary,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove guardian link?'),
        content: const Text(
          "The guardian will lose access to this tenant's information.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => loading = true);
    try {
      await service.deleteLink(widget.link!['id'] as String);
      if (mounted) Navigator.pop(context, true);
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => loading = false);
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
        child: FutureBuilder<List<List<Map<String, dynamic>>>>(
          future: options,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('Unable to load accounts: ${snapshot.error}');
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final guardians = snapshot.data![0];
            final tenants = snapshot.data![1];
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    editing ? 'Edit guardian link' : 'Add guardian link',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<String>(
                    initialValue: guardianId,
                    decoration: const InputDecoration(labelText: 'Guardian'),
                    items: guardians
                        .map(
                          (row) => DropdownMenuItem(
                            value: row['id'] as String,
                            child: Text(row['full_name'] as String),
                          ),
                        )
                        .toList(),
                    onChanged: editing || loading
                        ? null
                        : (value) => setState(() => guardianId = value),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: tenantId,
                    decoration: const InputDecoration(labelText: 'Tenant'),
                    items: tenants
                        .map(
                          (row) => DropdownMenuItem(
                            value: row['id'] as String,
                            child: Text(row['full_name'] as String),
                          ),
                        )
                        .toList(),
                    onChanged: editing || loading
                        ? null
                        : (value) => setState(() => tenantId = value),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: relationship,
                    enabled: !loading,
                    decoration:
                        const InputDecoration(labelText: 'Relationship'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Primary guardian'),
                    value: isPrimary,
                    onChanged: loading
                        ? null
                        : (value) => setState(() => isPrimary = value),
                  ),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: loading ? null : save,
                      child: Text(loading ? 'Saving...' : 'Save link'),
                    ),
                  ),
                  if (editing) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: loading ? null : remove,
                        icon: const Icon(Icons.link_off),
                        label: const Text('Remove link'),
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
