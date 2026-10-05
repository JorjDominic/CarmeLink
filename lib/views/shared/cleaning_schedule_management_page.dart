import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/utils/cleaning_schedule_policy.dart';
import '../../core/utils/natural_sort.dart';
import '../../core/widgets/common_widgets.dart';
import '../../services/cleaning_schedule_management_service.dart';
import '../../services/room_service.dart';
import '../../services/table_refresh_subscription.dart';
import 'room_cleaning_pages.dart';

class CleaningScheduleManagementPage extends StatefulWidget {
  const CleaningScheduleManagementPage({super.key});

  @override
  State<CleaningScheduleManagementPage> createState() =>
      _CleaningScheduleManagementPageState();
}

class _CleaningScheduleManagementPageState
    extends State<CleaningScheduleManagementPage> {
  static const _roomService = RoomService();
  static const _scheduleService = CleaningScheduleManagementService();

  late final TableRefreshSubscription _subscription;
  List<RoomRecord> _rooms = const [];
  List<ManagedCleaningSchedule> _schedules = const [];
  bool _loading = true;
  String? _errorMessage;
  String? _regeneratingRoomId;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _subscription = TableRefreshSubscription(
      'phase5-cleaning-management',
      const [
        'rooms',
        'bed_spaces',
        'tenant_assignments',
        'cleaning_schedules',
      ],
      () {
        if (mounted) unawaited(_load(showSpinner: false));
      },
    );
  }

  @override
  void dispose() {
    unawaited(_subscription.dispose());
    super.dispose();
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner && mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      final rooms = await _roomService.listRooms(forceRefresh: true);
      final orderedRooms = List<RoomRecord>.from(rooms)
        ..sort((a, b) => compareNaturalLabels(a.number, b.number));
      final schedules = await _scheduleService.listForRooms(orderedRooms);
      if (!mounted) return;
      setState(() {
        _rooms = orderedRooms;
        _schedules = schedules;
        _loading = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = cleaningScheduleManagementError(error);
      });
    }
  }

  List<ManagedCleaningSchedule> _forBed(String bedId) => _schedules
      .where((schedule) => schedule.bedSpaceId == bedId)
      .toList(growable: false)
    ..sort((a, b) => a.weekday.compareTo(b.weekday));

  Future<void> _regenerate(RoomRecord room) async {
    if (_regeneratingRoomId != null) return;
    setState(() => _regeneratingRoomId = room.id);
    try {
      final occupied = await _scheduleService.regenerateRoom(room.id);
      if (!mounted) return;
      showAppSnackBar(
        context,
        occupied == 0
            ? 'Room ${room.number} has no occupied beds to schedule.'
            : 'Automatic rotation refreshed for $occupied occupied bed(s).',
      );
      await _load(showSpinner: false);
    } catch (error) {
      if (mounted) {
        showAppSnackBar(context, cleaningScheduleManagementError(error));
      }
    } finally {
      if (mounted) setState(() => _regeneratingRoomId = null);
    }
  }

  Future<void> _openRoomEditor(RoomRecord room) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => StaffRoomCleaningPage(
          roomId: room.id,
          roomNumber: room.number,
          beds: room.beds,
        ),
      ),
    );
    if (mounted) await _load(showSpinner: false);
  }

  @override
  Widget build(BuildContext context) {
    final occupiedBeds = _rooms.fold<int>(
      0,
      (sum, room) => sum + room.beds.where((bed) => bed.occupied).length,
    );
    final automatic = _schedules
        .where((schedule) => schedule.isAutomatic)
        .map((schedule) => schedule.bedSpaceId)
        .toSet()
        .length;
    final manual = _schedules
        .where((schedule) => !schedule.isAutomatic)
        .map((schedule) => schedule.bedSpaceId)
        .toSet()
        .length;

    return PageFrame(
      title: 'Cleaning',
      subtitle: 'Automatic occupied-bed rotation with manual overrides',
      useScriptTitle: false,
      onRefresh: () => _load(showSpinner: false),
      child: _loading && _rooms.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AdaptiveGrid(
                  minTileWidth: 180,
                  children: [
                    MetricCard(
                      label: 'Rooms',
                      value: '${_rooms.length}',
                      detail: 'Configured dormitory rooms',
                      icon: Icons.meeting_room_outlined,
                    ),
                    MetricCard(
                      label: 'Occupied beds',
                      value: '$occupiedBeds',
                      detail: 'Eligible for automatic rotation',
                      icon: Icons.bed_outlined,
                    ),
                    MetricCard(
                      label: 'Automatic beds',
                      value: '$automatic',
                      detail: 'System-generated weekly duties',
                      icon: Icons.autorenew_rounded,
                    ),
                    MetricCard(
                      label: 'Manual override beds',
                      value: '$manual',
                      detail: 'Staff-edited weekly duties',
                      icon: Icons.edit_calendar_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                CarmelitaCard(
                  emphasis: true,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.auto_awesome_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Rotation rule: occupied beds are ordered by bed label and receive one weekly duty day in Monday-to-Sunday round-robin order. Vacant beds are removed automatically. A staff-edited bed becomes a manual override and is preserved during regeneration.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  CarmelitaCard(
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_errorMessage!)),
                        TextButton(
                          onPressed: () => _load(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                const SectionTitle(
                  'Room rotations',
                  subtitle:
                      'Automatic schedules remain editable through the existing room cleaning editor',
                ),
                const SizedBox(height: 10),
                if (_rooms.isEmpty)
                  const EmptyState(
                    icon: Icons.meeting_room_outlined,
                    title: 'No rooms configured',
                    message: 'Create rooms before generating cleaning duties.',
                  )
                else
                  ..._rooms.map(
                    (room) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _RoomCleaningRotationCard(
                        room: room,
                        schedulesForBed: _forBed,
                        regenerating: _regeneratingRoomId == room.id,
                        onRegenerate: () => _regenerate(room),
                        onEdit: () => _openRoomEditor(room),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _RoomCleaningRotationCard extends StatelessWidget {
  const _RoomCleaningRotationCard({
    required this.room,
    required this.schedulesForBed,
    required this.regenerating,
    required this.onRegenerate,
    required this.onEdit,
  });

  final RoomRecord room;
  final List<ManagedCleaningSchedule> Function(String bedId) schedulesForBed;
  final bool regenerating;
  final VoidCallback onRegenerate;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final occupied = room.beds.where((bed) => bed.occupied).toList()
      ..sort((a, b) => compareNaturalLabels(a.label, b.label));

    return CarmelitaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                child: Text(room.number),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Room ${room.number}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${occupied.length} of ${room.beds.length} beds occupied',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              StatusPill(
                occupied.isEmpty ? 'No duties' : 'Rotation active',
                icon: occupied.isEmpty
                    ? Icons.hotel_outlined
                    : Icons.autorenew_rounded,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (occupied.isEmpty)
            Text(
              'Vacant rooms do not receive automatic cleaning duties.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            ...occupied.map((bed) {
              final entries = schedulesForBed(bed.id);
              final days = entries.isEmpty
                  ? 'Waiting for automatic rotation'
                  : entries
                      .map((entry) => cleaningWeekdayShort(entry.weekday))
                      .join(' • ');
              final hasManual = entries.any((entry) => !entry.isAutomatic);
              final generator = entries.isEmpty
                  ? 'System pending'
                  : hasManual
                      ? entries
                              .map((entry) => entry.createdByName)
                              .whereType<String>()
                              .firstOrNull ??
                          'Authorized staff'
                      : entries
                              .map((entry) => entry.createdByName)
                              .whereType<String>()
                              .firstOrNull ??
                          'System rotation';

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.bed_outlined, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bed.label,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(days),
                            const SizedBox(height: 2),
                            Text(
                              entries.isEmpty
                                  ? generator
                                  : '${hasManual ? 'Manual override' : 'Automatic rotation'} • $generator',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed:
                    occupied.isEmpty || regenerating ? null : onRegenerate,
                icon: regenerating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.autorenew_rounded),
                label: Text(
                  regenerating ? 'Regenerating…' : 'Regenerate automatic',
                ),
              ),
              FilledButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_calendar_outlined),
                label: const Text('Review & edit'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
