import 'package:flutter/material.dart';

import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/numbered_pagination.dart';
import '../../core/widgets/role_guard.dart';
import '../../core/widgets/searchable_dropdown.dart';
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
  static const _pageSize = 6;

  String _groupKey = 'maintenance_category';
  String _query = '';
  String _visibility = 'active';
  int _page = 1;
  List<DormitoryOption> _options = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _resetPage() {
    _page = 1;
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
                  decoration: const InputDecoration(
                    labelText: 'Label',
                    helperText:
                        'Choices are sorted alphabetically. Other stays last.',
                  ),
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
                          value: 'roommate_concern',
                          child: Text('Roommate concern'),
                        ),
                        DropdownMenuItem(
                          value: 'rule_violation',
                          child: Text('Rule violation'),
                        ),
                        DropdownMenuItem(
                          value: 'safety_concern',
                          child: Text('Safety concern'),
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
                  Text(
                    message!,
                    style: TextStyle(
                      color: Theme.of(dialogContext).colorScheme.error,
                    ),
                  ),
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
                      updateDialog(() {
                        saving = true;
                        message = null;
                      });
                      try {
                        await _service.save(
                          existing: option,
                          groupKey: _groupKey,
                          label: label.text,
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
    if (mounted) {
      setState(_resetPage);
      await _load();
    }
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
      if (mounted) {
        setState(_resetPage);
        await _load();
      }
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'Could not update this choice.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final needle = _query.trim().toLowerCase();
    final visibleOptions = _options.where((option) {
      final matchesSearch =
          needle.isEmpty || option.label.toLowerCase().contains(needle);
      final matchesVisibility =
          _visibility == 'all' || option.isActive == (_visibility == 'active');
      return matchesSearch && matchesVisibility;
    }).toList()
      ..sort(DormitoryConfigurationService.compareOptions);

    final pageCount = visibleOptions.isEmpty
        ? 1
        : (visibleOptions.length + _pageSize - 1) ~/ _pageSize;
    final safePage = _page > pageCount ? pageCount : _page;
    final start = (safePage - 1) * _pageSize;
    final pagedOptions =
        visibleOptions.skip(start).take(_pageSize).toList(growable: false);

    final groupEntries = DormitoryConfigurationService.sortedGroupEntries();

    return RoleGuard(
      allowedRoles: const {UserRole.owner},
      child: PageFrame(
        title: 'Dormitory configuration',
        subtitle:
            'Manage choices used by new records while preserving existing history',
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
                for (final entry in groupEntries)
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
                  _visibility = 'active';
                  _resetPage();
                });
                _load();
              },
            ),
            const SizedBox(height: 12),
            ChoiceSearchField(
              key: ValueKey(_groupKey),
              hintText: 'Search choices by name',
              onChanged: (value) => setState(() {
                _query = value;
                _resetPage();
              }),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'active', label: Text('Active')),
                ButtonSegment(value: 'archived', label: Text('Archived')),
                ButtonSegment(value: 'all', label: Text('All')),
              ],
              selected: {_visibility},
              onSelectionChanged: (values) => setState(() {
                _visibility = values.first;
                _resetPage();
              }),
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
                message: 'Add a choice to make it available in new records.',
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
            for (final option in pagedOptions)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(option.label),
                subtitle: Text(
                  option.isSystem
                      ? 'Protected system choice'
                      : option.isActive
                          ? 'Active'
                          : 'Archived',
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
                            icon: Icon(
                              option.isActive
                                  ? Icons.archive_outlined
                                  : Icons.restore,
                            ),
                            onPressed: () => _toggle(option),
                          ),
                        ],
                      ),
              ),
            NumberedPaginationBar(
              currentPage: safePage,
              totalItems: visibleOptions.length,
              pageSize: _pageSize,
              itemLabel: 'choices',
              onPageChanged: (page) => setState(() => _page = page),
            ),
          ],
        ),
      ),
    );
  }
}
