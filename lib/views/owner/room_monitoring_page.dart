import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/common_widgets.dart';
import '../../services/room_service.dart';
import '../../services/table_refresh_subscription.dart';

class RoomMonitoringPage extends StatefulWidget {
  const RoomMonitoringPage({super.key});
  @override
  State<RoomMonitoringPage> createState() => _RoomMonitoringPageState();
}

class _RoomMonitoringPageState extends State<RoomMonitoringPage> {
  final service = const RoomService();
  List<RoomRecord>? rooms;
  bool loading = true;
  String? errorMessage;
  int _requestVersion = 0;
  Timer? _debounceTimer;
  late final TableRefreshSubscription subscription;

  @override
  void initState() {
    super.initState();
    _loadRooms(showSpinner: true);
    subscription = TableRefreshSubscription(
      'rooms',
      ['rooms', 'bed_spaces', 'tenant_assignments'],
      _onRealtimeChange,
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    subscription.dispose();
    super.dispose();
  }

  void _onRealtimeChange() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _loadRooms();
    });
  }

  Future<void> _loadRooms({bool showSpinner = false}) async {
    final version = ++_requestVersion;
    if (showSpinner && mounted) {
      setState(() => loading = true);
    }
    try {
      final latest = await service.listRooms();
      if (mounted && version == _requestVersion) {
        setState(() {
          rooms = latest;
          loading = false;
          errorMessage = null;
        });
      }
    } catch (error) {
      if (mounted && version == _requestVersion) {
        setState(() {
          loading = false;
          errorMessage = roomServiceError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentRooms = rooms;

    Widget body;
    if (loading && currentRooms == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (errorMessage != null && currentRooms == null) {
      body = EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Unable to load rooms',
        message: errorMessage!,
        action: FilledButton.icon(
          onPressed: () => _loadRooms(showSpinner: true),
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      );
    } else if (currentRooms == null || currentRooms.isEmpty) {
      body = EmptyState(
        icon: Icons.meeting_room_outlined,
        title: 'No rooms found',
        message: 'No dormitory rooms are available yet.',
        action: FilledButton.icon(
          onPressed: () => _loadRooms(showSpinner: true),
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
      );
    } else {
      final occupied =
          currentRooms.fold<int>(0, (sum, room) => sum + room.occupied);
      final bedCount =
          currentRooms.fold<int>(0, (sum, room) => sum + room.beds.length);
      final available = currentRooms.fold<int>(
          0, (sum, room) => sum + room.physicallyAvailable);
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdaptiveGrid(children: [
            MetricCard(
              label: 'Rooms',
              value: '${currentRooms.length}',
              detail: '$bedCount configured beds',
              icon: Icons.meeting_room_outlined,
            ),
            MetricCard(
              label: 'Occupied beds',
              value: '$occupied',
              detail: 'Active assignments',
              icon: Icons.bed_outlined,
            ),
            MetricCard(
              label: 'Available beds',
              value: '$available',
              detail: 'Ready for assignment',
              icon: Icons.event_available_outlined,
            ),
          ]),
          const SizedBox(height: 18),
          AdaptiveGrid(
            minTileWidth: 260,
            children: currentRooms.map(roomCard).toList(),
          ),
        ],
      );
    }

    return PageFrame(
      title: 'Room monitoring',
      subtitle: 'Live rooms, bed spaces, occupancy, and availability',
      actions: [
        IconButton(
          onPressed: () => _loadRooms(showSpinner: currentRooms == null),
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: body,
    );
  }

  Widget roomCard(RoomRecord room) {
    final percent = room.capacity > 0 ? (room.occupied / room.capacity) : 0.0;
    final isFull = room.occupied >= room.capacity && room.capacity > 0;
    final badgeColor = isFull ? AppColors.success : AppColors.info;

    return CarmelitaCard(
      padding: const EdgeInsets.all(12),
      onTap: () => _openRoomDetail(room),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Room ${room.number}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatFloor(room.floor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withValues(alpha: .5),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(badgeColor),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: .12),
              borderRadius: const BorderRadius.all(Radius.circular(999)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isFull ? Icons.lock_outline : Icons.bed_outlined,
                  size: 13,
                  color: badgeColor,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    _formatOccupancy(room),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: badgeColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openRoomDetail(RoomRecord room) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RoomDetailPage(
          initialRoom: room,
          service: service,
        ),
      ),
    );
    if (changed == true || mounted) {
      await _loadRooms();
    }
  }
}

class RoomDetailPage extends StatefulWidget {
  const RoomDetailPage({
    required this.initialRoom,
    required this.service,
    super.key,
  });

  final RoomRecord initialRoom;
  final RoomService service;

  @override
  State<RoomDetailPage> createState() => _RoomDetailPageState();
}

class _RoomDetailPageState extends State<RoomDetailPage> {
  late RoomRecord room;
  late final TableRefreshSubscription subscription;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    room = widget.initialRoom;
    subscription = TableRefreshSubscription(
      'room-${room.id}',
      ['rooms', 'bed_spaces', 'tenant_assignments'],
      _onRealtimeChange,
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    subscription.dispose();
    super.dispose();
  }

  void _onRealtimeChange() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _refreshRoom();
    });
  }

  Future<void> _refreshRoom() async {
    try {
      final latestRooms = await widget.service.listRooms();
      if (!mounted) return;
      final updated = latestRooms.cast<RoomRecord?>().firstWhere(
            (r) => r?.id == room.id,
            orElse: () => null,
          );
      if (updated == null) {
        if (mounted) Navigator.of(context).pop(true);
      } else {
        setState(() => room = updated);
      }
    } catch (_) {}
  }

  Future<void> editRoom() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => RoomEditor(service: widget.service, room: room),
    );
    if (changed == true && mounted) {
      await _refreshRoom();
    }
  }

  Future<void> editBed(BedRecord bed) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => BedEditor(service: widget.service, room: room, bed: bed),
    );
    if (changed == true && mounted) {
      await _refreshRoom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Room ${room.number}',
      subtitle: '${room.floor} • ${room.beds.length}/${room.capacity} bed spaces',
      useScriptTitle: false,
      actions: [
        IconButton(
          tooltip: 'Edit notes',
          onPressed: editRoom,
          icon: const Icon(Icons.edit_note_outlined),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdaptiveGrid(
            children: [
              MetricCard(
                label: 'Capacity',
                value: '${room.capacity}',
                detail: '${room.beds.length} configured beds',
                icon: Icons.meeting_room_outlined,
              ),
              MetricCard(
                label: 'Occupied',
                value: '${room.occupied}',
                detail: 'Active assignments',
                icon: Icons.bed_outlined,
              ),
              MetricCard(
                label: 'Available',
                value: '${room.physicallyAvailable}',
                detail: 'Ready for tenant',
                icon: Icons.event_available_outlined,
              ),
            ],
          ),
          if (room.description.isNotEmpty) ...[
            const SizedBox(height: 14),
            CarmelitaCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      room.description,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),
          const SectionTitle(
            'Bed spaces',
            subtitle: 'Manage availability, labels, and maintenance for each bed',
          ),
          const SizedBox(height: 12),
          if (room.beds.isEmpty)
            const EmptyState(
              icon: Icons.bed_outlined,
              title: 'No beds found',
              message: 'This room does not have any bed spaces configured.',
            )
          else
            ...room.beds.map((bed) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: CarmelitaCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: bed.occupied
                              ? const Color(0xFF56886B).withValues(alpha: .15)
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                          foregroundColor: bed.occupied
                              ? const Color(0xFF56886B)
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                          child: Icon(
                            bed.occupied
                                ? Icons.person
                                : Icons.bed_outlined,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                bed.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                bed.occupied
                                    ? 'Occupied by active assignment'
                                    : 'Status: ${bedStatusLabel(bed.status)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: bed.occupied
                                      ? const Color(0xFF56886B)
                                      : Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        StatusPill(
                          bed.occupied ? 'Occupied' : bedStatusLabel(bed.status),
                          icon: bed.occupied
                              ? Icons.lock_outline
                              : Icons.check_circle_outline,
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: bed.occupied
                              ? 'Occupied beds cannot be edited'
                              : 'Edit bed',
                          onPressed:
                              bed.occupied ? null : () => editBed(bed),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }
}

class RoomEditor extends StatefulWidget {
  const RoomEditor({required this.service, required this.room, super.key});
  final RoomService service;
  final RoomRecord room;
  @override
  State<RoomEditor> createState() => _RoomEditorState();
}

class _RoomEditorState extends State<RoomEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController description;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    description = TextEditingController(text: widget.room.description);
  }

  @override
  void dispose() {
    description.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      final r = widget.room;
      await widget.service.updateRoom(
        id: r.id,
        number: r.number,
        floor: r.floor,
        description: description.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showAppSnackBar(context, roomServiceError(e));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Edit Room ${widget.room.number} notes'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.room.floor} • 4 bed spaces',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: description,
                maxLength: 300,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Room notes / description',
                  hintText: 'e.g. Quiet room, near hallway window',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: saving ? null : save,
            child: Text(saving ? 'Saving…' : 'Save'),
          ),
        ],
      );
}

class BedEditor extends StatefulWidget {
  const BedEditor(
      {required this.service, required this.room, this.bed, super.key});
  final RoomService service;
  final RoomRecord room;
  final BedRecord? bed;
  @override
  State<BedEditor> createState() => _BedEditorState();
}

class _BedEditorState extends State<BedEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController label;
  late String status;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    label = TextEditingController(text: widget.bed?.label);
    status = widget.bed?.status ?? 'available';
  }

  @override
  void dispose() {
    label.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      final b = widget.bed!;
      await widget.service
          .updateBed(id: b.id, label: label.text, status: status);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showAppSnackBar(context, roomServiceError(e));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('Edit bed space'),
          content: Form(
              key: form,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                    controller: label,
                    maxLength: 40,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                    decoration: const InputDecoration(labelText: 'Bed label')),
                DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(
                          value: 'available', child: Text('Available')),
                      DropdownMenuItem(
                          value: 'reserved', child: Text('Reserved')),
                      DropdownMenuItem(
                          value: 'maintenance', child: Text('Maintenance')),
                      DropdownMenuItem(
                          value: 'unavailable', child: Text('Unavailable'))
                    ],
                    onChanged: (v) => setState(() => status = v!)),
              ])),
          actions: [
            TextButton(
                onPressed: saving ? null : () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: saving ? null : save,
                child: Text(saving ? 'Saving…' : 'Save'))
          ]);
}

String bedStatusLabel(String status) => switch (status) {
      'reserved' => 'Reserved',
      'maintenance' => 'Maintenance',
      'unavailable' => 'Unavailable',
      _ => 'Available'
    };

String _formatFloor(String floor) {
  final clean = floor.trim();
  if (clean.isEmpty) return 'Floor -';
  final lower = clean.toLowerCase();
  if (lower.startsWith('floor') ||
      lower.startsWith('flr') ||
      lower.endsWith('floor')) {
    return clean;
  }
  return 'Flr $clean';
}

String _formatOccupancy(RoomRecord room) {
  if (room.occupied >= room.capacity && room.capacity > 0) {
    return '${room.occupied}/${room.capacity} • Full';
  }
  return '${room.occupied}/${room.capacity} • ${room.physicallyAvailable} open';
}

