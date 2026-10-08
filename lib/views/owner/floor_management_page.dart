import 'package:flutter/material.dart';

import '../../core/utils/natural_sort.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/numbered_pagination.dart';
import '../../core/widgets/role_guard.dart';
import '../../core/widgets/searchable_dropdown.dart';
import '../../models/models.dart';
import '../../services/room_service.dart';
import '../../services/table_refresh_subscription.dart';

class FloorNameField extends StatelessWidget {
  const FloorNameField({
    super.key,
    required this.controller,
    required this.floors,
    this.enabled = true,
    this.onChanged,
  });

  final TextEditingController controller;
  final Iterable<String> floors;
  final bool enabled;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final options = floors.toSet().toList()..sort(compareFloorLabels);
    return DropdownButtonFormField<String>(
      initialValue: options.contains(controller.text) ? controller.text : null,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Floor',
        helperText:
            'Choose an existing floor. Add new floors in Manage floors.',
      ),
      items: [
        for (final floor in options)
          DropdownMenuItem(
              value: floor,
              child: Text(floor, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: !enabled
          ? null
          : (value) {
              controller.text = value ?? '';
              onChanged?.call();
            },
      validator: (value) => value == null ? 'Choose a floor' : null,
    );
  }
}

class FloorManagementPage extends StatefulWidget {
  const FloorManagementPage({super.key});

  @override
  State<FloorManagementPage> createState() => _FloorManagementPageState();
}

class _FloorManagementPageState extends State<FloorManagementPage> {
  static const _pageSize = 6;

  final _service = const RoomService();
  List<String> _floors = [];
  late final TableRefreshSubscription _subscription;
  int _loadVersion = 0;
  List<RoomRecord> _rooms = [];
  String _query = '';
  int _page = 1;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _subscription = TableRefreshSubscription(
        'floor-management', const ['rooms', 'room_floors'], _load);
  }

