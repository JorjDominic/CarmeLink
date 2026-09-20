import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/web_theme.dart';
import 'demo_catalog.dart';
import 'demo_store.dart';

const _brown = WebPalette.plum;
const _muted = WebPalette.muted;
const _border = WebPalette.border;
const _paper = WebPalette.surface;

class DemoBadge extends StatelessWidget {
  const DemoBadge({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12, vertical: 7),
    decoration: BoxDecoration(
      color: WebPalette.sand,
      borderRadius: BorderRadius.circular(40),
      border: Border.all(color: _border),
    ),
    child: Text('LOCAL DEMO',
      style: TextStyle(fontSize: compact ? 9 : 10,
        color: _brown, fontWeight: FontWeight.w800, letterSpacing: .6)),
  );
}

class DemoSectionCard extends StatelessWidget {
  const DemoSectionCard({super.key, required this.child, this.padding = const EdgeInsets.all(22)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: _paper,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: _border),
      boxShadow: [BoxShadow(color: _brown.withValues(alpha: .035),
        offset: const Offset(0, 8), blurRadius: 24)],
    ),
    // Keep ink effects above the painted card background. ListTiles and
    // InkWells must have a Material ancestor without a ColoredBox between.
    child: Material(type: MaterialType.transparency, child: child),
  );
}

class DemoKpi extends StatelessWidget {
  const DemoKpi({super.key, required this.label, required this.value,
    required this.icon, this.subtitle = '', this.onTap});
  final String label;
  final String value;
  final IconData icon;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => DemoSectionCard(
    // Reserve more room inside short dashboard grid tiles.
    padding: const EdgeInsets.all(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted,
                  fontWeight: FontWeight.w600, fontSize: 13)),
            ),
            const SizedBox(width: 8),
            Icon(icon, color: _brown, size: 22),
          ]),
          const SizedBox(height: 11),
          Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: WebPalette.ink,
              fontSize: 28, letterSpacing: -1,
              fontWeight: FontWeight.w800)),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted, fontSize: 12)),
          ],
        ],
      ),
    ),
  );
}

class DemoRecordEditor extends StatefulWidget {
  const DemoRecordEditor({super.key, required this.store, required this.module,
    required this.role, this.original});
  final DemoStore store;
  final DemoModule module;
  final Map<String, String>? original;
  final String role;

  @override
  State<DemoRecordEditor> createState() => _DemoRecordEditorState();
}

