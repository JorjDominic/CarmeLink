import 'package:flutter/material.dart';

import '../../core/utils/conduct_case_policy.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/searchable_dropdown.dart';
import '../../core/widgets/staff_tenant_picker.dart';
import '../../models/staff_tenant_option.dart';
import '../../services/conduct_case_service.dart';

class ConductCaseCreateDialog extends StatefulWidget {
  const ConductCaseCreateDialog({
    super.key,
    required this.service,
    required this.tenants,
  });

  final ConductCaseService service;
  final List<StaffTenantOption> tenants;

  @override
  State<ConductCaseCreateDialog> createState() =>
      _ConductCaseCreateDialogState();
}

class _ConductCaseCreateDialogState extends State<ConductCaseCreateDialog> {
  String? _tenantId;
  String _category = 'rule_violation';
  String _source = 'manual';
  String? _sourceRecordId;
  DateTime _incidentAt = DateTime.now();
  bool _saving = false;
  bool _loadingSources = false;
  String? _sourceError;
  List<ConductSourceOption> _sourceOptions = const [];

  final _categoryDetail = TextEditingController();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _sourceDetail = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _categoryDetail.dispose();
    _title.dispose();
    _description.dispose();
    _sourceDetail.dispose();
    super.dispose();
  }

  bool get _sourceCanLink => _source != 'manual' && _source != 'other';

  Future<void> _loadSourceOptions() async {
    final tenantId = _tenantId;
    if (!_sourceCanLink || tenantId == null || tenantId.isEmpty) {
      if (mounted) {
        setState(() {
          _sourceOptions = const [];
          _sourceRecordId = null;
          _sourceError = null;
          _loadingSources = false;
        });
      }
      return;
    }
    setState(() {
      _loadingSources = true;
      _sourceError = null;
      _sourceRecordId = null;
      _sourceOptions = const [];
    });
    try {
      final items = await widget.service.listSourceOptions(
        tenantId: tenantId,
        sourceModule: _source,
      );
      if (!mounted) return;
      setState(() {
        _sourceOptions = items;
        _loadingSources = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingSources = false;
        _sourceError = conductCaseError(error);
      });
    }
  }

  Future<void> _pickIncidentDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _incidentAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_incidentAt),
    );
    if (time == null) return;
    setState(() {
      _incidentAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  String _dateTimeLabel(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour == 0
        ? 12
        : local.hour > 12
            ? local.hour - 12
            : local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.month}/${local.day}/${local.year} • $hour:$minute $period';
  }

  String _sourceOptionLabel(String id) {
    final option = _sourceOptions.where((item) => item.id == id).firstOrNull;
    if (option == null) return 'Linked record';
    final date = option.occurredAt.toLocal();
    final when = '${date.month}/${date.day}/${date.year}';
    return '${option.title} • $when';
  }

  Future<void> _save() async {
    final tenantId = _tenantId;
    if (tenantId == null || tenantId.isEmpty) {
      showAppSnackBar(context, 'Select a tenant before creating the case.');
      return;
    }
    if (_category == 'other') {
      final error = validateConductOtherDetail(
        _categoryDetail.text,
        fieldLabel: 'the case category',
      );
      if (error != null) {
        showAppSnackBar(context, error);
        return;
      }
    }
    if (_source == 'other') {
      final error = validateConductOtherDetail(
        _sourceDetail.text,
        fieldLabel: 'the record source',
      );
      if (error != null) {
        showAppSnackBar(context, error);
        return;
      }
    }
    final titleError = validateConductCaseTitle(_title.text);
    if (titleError != null) {
      showAppSnackBar(context, titleError);
      return;
    }
    final descriptionError = validateConductCaseDescription(_description.text);
    if (descriptionError != null) {
      showAppSnackBar(context, descriptionError);
      return;
    }
    if (_incidentAt.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
      showAppSnackBar(context, 'Incident time cannot be in the future.');
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.service.createCase(
        tenantId: tenantId,
        category: _category,
        categoryDetail:
            _category == 'other' ? _categoryDetail.text.trim() : null,
        title: _title.text,
        description: _description.text,
        incidentAt: _incidentAt,
        sourceModule: _source,
        sourceRecordId: _sourceCanLink ? _sourceRecordId : null,
        sourceDetail: _source == 'other' ? _sourceDetail.text.trim() : null,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(context, conductCaseError(error));
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sourceItems = _sourceOptions
        .map(
          (item) => DropdownMenuItem<String>(
            value: item.id,
            child: Text(_sourceOptionLabel(item.id)),
          ),
        )
        .toList(growable: false);

    return AlertDialog(
      title: const Text('Create conduct case'),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CarmelitaCard(
                padding: const EdgeInsets.all(12),
                child: const Text(
                  'Record the incident for review. Creating a case does not decide guilt, create a charge, or terminate a tenancy.',
                ),
              ),
              const SizedBox(height: 14),
              StaffTenantPickerField(
                options: widget.tenants,
                value: _tenantId,
                enabled: !_saving,
                onChanged: (value) {
                  setState(() {
                    _tenantId = value;
                    _sourceRecordId = null;
                  });
                  if (_sourceCanLink) _loadSourceOptions();
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: conductCaseCategories
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(conductCategoryLabel(value)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() {
                          _category = value;
                          if (value != 'other') _categoryDetail.clear();
                        });
                      },
              ),
              if (_category == 'other') ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _categoryDetail,
                  enabled: !_saving,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Please specify category',
                    hintText: 'Describe the specific type of conduct concern',
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _title,
                enabled: !_saving,
                maxLength: 160,
                decoration: const InputDecoration(labelText: 'Case title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                enabled: !_saving,
                minLines: 3,
                maxLines: 6,
                maxLength: 4000,
                decoration: const InputDecoration(
                  labelText: 'Incident description',
                  hintText:
                      'Record observed or reported facts without deciding guilt.',
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_outlined),
                title: const Text('Incident date and time'),
                subtitle: Text(_dateTimeLabel(_incidentAt)),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: _saving ? null : _pickIncidentDateTime,
              ),
              const SizedBox(height: 4),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                leading: const Icon(Icons.link_outlined),
                title: const Text('Link supporting record (optional)'),
                subtitle: Text(conductSourceLabel(_source)),
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _source,
                    decoration:
                        const InputDecoration(labelText: 'Record source'),
                    items: conductCaseSources
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(conductSourceLabel(value)),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _saving
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() {
                              _source = value;
                              _sourceRecordId = null;
                              _sourceError = null;
                              _sourceOptions = const [];
                              if (value != 'other') _sourceDetail.clear();
                            });
                            _loadSourceOptions();
                          },
                  ),
                  if (_source == 'other') ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _sourceDetail,
                      enabled: !_saving,
                      maxLength: 120,
                      decoration: const InputDecoration(
                        labelText: 'Please specify source',
                        hintText: 'Example: Verbal complaint from caretaker',
                      ),
                    ),
                  ],
                  if (_sourceCanLink) ...[
                    const SizedBox(height: 10),
                    if (_loadingSources)
                      const LinearProgressIndicator()
                    else if (_sourceError != null)
                      CarmelitaCard(child: Text(_sourceError!))
                    else if (_sourceOptions.isEmpty)
                      const CarmelitaCard(
                        child: Text(
                          'No matching records were found for this tenant. You can still create the case without linking a record.',
                        ),
                      )
                    else
                      SearchableDropdownFormField<String>(
                        initialValue: _sourceRecordId,
                        decoration: const InputDecoration(
                          labelText: 'Linked record (optional)',
                        ),
                        hint: const Text('Choose a record'),
                        items: sourceItems,
                        itemLabel: _sourceOptionLabel,
                        onChanged: _saving
                            ? null
                            : (value) =>
                                setState(() => _sourceRecordId = value),
                      ),
                    if (_sourceRecordId != null) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _saving
                              ? null
                              : () => setState(() => _sourceRecordId = null),
                          icon: const Icon(Icons.link_off_outlined),
                          label: const Text('Remove linked record'),
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Creating…' : 'Create draft'),
        ),
      ],
    );
  }
}