  @override
  void dispose() {
    _subscription.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final version = ++_loadVersion;
    try {
      final results = await Future.wait<Object>([
        _service.listRooms(forceRefresh: true),
        _service.listFloors(),
      ]);
      if (mounted && version == _loadVersion) {
        setState(() {
          _rooms = results[0] as List<RoomRecord>;
          _floors = results[1] as List<String>;
          _loading = false;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted && version == _loadVersion) {
        setState(() {
          _loading = false;
          _error = roomServiceError(error);
        });
      }
    }
  }

  Future<void> _rename(String floor, {bool merge = false}) async {
    final affected = _rooms.where((room) => room.floor == floor).toList();
    final controller = TextEditingController(text: floor);
    var saving = false;
    String? error;

    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, update) {
          final target = controller.text.trim();
          return AlertDialog(
            title: Text(merge ? 'Merge floor' : 'Rename floor'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (merge)
                      FloorNameField(
                          controller: controller,
                          floors: _floors.where((item) => item != floor),
                          enabled: !saving,
                          onChanged: () => update(() {}))
                    else
                      TextField(
                        controller: controller,
                        maxLength: 60,
                        enabled: !saving,
                        decoration: const InputDecoration(
                          labelText: 'New floor name',
                        ),
                        onChanged: (_) => update(() {}),
                      ),
                    Text(
                      '${affected.length} rooms will move from "$floor" to "$target", including archived rooms.',
                    ),
                    const SizedBox(height: 8),
                    Text(affected.map((room) => room.number).join(', ')),
                    if (merge)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'This combines both floors in the room directory. Residents and bed assignments stay linked.',
                        ),
                      ),
                    if (error != null)
                      Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        final target = controller.text.trim();
                        if (target.isEmpty || target == floor) {
                          update(
                              () => error = 'Choose a different floor name.');
                          return;
                        }
                        if (!merge &&
                            _floors.any((item) =>
                                item.toLowerCase() == target.toLowerCase() &&
                                item != floor)) {
                          update(() => error =
                              'That floor name already exists. Use Merge floor instead.');
                          return;
                        }
                        update(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          await _service.manageFloor(
                            floor,
                            target,
                            affected.length,
                            merge: merge,
                          );
                          if (context.mounted) Navigator.pop(context, true);
                        } catch (e) {
                          if (context.mounted) {
                            update(() {
                              saving = false;
                              error = roomServiceError(e);
                            });
                          }
                        }
                      },
                child: Text(
                  saving
                      ? 'Saving...'
                      : merge
                          ? 'Confirm merge'
                          : 'Confirm rename',
                ),
              ),
            ],
          );
        },
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 200));
    controller.dispose();
    if (changed == true && mounted) {
      setState(() => _page = 1);
      await _load();
    }
  }

  Future<void> _addFloor() async {
    final name = TextEditingController();
    var saving = false;
    String? error;
    final changed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, update) => AlertDialog(
                    title: const Text('Add floor'),
                    scrollable: true,
                    content: SizedBox(
                        width: 440,
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          TextField(
                              controller: name,
                              enabled: !saving,
                              maxLength: 60,
                              decoration: const InputDecoration(
                                  labelText: 'Floor name')),
                          if (error != null) Text(error!),
                        ])),
                    actions: [
                      TextButton(
                          onPressed:
                              saving ? null : () => Navigator.pop(ctx, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: saving
                              ? null
                              : () async {
                                  final value = name.text.trim();
                                  if (value.isEmpty ||
                                      _floors.any((floor) =>
                                          floor.toLowerCase() ==
                                          value.toLowerCase())) {
                                    update(() =>
                                        error = 'Enter a unique floor name.');
                                    return;
                                  }
                                  update(() {
                                    saving = true;
                                    error = null;
                                  });
                                  try {
                                    await _service.createFloor(value);
                                    if (ctx.mounted) Navigator.pop(ctx, true);
                                  } catch (e) {
                                    if (ctx.mounted)
                                      update(() {
                                        saving = false;
                                        error = roomServiceError(e);
                                      });
                                  }
                                },
                          child: Text(saving ? 'Saving…' : 'Add floor')),
                    ])));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    name.dispose();
    if (changed == true && mounted) await _load();
  }

  Future<void> _deleteFloor(String floor) async {
    final count = _rooms.where((room) => room.floor == floor).length;
    if (count > 0) {
      showAppSnackBar(context,
          'Move or delete all $count rooms first, including archived rooms.');
      return;
    }
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: Text('Delete floor "$floor"?'),
                content: const Text(
                    'Only an empty floor can be deleted. No rooms or historical records will be removed.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete floor'))
                ]));
    if (confirmed != true) return;
    try {
      await _service.deleteFloor(floor);
      if (mounted) await _load();
    } catch (e) {
      if (mounted) showAppSnackBar(context, roomServiceError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final needle = _query.trim().toLowerCase();
    final floors = _floors
        .where(
            (floor) => needle.isEmpty || floor.toLowerCase().contains(needle))
        .toList()
      ..sort(compareFloorLabels);

    final pageCount =
        floors.isEmpty ? 1 : (floors.length + _pageSize - 1) ~/ _pageSize;
    final safePage = _page > pageCount ? pageCount : _page;
    final start = (safePage - 1) * _pageSize;
    final pagedFloors =
        floors.skip(start).take(_pageSize).toList(growable: false);

    return RoleGuard(
      allowedRoles: const {UserRole.owner},
      child: PageFrame(
        title: 'Floor management',
        subtitle: 'Manage floors without changing room or bed identities',
        onRefresh: _load,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                    onPressed: _loading || _error != null ? null : _addFloor,
                    icon: const Icon(Icons.add),
                    label: const Text('Add floor'))),
            const SizedBox(height: 12),
            ChoiceSearchField(
              hintText: 'Search floors',
              onChanged: (value) => setState(() {
                _query = value;
                _page = 1;
              }),
            ),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              ListTile(
                title: Text(_error!),
                trailing: TextButton(
                  onPressed: _load,
                  child: const Text('Retry'),
                ),
              ),
            if (!_loading && _error == null && floors.isEmpty)
              const EmptyState(
                icon: Icons.layers_outlined,
                title: 'No matching floors',
                message: 'Try another floor name or clear the search.',
              ),
            for (final floor in pagedFloors)
              ListTile(
                title: Text(floor),
                subtitle: Text(
                  '${_rooms.where((room) => room.floor == floor).length} rooms',
                ),
                trailing: PopupMenuButton<String>(
                  tooltip: 'Floor actions',
                  onSelected: (action) {
                    if (action == 'delete') {
                      _deleteFloor(floor);
                    } else {
                      _rename(floor, merge: action == 'merge');
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'rename', child: Text('Rename floor')),
                    PopupMenuItem(value: 'merge', child: Text('Merge floor')),
                    PopupMenuItem(
                        value: 'delete', child: Text('Delete empty floor')),
                  ],
                ),
              ),
            NumberedPaginationBar(
              currentPage: safePage,
              totalItems: floors.length,
              pageSize: _pageSize,
              itemLabel: 'floors',
              onPageChanged: (page) => setState(() => _page = page),
            ),
          ],
        ),
      ),
    );
  }
}
