import 'package:flutter/material.dart';

import '../../models/staff_tenant_option.dart';
import 'numbered_pagination.dart';

class StaffTenantPickerField extends StatelessWidget {
  const StaffTenantPickerField({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.labelText = 'Tenant',
    this.activeOnly = true,
    this.enabled = true,
  });

  final List<StaffTenantOption> options;
  final String? value;
  final ValueChanged<String> onChanged;
  final String labelText;
  final bool activeOnly;
  final bool enabled;

  StaffTenantOption? get _selected {
    for (final option in options) {
      if (option.id == value) return option;
    }
    return null;
  }

  Future<void> _open(BuildContext context) async {
    if (!enabled || options.isEmpty) return;
    final selected = await showDialog<StaffTenantOption>(
      context: context,
      builder: (context) => _StaffTenantPickerDialog(
        options: options,
        selectedId: value,
        activeOnly: activeOnly,
      ),
    );
    if (selected != null) onChanged(selected.id);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Semantics(
      button: true,
      enabled: enabled,
      label: labelText,
      child: InkWell(
        onTap: enabled ? () => _open(context) : null,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: labelText,
            floatingLabelBehavior: FloatingLabelBehavior.always,
            enabled: enabled,
            suffixIcon: const Icon(Icons.manage_search_outlined),
          ),
          isEmpty: false,
          child: selected == null
              ? Text(
                  'Search and select a tenant',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).hintColor,
                      ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      selected.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      selected.locationLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _StaffTenantPickerDialog extends StatefulWidget {
  const _StaffTenantPickerDialog({
    required this.options,
    required this.selectedId,
    required this.activeOnly,
  });

  final List<StaffTenantOption> options;
  final String? selectedId;
  final bool activeOnly;

  @override
  State<_StaffTenantPickerDialog> createState() =>
      _StaffTenantPickerDialogState();
}

class _StaffTenantPickerDialogState extends State<_StaffTenantPickerDialog> {
  static const int _pageSize = 8;
  final _search = TextEditingController();
  String? _floor;
  String? _room;
  int _page = 1;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<String> get _floors {
    final values = widget.options
        .where((item) => item.floor.trim().isNotEmpty)
        .map((item) => item.floor.trim())
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }

  List<String> get _rooms {
    final values = widget.options
        .where((item) =>
            item.isAssigned && (_floor == null || item.floor == _floor))
        .map((item) => item.room)
        .toSet()
        .toList()
      ..sort((a, b) {
        final aNumber = int.tryParse(a);
        final bNumber = int.tryParse(b);
        if (aNumber != null && bNumber != null) {
          return aNumber.compareTo(bNumber);
        }
        return a.toLowerCase().compareTo(b.toLowerCase());
      });
    return values;
  }

  List<StaffTenantOption> get _filtered {
    final query = _search.text.trim().toLowerCase();
    final values = widget.options.where((item) {
      if (widget.activeOnly && !item.isActiveResident) return false;
      if (_floor != null && item.floor != _floor) return false;
      if (_room != null && item.room != _room) return false;
      if (query.isEmpty) return true;
      return item.name.toLowerCase().contains(query) ||
          item.room.toLowerCase().contains(query) ||
          item.floor.toLowerCase().contains(query) ||
          item.bed.toLowerCase().contains(query);
    }).toList(growable: false)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return values;
  }

  void _resetPage() => setState(() => _page = 1);

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final pageCount =
        filtered.isEmpty ? 1 : ((filtered.length + _pageSize - 1) ~/ _pageSize);
    if (_page > pageCount) _page = pageCount;
    final start = (_page - 1) * _pageSize;
    final end = start + _pageSize > filtered.length
        ? filtered.length
        : start + _pageSize;
    final visible = filtered.sublist(start, end);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Select tenant',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _search,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Search tenant',
                  hintText: 'Name, room, floor or bed',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _search.clear();
                            _resetPage();
                          },
                          icon: const Icon(Icons.clear),
                        ),
                ),
                onChanged: (_) => _resetPage(),
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 500;
                  final floorField = DropdownButtonFormField<String?>(
                    key: ValueKey('floor-${_floor ?? 'all'}'),
                    initialValue: _floor,
                    decoration: const InputDecoration(labelText: 'Floor'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All floors'),
                      ),
                      ..._floors.map(
                        (value) => DropdownMenuItem<String?>(
                          value: value,
                          child: Text(value),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _floor = value;
                        _room = null;
                        _page = 1;
                      });
                    },
                  );
                  final roomField = DropdownButtonFormField<String?>(
                    key: ValueKey(
                      'room-${_floor ?? 'all'}-${_room ?? 'all'}',
                    ),
                    initialValue: _room,
                    decoration: const InputDecoration(labelText: 'Room'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All rooms'),
                      ),
                      ..._rooms.map(
                        (value) => DropdownMenuItem<String?>(
                          value: value,
                          child: Text('Room $value'),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _room = value;
                        _page = 1;
                      });
                    },
                  );
                  if (compact) {
                    return Column(
                      children: [
                        floorField,
                        const SizedBox(height: 8),
                        roomField,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: floorField),
                      const SizedBox(width: 10),
                      Expanded(child: roomField),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${filtered.length} matching tenant${filtered.length == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: (_floor == null &&
                            _room == null &&
                            _search.text.isEmpty)
                        ? null
                        : () {
                            _search.clear();
                            setState(() {
                              _floor = null;
                              _room = null;
                              _page = 1;
                            });
                          },
                    icon: const Icon(Icons.filter_alt_off_outlined),
                    label: const Text('Clear filters'),
                  ),
                ],
              ),
              const Divider(height: 16),
              Expanded(
                child: visible.isEmpty
                    ? const Center(
                        child: Text('No tenants match the current filters.'),
                      )
                    : ListView.separated(
                        itemCount: visible.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = visible[index];
                          return ListTile(
                            title: Text(item.name),
                            subtitle: Text(item.locationLabel),
                            selected: item.id == widget.selectedId,
                            trailing: item.id == widget.selectedId
                                ? const Icon(Icons.check_circle_outline)
                                : const Icon(Icons.chevron_right),
                            onTap: () => Navigator.pop(context, item),
                          );
                        },
                      ),
              ),
              NumberedPaginationBar(
                currentPage: _page,
                totalItems: filtered.length,
                pageSize: _pageSize,
                itemLabel: 'tenants',
                onPageChanged: (value) => setState(() => _page = value),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
