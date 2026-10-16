import 'package:flutter/material.dart';
import '../../core/utils/contract_occupancy_policy.dart';
import '../../core/widgets/common_widgets.dart';
import '../../models/models.dart';
import '../../services/room_service.dart';
import '../../services/table_refresh_subscription.dart';

class ContractOccupancySelection {
  const ContractOccupancySelection(
      this.roomId, this.mode, this.beds, this.deposits,
      [this.rents = const {}]);
  final String roomId, mode;
  final Map<String, String> beds;
  final Map<String, int> deposits;
  final Map<String, int> rents;
}

/// Preparation uses registered rooms, individual tenants and existing bed IDs.
class ContractOccupancyFields extends StatefulWidget {
  const ContractOccupancyFields(
      {required this.tenantId,
      required this.tenants,
      required this.rent,
      required this.onChanged,
      this.roomService = const RoomService(),
      super.key});
  final RoomService roomService;
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
  final rents = <String, int>{};
  late final TableRefreshSubscription _roomSubscription;
  int _request = 0;
  RoomRecord? get room => rooms.where((r) => r.id == roomId).firstOrNull;
  int get _standardCapacity =>
      room?.beds
          .where((b) =>
              b.tenantId == widget.tenantId ||
              (!b.occupied && b.status == 'available'))
          .length ??
      0;
  List<String> get ids => [
        if (widget.tenantId != null) widget.tenantId!,
        ...selected.where((id) => id != widget.tenantId)
      ];
  @override
  void initState() {
    super.initState();
    _roomSubscription = TableRefreshSubscription(
        'contract-preparation-${identityHashCode(this)}',
        const ['rooms', 'bed_spaces', 'tenant_assignments'],
        _load);
    _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    try {
      final values = await widget.roomService.listRooms(forceRefresh: true);
      if (!mounted || request != _request) return;
      final refreshed = values.where((r) => r.id == roomId).firstOrNull;
      final invalidated = roomId != null &&
          (refreshed == null ||
              !refreshed.isActive ||
              (mode != 'solo' && count > refreshed.capacity) ||
              (mode == 'standard_shared' &&
                  count >
                      refreshed.beds
                          .where((b) =>
                              b.tenantId == widget.tenantId ||
                              (!b.occupied && b.status == 'available'))
                          .length) ||
              ids.any((id) => !refreshed.beds.any((bed) =>
                  bed.id == beds[id] &&
                  (bed.tenantId == id ||
                      (!bed.occupied && bed.status == 'available')))));
      setState(() {
        rooms = values;
        loading = false;
        error = null;
        if (invalidated) {
          roomId = null;
          selected.clear();
          beds.clear();
          deposits.clear();
          rents.clear();
          mode = 'solo';
        }
      });
      if (invalidated) _publish();
    } catch (e) {
      if (mounted && request == _request)
        setState(() {
          loading = false;
          error = 'Could not load registered rooms. Please retry.';
        });
    }
  }

