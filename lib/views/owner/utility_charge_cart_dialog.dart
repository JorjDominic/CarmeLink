import 'package:flutter/material.dart';

import '../../controllers/owner_controller.dart';

class UtilityChargeCartDialog extends StatefulWidget {
  const UtilityChargeCartDialog({super.key});

  @override
  State<UtilityChargeCartDialog> createState() =>
      _UtilityChargeCartDialogState();
}

class _UtilityChargeCartDialogState extends State<UtilityChargeCartDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  final List<_UtilityCartLine> _cart = [];
  String _scope = 'individual';
  String _category = 'electricity';
  String _allocation = 'equal_per_tenant';
  String? _tenantId;
  final Set<String> _rooms = {};
  late DateTime _periodStart;
  late DateTime _periodEnd;
  late DateTime _dueDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _periodStart = DateTime(now.year, now.month, 1);
    _periodEnd = DateTime(now.year, now.month + 1, 0);
    _dueDate = DateTime(now.year, now.month + 1, 10);
    final tenants = OwnerController.instance.tenants;
    if (tenants.isNotEmpty) _tenantId = tenants.first.id;
  }

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  String _categoryTitle(String value) => switch (value) {
        'electricity' => 'Electricity',
        'water' => 'Water',
        'internet' => 'Internet',
        _ => 'Other utility',
      };

  String _scopeTitle(String value) => switch (value) {
        'individual' => 'Individual tenant',
        'selected_rooms' => 'Selected rooms',
        _ => 'All occupied rooms',
      };

  Future<void> _pickDate(String kind) async {
    final current = switch (kind) {
      'start' => _periodStart,
      'end' => _periodEnd,
      _ => _dueDate,
    };
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 730)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (kind == 'start') {
        _periodStart = picked;
        if (_periodEnd.isBefore(picked)) _periodEnd = picked;
      } else if (kind == 'end') {
        _periodEnd = picked;
      } else {
        _dueDate = picked;
      }
    });
  }

  void _addToCart() {
    if (!_formKey.currentState!.validate()) return;
    if (_scope == 'selected_rooms' && _rooms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one room.')),
      );
      return;
    }
    final tenants = OwnerController.instance.tenants;
    final matchingTenants =
        tenants.where((item) => item.id == _tenantId).toList();
    final tenant = _scope == 'individual' && matchingTenants.isNotEmpty
        ? matchingTenants.first
        : null;
    setState(() {
      _cart.add(_UtilityCartLine(
        scope: _scope,
        category: _category,
        allocation: _scope == 'individual' ? 'equal_per_tenant' : _allocation,
        tenantId: tenant?.id,
        targetLabel: tenant?.name ??
            (_scope == 'selected_rooms'
                ? (_rooms.toList()..sort()).join(', ')
                : 'All occupied rooms'),
        roomNumbers: (_rooms.toList()..sort()),
        total: double.parse(_amount.text.trim()),
        periodStart: _periodStart,
        periodEnd: _periodEnd,
        dueDate: _dueDate,
        notes: _notes.text.trim(),
      ));
      _amount.clear();
      _notes.clear();
    });
  }

  Future<void> _issueCart() async {
    if (_cart.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final count = await OwnerController.instance.createUtilityChargeCart(
        _cart
            .map((line) => {
                  'scope': line.scope,
                  'category': line.category,
                  'allocation_method': line.allocation,
                  'tenant_id': line.tenantId,
                  'room_numbers': line.roomNumbers,
                  'title':
                      '${_categoryTitle(line.category)} — ${_date(line.periodStart)}',
                  'total_amount': line.total,
                  'period_start': _date(line.periodStart),
                  'period_end': _date(line.periodEnd),
                  'due_date': _date(line.dueDate),
                  'notes': line.notes,
                })
            .toList(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(content: Text('Issued $count tenant utility charges.')),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to issue utility cart: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenants = OwnerController.instance.tenants;
    final roomNumbers = tenants
        .map((tenant) => tenant.room)
        .where((room) => room.isNotEmpty && room != 'Unassigned')
        .toSet()
        .toList()
      ..sort();
    final cartTotal = _cart.fold<double>(0, (sum, item) => sum + item.total);

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      title: const Text('Utility Charge Cart'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _scope,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(labelText: 'Charging scope'),
                  items: const [
                    DropdownMenuItem(
                        value: 'individual', child: Text('Individual tenant')),
                    DropdownMenuItem(
                        value: 'selected_rooms', child: Text('Selected rooms')),
                    DropdownMenuItem(
                        value: 'all_rooms', child: Text('All occupied rooms')),
                  ],
                  onChanged: (value) => setState(() => _scope = value!),
                ),
                const SizedBox(height: 12),
                if (_scope == 'individual')
                  DropdownButtonFormField<String>(
                    initialValue: _tenantId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Tenant'),
                    items: tenants
                        .map((tenant) => DropdownMenuItem(
                              value: tenant.id,
                              child: Text('${tenant.name} (${tenant.room})',
                                  overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    validator: (value) =>
                        value == null ? 'Select a tenant' : null,
                    onChanged: (value) => setState(() => _tenantId = value),
                  ),
                if (_scope == 'selected_rooms') ...[
                  const Text('Rooms',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: roomNumbers
                        .map((room) => FilterChip(
                              label: Text('Room $room'),
                              selected: _rooms.contains(room),
                              onSelected: (selected) => setState(() => selected
                                  ? _rooms.add(room)
                                  : _rooms.remove(room)),
                            ))
                        .toList(),
                  ),
                ],
                if (_scope != 'individual') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _allocation,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(labelText: 'Allocation method'),
                    items: const [
                      DropdownMenuItem(
                          value: 'equal_per_tenant',
                          child: Text('Equal per active tenant')),
                      DropdownMenuItem(
                          value: 'equal_per_room',
                          child: Text('Equal per occupied room')),
                    ],
                    onChanged: (value) => setState(() => _allocation = value!),
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Utility type'),
                  items: const [
                    DropdownMenuItem(
                        value: 'electricity', child: Text('Electricity')),
                    DropdownMenuItem(value: 'water', child: Text('Water')),
                    DropdownMenuItem(
                        value: 'internet', child: Text('Internet')),
                    DropdownMenuItem(
                        value: 'utility', child: Text('Other utility')),
                  ],
                  onChanged: (value) => setState(() => _category = value!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Source bill total', prefixText: '₱ '),
                  validator: (value) {
                    final parsed = double.tryParse(value?.trim() ?? '');
                    return parsed == null || parsed <= 0
                        ? 'Enter a valid total'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _DateButton(
                        label: 'Period start',
                        value: _date(_periodStart),
                        onTap: () => _pickDate('start')),
                    _DateButton(
                        label: 'Period end',
                        value: _date(_periodEnd),
                        onTap: () => _pickDate('end')),
                    _DateButton(
                        label: 'Due date',
                        value: _date(_dueDate),
                        onTap: () => _pickDate('due')),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notes,
                  maxLines: 2,
                  decoration:
                      const InputDecoration(labelText: 'Notes (optional)'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _addToCart,
                  icon: const Icon(Icons.add_shopping_cart_outlined),
                  label: const Text('Add to cart'),
                ),
                if (_cart.isNotEmpty) ...[
                  const Divider(height: 28),
                  ..._cart.indexed.map((entry) {
                    final index = entry.$1;
                    final item = entry.$2;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                          '${_categoryTitle(item.category)} • ${_scopeTitle(item.scope)}'),
                      subtitle: Text(
                          '${item.targetLabel}\nDue ${_date(item.dueDate)}'),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('₱${item.total.toStringAsFixed(2)}'),
                          IconButton(
                            tooltip: 'Remove from cart',
                            onPressed: _saving
                                ? null
                                : () => setState(() => _cart.removeAt(index)),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    );
                  }),
                  Text('Cart total: ₱${cartTotal.toStringAsFixed(2)}',
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton.icon(
          onPressed: _saving || _cart.isEmpty ? null : _issueCart,
          icon: const Icon(Icons.shopping_cart_checkout),
          label: Text(_saving ? 'Issuing…' : 'Issue cart'),
        ),
      ],
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton(
      {required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.event_outlined, size: 18),
        label: Text('$label: $value'),
      );
}

class _UtilityCartLine {
  const _UtilityCartLine({
    required this.scope,
    required this.category,
    required this.allocation,
    required this.targetLabel,
    required this.roomNumbers,
    required this.total,
    required this.periodStart,
    required this.periodEnd,
    required this.dueDate,
    required this.notes,
    this.tenantId,
  });
  final String scope, category, allocation, targetLabel, notes;
  final String? tenantId;
  final List<String> roomNumbers;
  final double total;
  final DateTime periodStart, periodEnd, dueDate;
}