class _DemoRecordEditorState extends State<DemoRecordEditor> {
  final _key = GlobalKey<FormState>();
  final Map<String, TextEditingController> _inputs = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final field in widget.module.fields) {
      final initial = widget.original?[field.key] ??
          ((field.kind == DemoFieldKind.choice && field.options.isNotEmpty)
              ? field.options.first : '');
      _inputs[field.key] = TextEditingController(text: initial);
    }
  }

  @override
  void dispose() {
    for (final controller in _inputs.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _date(DemoField field) async {
    final existing = DateTime.tryParse(_inputs[field.key]!.text);
    final chosen = await showDatePicker(
      context: context,
      firstDate: DateTime(2000), lastDate: DateTime(2100),
      initialDate: existing ?? DateTime.now(),
    );
    if (chosen == null || !mounted) return;
    _inputs[field.key]!.text =
      '${chosen.year.toString().padLeft(4, '0')}-${chosen.month.toString().padLeft(2, '0')}-${chosen.day.toString().padLeft(2, '0')}';
  }

  void _save() {
    if (!_key.currentState!.validate()) return;
    if (widget.module.ownerOnly && widget.role != 'Owner') return;
    final values = <String, String>{};
    for (final entry in _inputs.entries) {
      values[entry.key] = entry.value.text.trim();
    }
    // A caretaker cannot create or promote a demo account to owner.
    if (widget.module.id == 'accounts' && widget.role != 'Owner' &&
        (values['role'] == 'Owner' || widget.original?['role'] == 'Owner')) {
      setState(() => _error = 'Only the owner can manage an owner account.');
      return;
    }
    final problem = widget.store.save(widget.module.id, values,
      editingId: widget.original?['id']);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    Navigator.of(context).pop(true);
  }

  Widget _field(DemoField field) {
    final ctrl = _inputs[field.key]!;
    if (field.kind == DemoFieldKind.choice || field.kind == DemoFieldKind.reference) {
      final options = field.kind == DemoFieldKind.choice
          ? field.options.map((value) => (value, value)).toList()
          : widget.store.rows(field.reference!).map((row) =>
              (row['id']!, row['name'] ?? row['id']!)).toList();
      final allowed = options.any((value) => value.$1 == ctrl.text);
      return DropdownButtonFormField<String>(
        initialValue: allowed ? ctrl.text : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: field.label,
          helperText: field.reference != null ? 'Select a demo record' : null),
        items: [
          if (!field.isRequired) const DropdownMenuItem<String>(
            value: '', child: Text('None / unassigned')),
          ...options.map((value) => DropdownMenuItem<String>(
              value: value.$1, child: Text(value.$2, overflow: TextOverflow.ellipsis))),
        ],
        onChanged: (value) => setState(() => ctrl.text = value ?? ''),
        validator: (value) => field.isRequired && (value ?? '').isEmpty
            ? '${field.label} is required.' : null,
      );
    }
    return TextFormField(
      controller: ctrl,
      readOnly: field.kind == DemoFieldKind.date,
      onTap: field.kind == DemoFieldKind.date ? () => _date(field) : null,
      minLines: field.kind == DemoFieldKind.paragraph ? 3 : 1,
      maxLines: field.kind == DemoFieldKind.paragraph ? 5 : 1,
      keyboardType: field.kind == DemoFieldKind.number
          ? const TextInputType.numberWithOptions(decimal: true)
          : field.kind == DemoFieldKind.email
              ? TextInputType.emailAddress
              : field.kind == DemoFieldKind.phone
                  ? TextInputType.phone : TextInputType.text,
      decoration: InputDecoration(
        labelText: field.label, hintText: field.hint.isEmpty ? null : field.hint,
        suffixIcon: field.kind == DemoFieldKind.date
          ? const Icon(Icons.calendar_month_outlined) : null,
      ),
      validator: (value) => field.isRequired && (value ?? '').trim().isEmpty
          ? '${field.label} is required.' : null,
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: _paper,
    title: Text(widget.original == null ? 'Add ${widget.module.title}'
        : 'Edit ${widget.module.title}'),
    content: SizedBox(
      width: 520,
      child: Form(
        key: _key,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Changes affect this local demo only.',
                  style: TextStyle(color: _muted, fontSize: 12)),
              const SizedBox(height: 16),
              ...widget.module.fields.map((field) => Padding(
                padding: const EdgeInsets.only(bottom: 14), child: _field(field))),
              if (_error != null) Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(_error!, style: const TextStyle(color: WebPalette.danger))),
            ]),
          ),
        ),
      ),
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel')),
      FilledButton(onPressed: _save, child: Text(widget.original == null
          ? 'Add record' : 'Save changes')),
    ],
  );
}

class DemoModulePage extends StatefulWidget {
  const DemoModulePage({super.key, required this.module, required this.store,
    required this.role});
  final DemoModule module;
  final DemoStore store;
  final String role;

  @override
  State<DemoModulePage> createState() => _DemoModulePageState();
}

class _DemoModulePageState extends State<DemoModulePage> {
  final TextEditingController _search = TextEditingController();
  String _statusFilter = 'All';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _edit([Map<String, String>? row]) async {
    await showDialog<bool>(context: context,
      builder: (context) => DemoRecordEditor(store: widget.store,
        module: widget.module, role: widget.role, original: row));
  }