  @override
  void dispose() {
    _roomSubscription.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ContractOccupancyFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tenantId != widget.tenantId) {
      selected.clear();
      beds.clear();
      deposits.clear();
      rents.clear();
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
            Map.of(deposits),
            Map.of(rents)));
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
        if (error == null)
          TextButton(onPressed: _load, child: const Text('Refresh rooms')),
        DropdownButtonFormField<String>(
          key: ValueKey('contract-room-$roomId'),
          initialValue: roomId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Registered room'),
          items: rooms
              .where((r) => r.isActive)
              .map((r) => DropdownMenuItem(
                  value: r.id,
                  enabled: r.beds.any((b) =>
                      b.tenantId == widget.tenantId ||
                      (!b.occupied && b.status == 'available')),
                  child: Text('Room ${r.number}')))
              .toList(),
          onChanged: (id) => _change(() {
            roomId = id;
            selected.clear();
            deposits.clear();
            beds.clear();
            rents.clear();
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
            isExpanded: true,
            initialValue: mode,
            key: ValueKey('occupancy-mode-$mode'),
            decoration:
                const InputDecoration(labelText: 'Occupancy arrangement'),
            items: [
              const DropdownMenuItem(
                  value: 'solo', child: Text('Solo Occupancy')),
              if (room!.capacity >= 2)
                const DropdownMenuItem(
                    value: 'shared', child: Text('Exclusive Shared')),
              const DropdownMenuItem(
                  value: 'standard_shared', child: Text('Standard Shared')),
            ],
            onChanged: (value) => _change(() {
              mode = value!;
              selected.clear();
              deposits.clear();
              rents.clear();
              count = mode == 'standard_shared' ? 1 : 2;
              beds.removeWhere((id, _) => id != widget.tenantId);
            }),
          ),
          if (mode != 'solo') ...[
            if (mode == 'standard_shared')
              const Text(
                  'To stay with existing roommates, choose their room. Their contracts remain unchanged; the selected new occupants below receive their own contracts.'),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: ValueKey('occupancy-count-$mode-$count'),
              initialValue: count,
              decoration:
                  const InputDecoration(labelText: 'Contracted occupants'),
              items: [
                for (var n = mode == 'standard_shared' ? 1 : 2;
                    n <=
                        (mode == 'standard_shared'
                            ? _standardCapacity
                            : room!.capacity);
                    n++)
                  DropdownMenuItem(value: n, child: Text('$n tenants'))
              ],
              onChanged: (value) => _change(() {
                count = value!;
                selected.clear();
                deposits.clear();
                rents.clear();
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
                                            deposits.remove(tenant.id);
                                            rents.remove(tenant.id);
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
            if (mode == 'standard_shared' && id != widget.tenantId)
              TextFormField(
                key: ValueKey('occupancy-rent-$id'),
                decoration: InputDecoration(
                    labelText: 'Agreed monthly rent for ${_name(id)}'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  try {
                    parseRentCents(value ?? '');
                    return null;
                  } catch (_) {
                    return 'Enter the approved individual rent';
                  }
                },
                onChanged: (value) => _change(() {
                  rents.remove(id);
                  try {
                    rents[id] = parseRentCents(value);
                  } catch (_) {}
                }),
              ),
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
                initialValue: rentCentsText(deposits[id] ?? 0),
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
                if (mode != 'solo' && ids.length != count) {
                  if (mode == 'standard_shared')
                    return Text(
                        'Select exactly $count new occupants and enter each agreed individual rent.');
                  return Text(
                      'PHP ${widget.rent.text} / $count contracted occupants. Select all roommates to preview exact individual shares.');
                }
                Map<String, int> shares;
                try {
                  shares = occupancyRentalShares(
                      mode, parseRentCents(widget.rent.text), ids, {
                    ...rents,
                    if (widget.tenantId != null)
                      widget.tenantId!: parseRentCents(widget.rent.text)
                  });
                } catch (_) {
                  return Text(mode == 'standard_shared'
                      ? 'Enter each tenant’s agreed individual monthly rent.'
                      : 'Enter room rent to preview individual shares.');
                }
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(mode == 'standard_shared'
                          ? 'Fixed individual rental obligations'
                          : 'PHP ${widget.rent.text} / ${ids.length} contracted occupants'),
                      for (final id in ids)
                        Text(
                            '${_name(id)}: PHP ${rentCentsText(shares[id]!)} / month'),
                      Text(mode == 'standard_shared'
                          ? 'Joining occupants do not change existing contractual rents. Available beds may receive their own approved contracts.'
                          : 'Any remaining centavos go in tenant ID order. Utilities and other charges are unchanged.'),
                    ]);
              }),
          const SizedBox(height: 8),
          Text(mode == 'standard_shared'
              ? 'Saving reserves only the selected beds and creates individual fixed-rate Draft contracts. Existing signed agreements remain unchanged.'
              : 'Saving reserves this room for the selected group and creates one Draft contract per tenant. Each contract must complete the existing signing and activation requirements.'),
        ],
      ]);
}
