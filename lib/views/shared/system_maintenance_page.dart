import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../controllers/session_controller.dart';
import '../../core/widgets/common_widgets.dart';
import '../../models/models.dart';
import '../../services/system_maintenance_service.dart';
import '../owner/dormitory_configuration_page.dart';
import 'account_management_page.dart';
import 'retention_settings_page.dart';

class SystemMaintenancePage extends StatefulWidget {
  const SystemMaintenancePage(
      {super.key,
      this.service = const SystemMaintenanceService(),
      this.session});
  final SystemMaintenanceService service;
  final ValueListenable<AppUser?>? session;
  @override
  State<SystemMaintenancePage> createState() => _SystemMaintenancePageState();
}

class _SystemMaintenancePageState extends State<SystemMaintenancePage> {
  SystemMaintenanceService get service => widget.service;
  AppUser? get user => widget.session != null
      ? widget.session!.value
      : SessionController.instance.currentUser;
  bool get staff =>
      user?.role == UserRole.owner || user?.role == UserRole.caretaker;
  int generation = 0;
  final message = TextEditingController();
  Map<String, dynamic>? settings;
  List<Map<String, dynamic>> audit = [], backups = [];
  bool busy = false;
  String? error;
  bool get owner => user?.role == UserRole.owner;
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
    final request = ++generation;
    if (!staff) return;
    try {
      final latest = await service.settings();
      final events = await service.audit();
      final saved = owner ? await service.backups() : <Map<String, dynamic>>[];
      if (!mounted || request != generation) return;
      setState(() {
        settings = latest;
        audit = events;
        backups = saved;
        message.text = latest['message'] as String;
        error = null;
      });
    } catch (e) {
      if (mounted && request == generation)
        setState(() {
          settings = null;
          backups = [];
          audit = [];
          error = 'Unable to load system maintenance. Please retry.';
        });
    }
  }

  Future<void> run(Future<void> Function() action, {String? success}) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
      await load();
      if (mounted && success != null) showAppSnackBar(context, success);
    } catch (e) {
      if (mounted)
        setState(() => error =
            'Could not confirm the action. Refresh the page before retrying.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> saveMode(bool enabled) async {
    final value = message.text.trim();
    if (value.length < 5 || value.length > 500) {
      showAppSnackBar(
          context, 'Enter a maintenance message of 5 to 500 characters.');
      return;
    }
    final current = settings;
    if (current == null) return;
    final changed = current['enabled'] != enabled;
    await run(
        () => service.save(enabled, value, current['updated_at'] as String),
        success: changed
            ? (enabled ? 'Maintenance started.' : 'Maintenance ended.')
            : 'Maintenance message saved.');
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
    if (confirmed == true)
      await run(() => service.restore(id),
          success: 'Configuration restored. A safety backup was saved.');
  }

  void open(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: widget.session ?? SessionController.instance,
      builder: (context, _) => !staff
          ? const PageFrame(
              title: 'System maintenance',
              subtitle: 'Staff access required',
              child: SizedBox.shrink())
          : PageFrame(
              title: 'System maintenance',
              subtitle:
                  'Administration, availability and configuration recovery',
              onRefresh: () async {
                if (!busy) await load();
              },
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      OutlinedButton(
                          onPressed: () => open(const AccountManagementPage()),
                          child: const Text('User accounts')),
                      OutlinedButton(
                          onPressed: () => open(const RetentionSettingsPage()),
                          child: const Text('Security & retention')),
                      if (owner)
                        OutlinedButton(
                            onPressed: () =>
                                open(const DormitoryConfigurationPage()),
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
                          decoration: const InputDecoration(
                              labelText: 'Maintenance message')),
                      if (owner)
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          OutlinedButton(
                              onPressed: busy
                                  ? null
                                  : () =>
                                      saveMode(settings!['enabled'] == true),
                              child: const Text('Save message')),
                          FilledButton(
                              onPressed: busy
                                  ? null
                                  : () =>
                                      saveMode(settings!['enabled'] != true),
                              child: Text(settings!['enabled'] == true
                                  ? 'End maintenance'
                                  : 'Start maintenance')),
                        ]),
                    ] else if (error == null)
                      const LinearProgressIndicator(),
                    const SizedBox(height: 20),
                    if (owner) ...[
                      const SectionTitle('Configuration backups'),
                      const Text(
                          'Saved snapshots cover custom dormitory options only. Restore uses the saved server snapshot; downloaded JSON is an export. Full database, account and file recovery uses the hosting platform backup tools.'),
                      FilledButton(
                          onPressed: busy
                              ? null
                              : () => run(service.backup,
                                  success: 'Configuration backup created.'),
                          child: const Text('Create configuration backup')),
                      for (final backup in backups)
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Wrap(
                                spacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(DateTime.parse(
                                          backup['created_at'] as String)
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
                                                        utf8.encode(
                                                            const JsonEncoder
                                                                    .withIndent(
                                                                    '  ')
                                                                .convert(
                                                                    payload))));
                                              }),
                                      child: const Text('Download')),
                                  TextButton(
                                      onPressed: busy
                                          ? null
                                          : () =>
                                              restore(backup['id'] as String),
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
