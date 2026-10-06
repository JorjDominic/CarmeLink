import 'package:flutter/material.dart';

import '../../core/utils/natural_sort.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/numbered_pagination.dart';
import '../../core/widgets/role_guard.dart';
import '../../core/widgets/searchable_dropdown.dart';
import '../../models/models.dart';
import '../../services/room_service.dart';

class FloorNameField extends StatefulWidget {
  const FloorNameField({
    super.key,
    required this.controller,
    required this.floors,
  });

  final TextEditingController controller;
  final Iterable<String> floors;

  @override
  State<FloorNameField> createState() => _FloorNameFieldState();
}

class _FloorNameFieldState extends State<FloorNameField> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RawAutocomplete<String>(
        textEditingController: widget.controller,
        focusNode: _focus,
        optionsBuilder: (text) {
          final needle = text.text.trim().toLowerCase();
          final options = widget.floors
              .toSet()
              .where((floor) => floor.toLowerCase().contains(needle))
              .toList()
            ..sort(compareFloorLabels);
          return options;
        },
        fieldViewBuilder: (context, controller, focus, submit) => TextFormField(
          controller: controller,
          focusNode: focus,
          maxLength: 60,
          decoration: const InputDecoration(
            labelText: 'Floor',
            helperText: 'Choose an existing floor or enter a new name.',
          ),
          validator: (value) =>
              value == null || value.trim().isEmpty ? 'Enter a floor' : null,
          onFieldSubmitted: (_) => submit(),
        ),
        optionsViewBuilder: (context, select, options) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth:
                    MediaQuery.sizeOf(context).width.clamp(0, 320).toDouble() -
                        48,
                maxHeight: 180,
              ),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: options
                    .map(
                      (floor) => ListTile(
                        title: Text(floor),
                        onTap: () => select(floor),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
      );
}

class FloorManagementPage extends StatefulWidget {
  const FloorManagementPage({super.key});

  @override
  State<FloorManagementPage> createState() => _FloorManagementPageState();
}

class _FloorManagementPageState extends State<FloorManagementPage> {
  static const _pageSize = 6;

  final _service = const RoomService();
  List<RoomRecord> _rooms = [];
  String _query = '';
  int _page = 1;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rooms = await _service.listRooms(forceRefresh: true);
      if (mounted) {
        setState(() {
          _rooms = rooms;
          _loading = false;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load floors. Retry.';
        });
      }
    }
  }

  Future<void> _rename(String floor) async {
    final affected = _rooms.where((room) => room.floor == floor).toList();
    final controller = TextEditingController(text: floor);
    var saving = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) {
          final target = controller.text.trim();
          final merge =
              target != floor && _rooms.any((room) => room.floor == target);
          return AlertDialog(
            title: Text(merge ? 'Merge floor' : 'Rename floor'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: controller,
                      maxLength: 60,
                      enabled: !saving,
                      decoration: const InputDecoration(
                        labelText: 'New or existing floor name',
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
                onPressed: saving || target.isEmpty || target == floor
                    ? null
                    : () async {
                        update(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          await _service.renameFloor(
                            floor,
                            target,
                            affected.length,
                          );
                          if (context.mounted) Navigator.pop(context);
                        } catch (_) {
                          if (context.mounted) {
                            update(() {
                              saving = false;
                              error =
                                  'Could not update this floor. Refresh if the room list changed.';
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
    if (mounted) {
      setState(() => _page = 1);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final needle = _query.trim().toLowerCase();
    final floors = _rooms
        .map((room) => room.floor)
        .toSet()
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
        subtitle: 'Rename a floor or merge its rooms into another floor',
        onRefresh: _load,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                trailing: IconButton(
                  tooltip: 'Rename or merge floor',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _rename(floor),
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
