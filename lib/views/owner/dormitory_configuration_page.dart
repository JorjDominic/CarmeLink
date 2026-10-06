import 'package:flutter/material.dart';

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
                        (option.categoryCode ?? 'other')
                            .replaceAll('_', ' '),
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
    order.dispose();
    if (mounted) await _load();
  }

  Future<void> _toggle(DormitoryOption option) async {
    if (option.isSystem) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(option.isActive ? 'Deactivate choice?' : 'Reactivate choice?'),
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
            child: const Text('Confirm'),
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
              decoration: const InputDecoration(labelText: 'Configuration group'),
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
                setState(() => _groupKey = value);
                _load();
              },
            ),
            const SizedBox(height: 12),
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
            for (final option in _options)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(option.label),
                subtitle: Text(
                  option.isSystem
                      ? 'Protected system choice'
                      : option.isActive
                          ? 'Active • order ${option.sortOrder}'
                          : 'Inactive • order ${option.sortOrder}',
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
                          Switch(
                            value: option.isActive,
                            onChanged: (_) => _toggle(option),
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
