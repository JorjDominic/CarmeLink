import 'package:flutter/material.dart';

import '../../core/widgets/common_widgets.dart';
import '../../services/staff_maintenance_service.dart';

class StaffMaintenancePage extends StatefulWidget {
  const StaffMaintenancePage({super.key});

  @override
  State<StaffMaintenancePage> createState() => _StaffMaintenancePageState();
}

class _StaffMaintenancePageState extends State<StaffMaintenancePage> {
  final _service = const StaffMaintenanceService();
  late Future<List<StaffMaintenanceReport>> _reports;

  @override
  void initState() {
    super.initState();
    _reports = _service.listReports();
  }

  void _refresh() => setState(() => _reports = _service.listReports());

  @override
  Widget build(BuildContext context) => PageFrame(
        title: 'Maintenance management',
        subtitle: 'Tenant reports, status updates, and history',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ),
            FutureBuilder<List<StaffMaintenanceReport>>(
              future: _reports,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Text(staffMaintenanceError(snapshot.error!));
                }
                final reports = snapshot.data!;
                if (reports.isEmpty)
                  return const Text('No maintenance reports.');
                return CarmelitaCard(
                  child: Column(
                    children: reports
                        .map((report) => ListTile(
                              title: Text(
                                  '${report.category} • ${report.location}'),
                              subtitle: Text(
                                  '${report.tenantName}\n${report.description}\nPriority: ${report.urgency}'),
                              trailing: Text(report.statusLabel),
                              onTap: () async {
                                await Navigator.of(context)
                                    .push(MaterialPageRoute<void>(
                                  builder: (_) => _StaffMaintenanceDetailsPage(
                                      id: report.id),
                                ));
                                if (mounted) _refresh();
                              },
                            ))
                        .toList(),
                  ),
                );
              },
            ),
          ],
        ),
      );
}

class _StaffMaintenanceDetailsPage extends StatefulWidget {
  const _StaffMaintenanceDetailsPage({required this.id});
  final String id;

  @override
  State<_StaffMaintenanceDetailsPage> createState() =>
      _StaffMaintenanceDetailsPageState();
}

class _StaffMaintenanceDetailsPageState
    extends State<_StaffMaintenanceDetailsPage> {
  final _service = const StaffMaintenanceService();
  final _notes = TextEditingController();
  StaffMaintenanceReport? _report;
  List<Map<String, dynamic>> _history = [];
  String? _photoUrl;
  String? _photoError;
  String? _error;
  String? _status;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final report = await _service.getReport(widget.id);
      final history = await _service.history(widget.id);
      String? photo;
      String? photoError;
      try {
        photo = await _service.photoUrl(report.photoPath);
      } catch (error) {
        photoError = staffMaintenanceError(error);
      }
      if (!mounted) return;
      setState(() {
        _report = report;
        _history = history;
        _photoUrl = photo;
        _photoError = photoError;
        _status = report.status;
        _notes.text = report.notes;
      });
    } catch (error) {
      if (mounted) setState(() => _error = staffMaintenanceError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if ((_status == 'resolved' || _status == 'cancelled') &&
        _notes.text.trim().isEmpty) {
      setState(
          () => _error = 'Add resolution details or a cancellation reason.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _service.save(_report!, _status!, _notes.text);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) setState(() => _error = staffMaintenanceError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    return Scaffold(
      appBar: AppBar(title: const Text('Maintenance details'), actions: [
        IconButton(
            onPressed: _loading || _saving ? null : _load,
            tooltip: 'Reload report',
            icon: const Icon(Icons.refresh)),
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    ),
                  if (report != null) ...[
                    Text('${report.category} • ${report.location}',
                        style: Theme.of(context).textTheme.titleLarge),
                    Text('${report.tenantName} • ${report.urgency} priority'),
                    Text('Submitted: ${report.createdAt}'),
                    const SizedBox(height: 16),
                    Text(report.description),
                    const SizedBox(height: 16),
                    if (_photoUrl != null)
                      Image.network(_photoUrl!,
                          height: 260,
                          fit: BoxFit.contain,
                          errorBuilder: (_, error, stackTrace) => const Text(
                              'Photo could not be loaded. Reload to retry.')),
                    if (_photoError != null) Text('Photo: $_photoError'),
                    if (report.photoPath == null || report.photoPath!.isEmpty)
                      const Text('No photo attached.'),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: allowedMaintenanceStatuses(report.status)
                          .map((status) => DropdownMenuItem(
                                value: status,
                                child: Text(
                                    maintenanceStatusLabels[status] ?? status),
                              ))
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _status = value),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                        controller: _notes,
                        enabled: !_saving,
                        maxLength: 2000,
                        minLines: 3,
                        maxLines: 6,
                        decoration: const InputDecoration(
                            labelText: 'Staff / resolution notes')),
                    FilledButton(
                        onPressed: _saving ? null : _save,
                        child: Text(_saving ? 'Saving…' : 'Save')),
                    const SizedBox(height: 24),
                    Text('History',
                        style: Theme.of(context).textTheme.titleMedium),
                    if (_history.isEmpty) const Text('No staff updates yet.'),
                    ..._history.map((entry) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                              '${maintenanceStatusLabels[entry['previous_status']] ?? entry['previous_status']} → ${maintenanceStatusLabels[entry['next_status']] ?? entry['next_status']}'),
                          subtitle: Text(
                              '${entry['actor_name']} • ${DateTime.parse(entry['created_at'] as String).toLocal()}\n${entry['notes']}'),
                        )),
                  ],
                ],
              ),
            ),
    );
  }
}
