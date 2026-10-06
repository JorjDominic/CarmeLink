import 'package:flutter/material.dart';
import '../../core/widgets/searchable_dropdown.dart';

import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/role_guard.dart';
import '../../models/models.dart';
import '../../services/dormitory_configuration_service.dart';

class DormitoryConfigurationPage extends StatefulWidget {
  const DormitoryConfigurationPage({super.key});

  @override
  State<DormitoryConfigurationPage> createState() =>
      _DormitoryConfigurationPageState();
}

class _DormitoryConfigurationPageState
    extends State<DormitoryConfigurationPage> {
  static const _service = DormitoryConfigurationService();

  String _groupKey = 'maintenance_category';
  String _query = '';
  String _visibility = 'active';
  List<DormitoryOption> _options = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final requestedGroup = _groupKey;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final options = await _service.options(requestedGroup, activeOnly: false);
      if (!mounted || requestedGroup != _groupKey) return;
      setState(() {
        _options = options;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || requestedGroup != _groupKey) return;
      setState(() {
        _loading = false;
        _error = 'Could not load configuration. Please retry.';
      });
    }
  }

  Future<void> _edit([DormitoryOption? option]) async {
    final label = TextEditingController(text: option?.label ?? '');
    final instructions =
        TextEditingController(text: option?.instructions ?? '');
    final order = TextEditingController(
      text: '${option?.sortOrder ?? (_options.length + 1)}',
    );
    var categoryCode = option?.categoryCode ?? 'rule_violation';
    var saving = false;
    String? message;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, updateDialog) => AlertDialog(
          title: Text(option == null ? 'Add choice' : 'Edit choice'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: label,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'Label'),
                ),
                TextField(
                  controller: order,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Display order'),
                ),
                if (_groupKey == 'payment_method')
                  TextField(
                    controller: instructions,
                    maxLength: 1000,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Payment instructions / account details',
                      helperText:
                          'Visible to tenants when they select this method.',
                    ),
                  ),
                if (_groupKey == 'report_type') ...[
                  const SizedBox(height: 10),
                  if (option == null)
                    DropdownButtonFormField<String>(
                      initialValue: categoryCode,
                      decoration: const InputDecoration(
                        labelText: 'Workflow category',
                        helperText:
                            'The visible label is editable; this workflow mapping stays fixed.',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'safety_concern',
                          child: Text('Safety concern'),
                        ),
                        DropdownMenuItem(
                          value: 'rule_violation',
                          child: Text('Rule violation'),
                        ),
                        DropdownMenuItem(
                          value: 'roommate_concern',
                          child: Text('Roommate concern'),
                        ),
                        DropdownMenuItem(
                          value: 'other',
                          child: Text('Other'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) categoryCode = value;
                      },
                    )
                  else
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.lock_outline),
                      title: const Text('Workflow category'),
                      subtitle: Text(
                        (option.categoryCode ?? 'other').replaceAll('_', ' '),
                      ),
                    ),
                ],
                if (message != null) ...[
                  const SizedBox(height: 8),
                  Text(message!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final position = int.tryParse(order.text.trim());
                      if (position == null) {
                        updateDialog(
                          () => message = 'Enter a valid display order.',
                        );
                        return;
                      }
                      updateDialog(() {
                        saving = true;
                        message = null;
                      });
                      try {
                        await _service.save(
                          existing: option,
                          groupKey: _groupKey,
                          label: label.text,
                          sortOrder: position,
                          categoryCode: categoryCode,
                          instructions: instructions.text,
                        );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                      } catch (_) {
                        if (dialogContext.mounted) {
                          updateDialog(() {
                            saving = false;
                            message =
                                'Could not save. Check for duplicate labels and try again.';
                          });
                        }
                      }
                    },
              child: Text(saving ? 'Saving...' : 'Save'),
            ),
          ],
        ),
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 200));
    label.dispose();
    instructions.dispose();
    order.dispose();
    if (mounted) await _load();
  }

  Future<void> _toggle(DormitoryOption option) async {
    if (option.isSystem) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(option.isActive ? 'Archive choice?' : 'Restore choice?'),
        content: const Text(
          'Existing records keep their saved labels. Only new selections are affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(option.isActive ? 'Archive' : 'Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.setActive(option, !option.isActive);
      if (mounted) await _load();
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'Could not update this choice.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleOptions = _options
        .where(
          (option) =>
              option.label.toLowerCase().contains(_query) &&
              (_visibility == 'all' ||
                  option.isActive == (_visibility == 'active')),
        )
        .toList();
    return RoleGuard(
      allowedRoles: const {UserRole.owner},
      child: PageFrame(
        title: 'Dormitory configuration',
        subtitle:
            'Manage choices used by new reports while preserving existing history',
        onRefresh: _load,
        actions: [
          IconButton(
            onPressed: _loading ? null : () => _edit(),
            icon: const Icon(Icons.add),
            tooltip: 'Add choice',
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _groupKey,
              decoration:
                  const InputDecoration(labelText: 'Configuration group'),
              items: [
                for (final entry
                    in DormitoryConfigurationService.groups.entries)
                  DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
              ],
              onChanged: (value) {
                if (value == null || value == _groupKey) return;
                setState(() {
                  _groupKey = value;
                  _query = '';
                });
                _load();
              },
            ),
            const SizedBox(height: 12),
            ChoiceSearchField(
              key: ValueKey(_groupKey),
              hintText: 'Search choices by name',
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'active', label: Text('Active')),
                ButtonSegment(value: 'archived', label: Text('Archived')),
                ButtonSegment(value: 'all', label: Text('All')),
              ],
              selected: {_visibility},
              onSelectionChanged: (values) =>
                  setState(() => _visibility = values.first),
            ),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_error!),
                trailing: IconButton(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                ),
              ),
            if (!_loading && _error == null && _options.isEmpty)
              const EmptyState(
                icon: Icons.tune_outlined,
                title: 'No choices yet',
                message: 'Add a choice to make it available in new reports.',
              ),
            if (!_loading &&
                _error == null &&
                _options.isNotEmpty &&
                visibleOptions.isEmpty)
              const EmptyState(
                icon: Icons.search_off,
                title: 'No matching choices',
                message: 'Try another name or clear your search.',
              ),
            for (final option in visibleOptions)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(option.label),
                subtitle: Text(
                  option.isSystem
                      ? 'Protected system choice'
                      : option.isActive
                          ? 'Active • order ${option.sortOrder}'
                          : 'Archived • order ${option.sortOrder}',
                ),
                trailing: option.isSystem
                    ? const Icon(Icons.lock_outline)
                    : Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            onPressed: () => _edit(option),
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Edit',
                          ),
                          IconButton(
                            tooltip: option.isActive
                                ? 'Archive choice'
                                : 'Restore choice',
                            icon: Icon(option.isActive
                                ? Icons.archive_outlined
                                : Icons.restore),
                            onPressed: () => _toggle(option),
                          ),
                        ],
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
