import 'package:flutter/material.dart';

import '../../core/widgets/common_widgets.dart';

class AdminFloorPlanPage extends StatefulWidget {
  const AdminFloorPlanPage({super.key});

  @override
  State<AdminFloorPlanPage> createState() => _AdminFloorPlanPageState();
}

class _AdminFloorPlanPageState extends State<AdminFloorPlanPage> {
  final TransformationController _transform = TransformationController();
  int _floor = 0;
  String? _selectedRoom;

  static const _floors = ['Ground floor', 'Second floor'];

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _zoom(double factor) {
    final scale = _transform.value.getMaxScaleOnAxis();
    final next = (scale * factor).clamp(.65, 3.5);
    _transform.value = Matrix4.diagonal3Values(next, next, 1);
  }

  void _reset() => _transform.value = Matrix4.identity();

  @override
  Widget build(BuildContext context) {
    final rooms = _floor == 0 ? _groundFloor : _secondFloor;
    final bedrooms = rooms.where((room) => !room.isAmenity);
    final occupied = bedrooms.fold<int>(0, (sum, room) => sum + room.occupied);
    final capacity = bedrooms.fold<int>(0, (sum, room) => sum + room.capacity);

    return PageFrame(
      title: 'Floor plan',
      subtitle: 'Interactive admin occupancy map',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SegmentedButton<int>(
                  segments: List.generate(
                    _floors.length,
                    (index) => ButtonSegment(
                      value: index,
                      label: Text(_floors[index]),
                      icon: const Icon(Icons.layers_outlined),
                    ),
                  ),
                  selected: {_floor},
                  onSelectionChanged: (value) {
                    setState(() {
                      _floor = value.first;
                      _selectedRoom = null;
                      _reset();
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SummaryChip(
                icon: Icons.bed_outlined,
                label: '$occupied / $capacity occupied',
              ),
              _SummaryChip(
                icon: Icons.event_available_outlined,
                label: '${capacity - occupied} beds available',
              ),
              const _LegendDot(label: 'Available', color: Color(0xFF56886B)),
              const _LegendDot(label: 'Full', color: Color(0xFFAA6870)),
            ],
          ),
          const SizedBox(height: 12),
          CarmelitaCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.touch_app_outlined, size: 18),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Tap a room for details • pinch or drag to explore',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Zoom out',
                        onPressed: () => _zoom(.8),
                        icon: const Icon(Icons.remove),
                      ),
                      IconButton(
                        tooltip: 'Reset view',
                        onPressed: _reset,
                        icon: const Icon(Icons.center_focus_strong_outlined),
                      ),
                      IconButton(
                        tooltip: 'Zoom in',
                        onPressed: () => _zoom(1.25),
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 440,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLowest,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(20),
                    ),
                  ),
                  child: InteractiveViewer(
                    transformationController: _transform,
                    minScale: .65,
                    maxScale: 3.5,
                    boundaryMargin: const EdgeInsets.all(90),
                    constrained: false,
                    child: _FloorCanvas(
                      rooms: rooms,
                      selectedRoom: _selectedRoom,
                      onRoomTap: (room) {
                        setState(() => _selectedRoom = room.number);
                        _showRoomDetails(room);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Sample layout for administrator preview. Room positions can later be connected to your property database.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  void _showRoomDetails(_PlanRoom room) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Room ${room.number}',
                        style: Theme.of(context).textTheme.headlineSmall),
                  ),
                  StatusPill(room.isAmenity
                      ? 'Shared space'
                      : room.isFull
                          ? 'Full'
                          : 'Available'),
                ],
              ),
              const SizedBox(height: 16),
              if (!room.isAmenity) ...[
                _DetailRow(Icons.bed_outlined,
                    '${room.occupied} of ${room.capacity} beds occupied'),
                _DetailRow(
                    Icons.person_outline,
                    room.occupied == 0
                        ? 'No assigned tenants'
                        : '${room.occupied} assigned tenant(s)'),
              ],
              _DetailRow(Icons.home_work_outlined, room.note),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.check),
                  label: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FloorCanvas extends StatelessWidget {
  const _FloorCanvas({
    required this.rooms,
    required this.selectedRoom,
    required this.onRoomTap,
  });

  final List<_PlanRoom> rooms;
  final String? selectedRoom;
  final ValueChanged<_PlanRoom> onRoomTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 780,
      height: 440,
      padding: const EdgeInsets.all(24),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border.all(color: scheme.onSurface, width: 4),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Positioned(
            left: 306,
            top: 4,
            width: 120,
            height: 384,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                border: Border.symmetric(
                  vertical: BorderSide(color: scheme.outline, width: 2),
                ),
              ),
              child: const RotatedBox(
                quarterTurns: 1,
                child: Text('MAIN CORRIDOR  →  EXIT',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, letterSpacing: 1)),
              ),
            ),
          ),
          ...rooms.map((room) => Positioned(
                left: room.x,
                top: room.y,
                width: room.width,
                height: room.height,
                child: _RoomTile(
                  room: room,
                  selected: selectedRoom == room.number,
                  onTap: () => onRoomTap(room),
                ),
              )),
          const Positioned(
              left: 330,
              top: 360,
              child: _MapMarker(Icons.exit_to_app, 'ENTRANCE')),
          const Positioned(
              left: 330,
              top: 12,
              child: _MapMarker(Icons.stairs_outlined, 'STAIRS')),
        ],
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  const _RoomTile(
      {required this.room, required this.selected, required this.onTap});
  final _PlanRoom room;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        room.isFull ? const Color(0xFFAA6870) : const Color(0xFF56886B);
    return Semantics(
      button: true,
      label:
          'Room ${room.number}, ${room.occupied} of ${room.capacity} occupied',
      child: Material(
        color: color.withValues(alpha: selected ? .24 : .12),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: color, width: selected ? 4 : 2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.meeting_room_outlined, color: color, size: 20),
                  const SizedBox(width: 6),
                  Text(room.number,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900)),
                ]),
                const Spacer(),
                Text(
                    room.isAmenity
                        ? 'Shared space'
                        : '${room.occupied}/${room.capacity} beds',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                if (!room.isAmenity) ...[
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: room.occupied / room.capacity,
                    color: color,
                    backgroundColor: color.withValues(alpha: .18),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanRoom {
  const _PlanRoom(this.number, this.occupied, this.capacity, this.x, this.y,
      {this.note = 'Standard shared room'});
  final String number;
  final int occupied;
  final int capacity;
  final double x, y;
  final String note;
  double get width => 270;
  double get height => 105;
  bool get isAmenity => number == 'COMMON' || number == 'LAUNDRY';
  bool get isFull => occupied >= capacity;
}

const _groundFloor = [
  _PlanRoom('101', 4, 4, 4, 4),
  _PlanRoom('102', 3, 4, 4, 118),
  _PlanRoom('103', 2, 4, 4, 232),
  _PlanRoom('104', 4, 4, 458, 4),
  _PlanRoom('105', 1, 4, 458, 118),
  _PlanRoom('COMMON', 0, 8, 458, 232, note: 'Shared lounge and study area'),
];

const _secondFloor = [
  _PlanRoom('201', 4, 4, 4, 4),
  _PlanRoom('202', 3, 4, 4, 118),
  _PlanRoom('203', 2, 4, 4, 232),
  _PlanRoom('204', 4, 4, 458, 4),
  _PlanRoom('205', 2, 4, 458, 118),
  _PlanRoom('LAUNDRY', 0, 6, 458, 232, note: 'Shared laundry and utility area'),
];

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Chip(
        avatar: Icon(icon, size: 18),
        label: Text(label),
      );
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Chip(
        avatar: CircleAvatar(backgroundColor: color, radius: 6),
        label: Text(label),
      );
}

class _MapMarker extends StatelessWidget {
  const _MapMarker(this.icon, this.label);
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800))
        ],
      );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text))
        ]),
      );
}
