import 'package:flutter/material.dart';

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
  late Future<List<RoomRecord>> future;
  late final TableRefreshSubscription subscription;

  @override
  void initState() {
    super.initState();
    future = service.listRooms();
    subscription = TableRefreshSubscription(
        'rooms', ['rooms', 'bed_spaces', 'tenant_assignments'], refresh);
  }

  @override
  void dispose() {
    subscription.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    try {
      final latest = await service.listRooms();
      if (mounted) setState(() => future = Future.value(latest));
    } catch (error, stackTrace) {
      if (mounted) {
        setState(() => future = Future.error(error, stackTrace));
      }
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
        title: 'Room monitoring',
        subtitle: 'Live rooms, bed spaces, occupancy, and availability',
        actions: [
          IconButton(
              onPressed: refresh,
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh))
        ],
        floatingActionButton: FloatingActionButton.extended(
            onPressed: () => editRoom(),
            icon: const Icon(Icons.add),
            label: const Text('Room')),
        child: FutureBuilder<List<RoomRecord>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done)
                return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError)
                return EmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: 'Unable to load rooms',
                    message: roomServiceError(snapshot.error!),
                    action: FilledButton.icon(
                        onPressed: refresh,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry')));
              final rooms = snapshot.data ?? const <RoomRecord>[];
              if (rooms.isEmpty)
                return EmptyState(
                    icon: Icons.meeting_room_outlined,
                    title: 'No rooms yet',
                    message: 'Create the first room, then add its bed spaces.',
                    action: FilledButton.icon(
                        onPressed: editRoom,
                        icon: const Icon(Icons.add),
                        label: const Text('Create room')));
              final occupied =
                  rooms.fold<int>(0, (sum, room) => sum + room.occupied);
              final bedCount =
                  rooms.fold<int>(0, (sum, room) => sum + room.beds.length);
              final available = rooms.fold<int>(
                  0, (sum, room) => sum + room.physicallyAvailable);
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AdaptiveGrid(children: [
                      MetricCard(
                          label: 'Rooms',
                          value: '${rooms.length}',
                          detail: '$bedCount configured beds',
                          icon: Icons.meeting_room_outlined),
                      MetricCard(
                          label: 'Occupied beds',
                          value: '$occupied',
                          detail: 'Active assignments',
                          icon: Icons.bed_outlined),
                      MetricCard(
                          label: 'Available beds',
                          value: '$available',
                          detail: 'Ready for assignment',
                          icon: Icons.event_available_outlined),
                    ]),
                    const SizedBox(height: 18),
                    AdaptiveGrid(
                        minTileWidth: 290,
                        children: rooms.map(roomCard).toList()),
                  ]);
            }),
      );

  Widget roomCard(RoomRecord room) => CarmelitaCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text('Room ${room.number}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 17))),
          PopupMenuButton<String>(
              onSelected: (v) =>
                  v == 'edit' ? editRoom(room) : deleteRoom(room),
              itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit room')),
                    PopupMenuItem(value: 'delete', child: Text('Delete room'))
                  ])
        ]),
        Text('${room.floor} • ${room.beds.length}/${room.capacity} bed spaces'),
        if (room.description.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(room.description)),
        const Divider(),
        if (room.beds.isEmpty) const Text('No bed spaces configured.'),
        ...room.beds.map((bed) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(bed.occupied ? Icons.person : Icons.bed_outlined),
            title: Text(bed.label),
            subtitle:
                Text(bed.occupied ? 'Occupied' : bedStatusLabel(bed.status)),
            trailing: IconButton(
                tooltip: bed.occupied
                    ? 'Occupied beds cannot be edited'
                    : 'Edit bed',
                onPressed: bed.occupied ? null : () => editBed(room, bed),
                icon: const Icon(Icons.edit_outlined)))),
      ]));

  Future<void> editRoom([RoomRecord? room]) async {
    final changed = await showDialog<bool>(
        context: context,
        builder: (_) => RoomEditor(service: service, room: room));
    if (changed == true && mounted) await refresh();
  }

  Future<void> editBed(RoomRecord room, BedRecord bed) async {
    final changed = await showDialog<bool>(
        context: context,
        builder: (_) => BedEditor(service: service, room: room, bed: bed));
    if (changed == true && mounted) await refresh();
  }

  Future<bool> confirm(String title, String message) async =>
      await showDialog<bool>(
          context: context,
          builder: (c) =>
              AlertDialog(title: Text(title), content: Text(message), actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('Delete'))
              ])) ??
      false;
  Future<void> deleteRoom(RoomRecord room) async {
    if (await confirm('Delete Room ${room.number}?',
        'Only rooms without assignment history can be deleted.'))
      mutate(() => service.deleteRoom(room.id));
  }

  Future<void> mutate(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) await refresh();
    } catch (e) {
      if (mounted) showAppSnackBar(context, roomServiceError(e));
    }
  }
}

class RoomEditor extends StatefulWidget {
  const RoomEditor({required this.service, this.room, super.key});
  final RoomService service;
  final RoomRecord? room;
  @override
  State<RoomEditor> createState() => _RoomEditorState();
}

class _RoomEditorState extends State<RoomEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController number, floor, description;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    final r = widget.room;
    number = TextEditingController(text: r?.number);
    floor = TextEditingController(text: r?.floor);
    description = TextEditingController(text: r?.description);
  }

  @override
  void dispose() {
    number.dispose();
    floor.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      final r = widget.room;
      if (r == null) {
        await widget.service.createRoom(
            number: number.text,
            floor: floor.text,
            description: description.text);
      } else {
        await widget.service.updateRoom(
            id: r.id,
            number: number.text,
            floor: floor.text,
            description: description.text);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showAppSnackBar(context, roomServiceError(e));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String? requiredText(String? v) =>
      v == null || v.trim().isEmpty ? 'Required' : null;
  @override
  Widget build(BuildContext context) => AlertDialog(
          title: Text(widget.room == null ? 'Create room' : 'Edit room'),
          content: Form(
              key: form,
              child: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                    controller: number,
                    validator: requiredText,
                    maxLength: 30,
                    decoration:
                        const InputDecoration(labelText: 'Room number')),
                TextFormField(
                    controller: floor,
                    validator: requiredText,
                    maxLength: 60,
                    decoration: const InputDecoration(labelText: 'Floor')),
                const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.bed_outlined),
                    title: Text('4 bed spaces'),
                    subtitle: Text('Every room always has four beds.')),
                TextFormField(
                    controller: description,
                    maxLength: 300,
                    maxLines: 3,
                    decoration: const InputDecoration(
                        labelText: 'Description (optional)')),
              ]))),
          actions: [
            TextButton(
                onPressed: saving ? null : () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: saving ? null : save,
                child: Text(saving ? 'Saving…' : 'Save'))
          ]);
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