  Future<void> _delete(Map<String, String> row) async {
    if (widget.module.id == 'accounts' && widget.role != 'Owner' &&
        row['role'] == 'Owner') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Only the owner can remove an owner account.')));
      return;
    }
    final answer = await showDialog<bool>(context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete sample record?'),
        content: Text('Delete "${row['name']}" from the local demo?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ));
    if (answer != true || !mounted) return;
    final result = widget.store.delete(widget.module.id, row['id']!);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result ?? 'Sample record deleted.')));
  }

  void _details(Map<String, String> row) {
    showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
      backgroundColor: _paper,
      title: Text(row['name'] ?? 'Record details'),
      content: SizedBox(width: 500, child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Local demo record', style: TextStyle(color: _muted)),
          const SizedBox(height: 12),
          ...widget.module.fields.map((field) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(field.label, style: const TextStyle(color: _muted, fontSize: 12)),
              Text(field.reference != null
                  ? widget.store.label(field.reference!, row[field.key] ?? '')
                  : (row[field.key] ?? '').isEmpty ? '—' : row[field.key]!,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ]),
          )),
        ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close')),
        FilledButton(onPressed: () {
          Navigator.pop(dialogContext);
          _edit(row);
        }, child: const Text('Edit record')),
      ],
    ));
  }

  String _display(DemoField field, Map<String, String> row) {
    final value = row[field.key] ?? '';
    if (field.reference != null) return widget.store.label(field.reference!, value);
    if (field.kind == DemoFieldKind.number &&
        ['amount'].contains(field.key)) {
      return '₱${double.tryParse(value)?.toStringAsFixed(2) ?? value}';
    }
    return value.isEmpty ? '—' : value;
  }

  Widget _status(Map<String, String> row) {
    final options = widget.module.statusOptions;
    if (options.isEmpty) return const SizedBox.shrink();
    return DropdownButton<String>(
      value: options.contains(row['status']) ? row['status'] : null,
      isDense: true, underline: const SizedBox.shrink(),
      items: options.map((s) => DropdownMenuItem(value: s,
          child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
      onChanged: (value) {
        if (value == null) return;
        final result = widget.store.updateStatus(widget.module.id, row['id']!, value);
        if (result != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
        }
      },
    );
  }

  Widget _actions(Map<String, String> row) => Row(mainAxisSize: MainAxisSize.min, children: [
    IconButton(tooltip: 'View', icon: const Icon(Icons.visibility_outlined, size: 20),
      onPressed: () => _details(row)),
    IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_outlined, size: 20),
      onPressed: () => _edit(row)),
    if (widget.module.allowDelete)
      IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline, size: 20),
        onPressed: () => _delete(row)),
  ]);

  @override
  Widget build(BuildContext context) {
    if (widget.module.ownerOnly && widget.role != 'Owner') {
      return const Center(child: Text('This demo area is owner-only.'));
    }
    return AnimatedBuilder(animation: widget.store, builder: (context, _) {
      final query = _search.text.trim().toLowerCase();
      final allRows = widget.store.rows(widget.module.id);
      final rows = allRows.where((row) {
        final searchable = widget.module.fields.map((field) =>
          _display(field, row)).join(' ').toLowerCase();
        return searchable.contains(query) &&
          (_statusFilter == 'All' || row['status'] == _statusFilter);
      }).toList();
      final width = MediaQuery.sizeOf(context).width;
      final compact = width < 770;
      final visible = widget.module.visibleFields;
      return ListView(padding: const EdgeInsets.all(28), children: [
        Text(widget.module.title, style: const TextStyle(
          fontSize: 32, fontWeight: FontWeight.w800,
          letterSpacing: -1, color: WebPalette.ink)),
        const SizedBox(height: 5),
        Text(widget.module.subtitle, style: const TextStyle(color: _muted)),
        const SizedBox(height: 20),
        DemoSectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(spacing: 10, runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center, children: [
                SizedBox(width: compact ? 250 : 320, child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Search records', prefixIcon: Icon(Icons.search),
                    isDense: true),
                )),
                if (widget.module.statusOptions.isNotEmpty)
                  DropdownButton<String>(
                    value: _statusFilter,
                    items: ['All', ...widget.module.statusOptions]
                      .map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (s) => setState(() => _statusFilter = s ?? 'All'),
                  ),
                OutlinedButton.icon(onPressed: () async {
                  await Clipboard.setData(ClipboardData(
                    text: widget.store.exportCsv(widget.module.id)));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Demo CSV copied to clipboard.')));
                }, icon: const Icon(Icons.copy_all_outlined, size: 18),
                  label: const Text('Copy CSV')),
                if (widget.module.allowCreate)
                  FilledButton.icon(onPressed: () => _edit(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add record')),
              ]),
            const SizedBox(height: 14),
            Text('${rows.length} of ${allRows.length} sample records',
              style: const TextStyle(color: _muted, fontSize: 12)),
            const SizedBox(height: 14),
            if (rows.isEmpty)
              const Padding(padding: EdgeInsets.all(36),
                child: Center(child: Text('No matching records. Try another search or add one.')))
            else if (compact)
              ...rows.map((row) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Container(padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: WebPalette.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _border)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(row['name'] ?? 'Record',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 7),
                    ...visible.skip(1).take(3).map((field) => Text(
                      '${field.label}: ${_display(field, row)}',
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _muted, fontSize: 12))),
                    Row(children: [if (widget.module.statusOptions.isNotEmpty) _status(row),
                      const Spacer(), _actions(row)]),
                  ])),
              ))
            else SingleChildScrollView(scrollDirection: Axis.horizontal,
              child: DataTable(
                dataRowMinHeight: 54, dataRowMaxHeight: 68,
                headingRowColor: WidgetStatePropertyAll(WebPalette.sand),
                columnSpacing: 28,
                columns: [
                  ...visible.map((field) => DataColumn(label: Text(field.label))),
                  if (widget.module.statusOptions.isNotEmpty)
                    const DataColumn(label: Text('Change status')),
                  const DataColumn(label: Text('Actions')),
                ],
                rows: rows.map((row) => DataRow(cells: [
                  ...visible.map((field) => DataCell(
                    ConstrainedBox(constraints: const BoxConstraints(maxWidth: 190),
                      child: Text(_display(field, row), maxLines: 2,
                        overflow: TextOverflow.ellipsis)))),
                  if (widget.module.statusOptions.isNotEmpty)
                    DataCell(_status(row)),
                  DataCell(_actions(row)),
                ])).toList(),
              ),
            ),
          ])),
      ]);
    });
  }
}

