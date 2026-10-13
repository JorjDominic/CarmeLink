import 'package:flutter/material.dart';
import '../../core/utils/contract_occupancy_policy.dart';
import '../../core/widgets/common_widgets.dart';
import '../../models/models.dart';
import '../../services/room_service.dart';

class ContractOccupancySelection {
  const ContractOccupancySelection(
      this.roomId, this.mode, this.beds, this.deposits);
  final String roomId, mode;
  final Map<String, String> beds;
  final Map<String, int> deposits;
}

/// Preparation uses registered rooms, individual tenants and existing bed IDs.
class ContractOccupancyFields extends StatefulWidget {
  const ContractOccupancyFields(
      {required this.tenantId,
      required this.tenants,
      required this.rent,
      required this.onChanged,
      super.key});
  final String? tenantId;
  final List<TenantDirectoryEntry> tenants;
  final TextEditingController rent;
  final ValueChanged<ContractOccupancySelection?> onChanged;
  @override
  State<ContractOccupancyFields> createState() =>
      _ContractOccupancyFieldsState();
}

class _ContractOccupancyFieldsState extends State<ContractOccupancyFields> {
  List<RoomRecord> rooms = RoomService.cachedRooms ?? [];
  bool loading = true;
  String? error, roomId;
  String mode = 'solo';
  int count = 2;
  final selected = <String>{};
  final beds = <String, String>{};
  final deposits = <String, int>{};
  RoomRecord? get room => rooms.where((r) => r.id == roomId).firstOrNull;
  List<String> get ids => [
        if (widget.tenantId != null) widget.tenantId!,
        ...selected.where((id) => id != widget.tenantId)
      ];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final values = await const RoomService().listRooms(forceRefresh: true);
      if (mounted)
        setState(() {
          rooms = values;
          loading = false;
          error = null;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          loading = false;
          error = 'Could not load registered rooms. Please retry.';
        });
    }
  }

  @override
  void didUpdateWidget(covariant ContractOccupancyFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tenantId != widget.tenantId) {
      selected.clear();
      beds.clear();
      deposits.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _publish();
      });
    }
  }

  List<BedRecord> _bedsFor(String id) =>
      room?.beds
          .where((b) =>
              b.tenantId == id || (!b.occupied && b.status == 'available'))
          .toList() ??
      [];
  void _publish() {
    for (final id in ids) {
      if (!beds.containsKey(id)) {
        final candidates =
            _bedsFor(id).where((b) => !beds.values.contains(b.id)).toList();
        final current = candidates.where((b) => b.tenantId == id).firstOrNull;
        if (candidates.isNotEmpty) beds[id] = (current ?? candidates.first).id;
      }
    }
    widget.onChanged(roomId == null
        ? null
        : ContractOccupancySelection(
            roomId!,
            mode,
            {
              for (final id in ids)
                if (beds[id] != null) id: beds[id]!
            },
            Map.of(deposits)));
  }

  void _change(VoidCallback action) {
    setState(action);
    _publish();
  }

  String _name(String id) =>
      widget.tenants.where((t) => t.id == id).firstOrNull?.name ??
      'Selected tenant';
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionTitle('Occupancy Arrangement'),
        const SizedBox(height: 8),
        if (loading) const LinearProgressIndicator(),
        if (error != null) ...[
          Text(error!),
          TextButton(onPressed: _load, child: const Text('Retry rooms'))
        ],
        DropdownButtonFormField<String>(
          key: ValueKey('contract-room-$roomId'),
          initialValue: roomId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Registered room'),
          items: rooms
              .where((r) => r.isActive)
              .map((r) => DropdownMenuItem(
                  value: r.id, child: Text('Room ${r.number}')))
              .toList(),
          onChanged: (id) => _change(() {
            roomId = id;
            selected.clear();
            beds.clear();
            count = room!.capacity.clamp(1, 2);
            mode = 'solo';
          }),
          validator: (id) => id == null ? 'Select a registered room' : null,
        ),
        if (room != null) ...[
          const SizedBox(height: 8),
          Text(
              'Capacity ${room!.capacity} | ${room!.occupied} occupants | ${room!.physicallyAvailable} available\nCurrent occupants: ${room!.beds.where((b) => b.occupied).map((b) => b.tenantName ?? 'Assigned tenant').join(', ')}'),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: mode,
            key: ValueKey('occupancy-mode-$mode'),
            decoration:
                const InputDecoration(labelText: 'Occupancy arrangement'),
            items: [
              const DropdownMenuItem(
                  value: 'solo', child: Text('Solo Occupancy')),
              if (room!.capacity >= 2)
                const DropdownMenuItem(
                    value: 'shared', child: Text('Shared Occupancy'))
            ],
            onChanged: (value) => _change(() {
              mode = value!;
              selected.clear();
              beds.removeWhere((id, _) => id != widget.tenantId);
            }),
          ),
          if (mode == 'shared') ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: count,
              decoration:
                  const InputDecoration(labelText: 'Contracted occupants'),
              items: [
                for (var n = 2; n <= room!.capacity && n <= 4; n++)
                  DropdownMenuItem(value: n, child: Text('$n tenants'))
              ],
              onChanged: (value) => _change(() {
                count = value!;
                selected.clear();
                beds.removeWhere((id, _) => id != widget.tenantId);
              }),
            ),
            FormField<int>(
                validator: (_) => ids.length != count
                    ? 'Select exactly $count occupants including the tenant'
                    : null,
                builder: (field) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final tenant in widget.tenants
                              .where((t) => t.id != widget.tenantId))
                            CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(tenant.name),
                                value: selected.contains(tenant.id),
                                onChanged: !selected.contains(tenant.id) &&
                                        ids.length >= count
                                    ? null
                                    : (value) => _change(() {
                                          if (value == true) {
                                            selected.add(tenant.id);
                                          } else {
                                            selected.remove(tenant.id);
                                            beds.remove(tenant.id);
                                          }
                                        })),
                          if (field.hasError)
                            Text(field.errorText!,
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.error)),
                        ])),
          ],
          for (final id in ids) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('occupancy-bed-$id-${beds[id]}'),
              initialValue: beds[id],
              isExpanded: true,
              decoration: InputDecoration(labelText: 'Bed for ${_name(id)}'),
              items: _bedsFor(id)
                  .map((b) =>
                      DropdownMenuItem(value: b.id, child: Text(b.label)))
                  .toList(),
              onChanged: (bed) => _change(() {
                beds[id] = bed!;
              }),
              validator: (value) => value == null
                  ? 'Select an available bed'
                  : beds.values.where((b) => b == value).length > 1
                      ? 'Each tenant needs a different bed'
                      : null,
            ),
            if (id != widget.tenantId) ...[
              const SizedBox(height: 8),
              TextFormField(
                key: ValueKey('occupancy-deposit-$id'),
                initialValue: '0.00',
                decoration: InputDecoration(
                    labelText: 'Security deposit for ${_name(id)}',
                    helperText: 'Individual amount; deposits are not split.'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  try {
                    parseRentCents(value ?? '');
                    return null;
                  } catch (_) {
                    return 'Enter a valid individual deposit';
                  }
                },
                onChanged: (value) {
                  try {
                    deposits[id] = parseRentCents(value);
                    _publish();
                  } catch (_) {}
                },
              ),
            ],
          ],
          const SizedBox(height: 12),
          ValueListenableBuilder<TextEditingValue>(
              valueListenable: widget.rent,
              builder: (context, _, child) {
                if (mode == 'shared' && ids.length != count) {
                  return Text(
                      'PHP ${widget.rent.text} / $count contracted occupants. Select all roommates to preview exact individual shares.');
                }
                Map<String, int> shares;
                try {
                  shares = allocateContractRent(
                      parseRentCents(widget.rent.text), ids);
                } catch (_) {
                  return const Text(
                      'Enter room rent to preview individual shares.');
                }
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'PHP ${widget.rent.text} / ${ids.length} contracted occupants'),
                      for (final id in ids)
                        Text(
                            '${_name(id)}: PHP ${rentCentsText(shares[id]!)} / month'),
                      const Text(
                          'Any remaining centavos go in tenant ID order. Utilities and other charges are unchanged.'),
                    ]);
              }),
          const SizedBox(height: 8),
          const Text(
              'Saving reserves this room for the selected group and creates one Draft contract per tenant. Each contract must complete the existing signing and activation requirements.'),
        ],
      ]);
}
