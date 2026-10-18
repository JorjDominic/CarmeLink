import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../controllers/session_controller.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/role_guard.dart';
import '../../models/models.dart';
import '../../services/system_maintenance_service.dart';
import '../owner/dormitory_configuration_page.dart';
import 'account_management_page.dart';
import 'retention_settings_page.dart';

class SystemMaintenancePage extends StatefulWidget {
  const SystemMaintenancePage({super.key});
  @override
  State<SystemMaintenancePage> createState() => _SystemMaintenancePageState();
}

class _SystemMaintenancePageState extends State<SystemMaintenancePage> {
  final service = const SystemMaintenanceService();
  final message = TextEditingController();
  Map<String, dynamic>? settings;
  List<Map<String, dynamic>> audit = [], backups = [];
  bool busy = false;
  String? error;
  bool get owner =>
      SessionController.instance.currentUser?.role == UserRole.owner;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    message.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final latest = await service.settings();
      final events = await service.audit();
      final saved = owner ? await service.backups() : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        settings = latest;
        audit = events;
        backups = saved;
        message.text = latest['message'] as String;
        error = null;
      });
    } catch (e) {
      if (mounted)
        setState(() {
          settings = null;
          error = e.toString();
        });
    }
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
      await load();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> restore(String id) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Restore configuration?'),
                content: const Text(
                    'Restore the labels, instructions, order and active status of custom options in this backup. Newer options stay unchanged. A safety backup is created first. Accounts, tenant records, files and maintenance mode are unchanged.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Restore'))
                ]));
    if (confirmed == true) await run(() => service.restore(id));
  }

  void open(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  @override
  Widget build(BuildContext context) => RoleGuard(
      allowedRoles: const {UserRole.owner, UserRole.caretaker},
      child: PageFrame(
          title: 'System maintenance',
          subtitle: 'Administration, availability and configuration recovery',
          onRefresh: load,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton(
                  onPressed: () => open(const AccountManagementPage()),
                  child: const Text('User accounts')),
              OutlinedButton(
                  onPressed: () => open(const RetentionSettingsPage()),
                  child: const Text('Security & retention')),
              if (owner)
                OutlinedButton(
                    onPressed: () => open(const DormitoryConfigurationPage()),
                    child: const Text('App configuration')),
            ]),
            const SizedBox(height: 16),
            if (error != null) ...[
              Text(error!),
              TextButton(onPressed: load, child: const Text('Retry'))
            ],
            if (settings != null) ...[
              Text(
                  'Maintenance mode: ${settings!['enabled'] == true ? 'On' : 'Off'}',
                  style: Theme.of(context).textTheme.titleMedium),
              const Text(
                  'Pauses tenant and guardian access in the updated app. Staff retain access. Existing integrations and older app versions are not suspended.'),
              TextField(
                  controller: message,
                  readOnly: !owner || busy,
                  maxLength: 500,
                  maxLines: 3,
                  decoration:
                      const InputDecoration(labelText: 'Maintenance message')),
              if (owner)
                FilledButton(
                    onPressed: busy
                        ? null
                        : () => run(() => service.save(
                            settings!['enabled'] != true,
                            message.text.trim(),
                            settings!['updated_at'] as String)),
                    child: Text(settings!['enabled'] == true
                        ? 'End maintenance'
                        : 'Start maintenance')),
            ] else if (error == null)
              const LinearProgressIndicator(),
            const SizedBox(height: 20),
            if (owner) ...[
              const SectionTitle('Configuration backups'),
              const Text(
                  'Saved snapshots cover custom dormitory options only. Restore uses the saved server snapshot; downloaded JSON is an export. Full database, account and file recovery uses the hosting platform backup tools.'),
              FilledButton(
                  onPressed: busy ? null : () => run(service.backup),
                  child: const Text('Create configuration backup')),
              for (final backup in backups)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(DateTime.parse(backup['created_at'] as String)
                              .toLocal()
                              .toString()),
                          OutlinedButton(
                              onPressed: busy
                                  ? null
                                  : () => run(() async {
                                        final payload =
                                            await service.backupPayload(
                                                backup['id'] as String);
                                        await FilePicker.saveFile(
                                            dialogTitle:
                                                'Export configuration backup',
                                            fileName:
                                                'carmelink-configuration-${backup['id']}.json',
                                            bytes: Uint8List.fromList(
                                                utf8.encode(const JsonEncoder
                                                        .withIndent('  ')
                                                    .convert(payload))));
                                      }),
                              child: const Text('Download')),
                          TextButton(
                              onPressed: busy
                                  ? null
                                  : () => restore(backup['id'] as String),
                              child: const Text('Restore')),
                        ])),
            ],
            const SizedBox(height: 20),
            const SectionTitle('System maintenance audit'),
            const Text(
                'Latest 100 maintenance and configuration backup actions.'),
            if (audit.isEmpty) const Text('No actions recorded.'),
            for (final event in audit)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                      '${event['action'].toString().replaceAll('_', ' ')}\n${DateTime.parse(event['created_at'] as String).toLocal()} · ${event['actor_id']}\n${jsonEncode(event['details'])}')),
          ])));
}