/// Optional public-to-staff inquiry flow for the debug-only demo entry point.
/// Intentionally not part of the production landing page or Supabase.
class DemoPublicInquiryDialog extends StatefulWidget {
  const DemoPublicInquiryDialog({super.key, required this.store});
  final DemoStore store;

  @override
  State<DemoPublicInquiryDialog> createState() => _DemoPublicInquiryDialogState();
}

class _DemoPublicInquiryDialogState extends State<DemoPublicInquiryDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _message = TextEditingController();
  String? _error;
  bool _sent = false;

  @override
  void dispose() {
    _name.dispose(); _email.dispose(); _phone.dispose(); _message.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final result = widget.store.save('inquiries', {
      'name': _name.text.trim(), 'email': _email.text.trim(),
      'phone': _phone.text.trim(), 'details': _message.text.trim(),
      'status': 'New',
    });
    if (result != null) {
      setState(() => _error = result);
      return;
    }
    setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: WebPalette.surface,
    title: Text(_sent ? 'Saved in this demo' : 'Try the inquiry form'),
    content: SizedBox(width: 480,
      child: _sent
        ? const Text('Your sample inquiry appears in the Staff Portal → Inquiries section. It was not sent to the dormitory, and will disappear on reload.')
        : SingleChildScrollView(child: Form(key: _form,
            child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('Fictional information only. This demo does not send messages or collect real inquiries.',
                  style: TextStyle(color: WebPalette.muted, fontSize: 12)),
                const SizedBox(height: 14),
                TextFormField(controller: _name,
                  decoration: const InputDecoration(labelText: 'Your name'),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a name.' : null),
                const SizedBox(height: 12),
                TextFormField(controller: _email,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v ?? '').contains('@') ? null : 'Enter an email.'),
                const SizedBox(height: 12),
                TextFormField(controller: _phone,
                  decoration: const InputDecoration(labelText: 'Phone (optional)'),
                  keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                TextFormField(controller: _message, minLines: 3, maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Your inquiry'),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Enter an inquiry.' : null),
                if (_error != null) Text(_error!,
                  style: const TextStyle(color: WebPalette.danger)),
              ]))),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(),
        child: Text(_sent ? 'Done' : 'Cancel')),
      if (!_sent) FilledButton(onPressed: _submit,
        child: const Text('Save demo inquiry')),
    ],
  );
}
