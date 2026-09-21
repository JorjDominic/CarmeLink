import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/common_widgets.dart';
import '../../services/room_service.dart';
import '../../services/table_refresh_subscription.dart';
import '../../services/tenant_service.dart';
import '../shared/staff_quick_panel.dart';
import 'floor_plan_page.dart';
import 'owner_pages.dart';

enum RoomViewMode { list, floorPlan }

/// A display-only filter over already authorized RoomService records.
List<RoomRecord> filterRoomDirectory(
  List<RoomRecord> rooms, {
  String query = '',
  String availability = 'all',
}) {
  final needle = query.trim().toLowerCase();
  return rooms.where((room) {
    if (availability == 'available' && room.physicallyAvailable == 0) {
      return false;
    }
    if (availability == 'full' &&
        !(room.capacity > 0 && room.occupied >= room.capacity)) {
      return false;
    }
    return needle.isEmpty ||
        [room.number, room.floor, room.description]
            .any((value) => value.toLowerCase().contains(needle));
  }).toList();
}

class RoomMonitoringPage extends StatefulWidget {
  const RoomMonitoringPage({
    super.key,
    this.initialMode = RoomViewMode.list,
  });

  final RoomViewMode initialMode;

  @override
  State<RoomMonitoringPage> createState() => _RoomMonitoringPageState();
}

class _RoomMonitoringPageState extends State<RoomMonitoringPage> {
  late RoomViewMode _viewMode = widget.initialMode;
  final service = const RoomService();
  List<RoomRecord>? rooms;
  bool loading = true;
  String? errorMessage;
  String _roomQuery = '';
  String _availabilityFilter = 'all';
  int _requestVersion = 0;
  Timer? _debounceTimer;
  late final TableRefreshSubscription subscription;

  @override
  void initState() {
    super.initState();
    rooms = RoomService.cachedRooms;
    loading = rooms == null;
    _loadRooms(showSpinner: rooms == null);
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
      final visibleRooms = kIsWeb
          ? filterRoomDirectory(currentRooms,
              query: _roomQuery, availability: _availabilityFilter)
          : currentRooms;
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
          Row(
            children: [
              Expanded(
                child: SegmentedButton<RoomViewMode>(
                  segments: const [
                    ButtonSegment(
                      value: RoomViewMode.list,
                      label: Text('List view'),
                      icon: Icon(Icons.view_agenda_outlined),
                    ),
                    ButtonSegment(
                      value: RoomViewMode.floorPlan,
                      label: Text('Floor plan map'),
                      icon: Icon(Icons.map_outlined),
                    ),
                  ],
                  selected: {_viewMode},
                  onSelectionChanged: (selection) {
                    setState(() => _viewMode = selection.first);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (kIsWeb && _viewMode == RoomViewMode.list) ...[
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 300,
                  child: TextField(
                    key: const Key('web-room-search'),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search room number or floor',
                    ),
                    onChanged: (value) => setState(() => _roomQuery = value),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    key: const Key('web-room-availability-filter'),
                    initialValue: _availabilityFilter,
                    decoration:
                        const InputDecoration(labelText: 'Availability'),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All rooms')),
                      DropdownMenuItem(
                          value: 'available', child: Text('Beds available')),
                      DropdownMenuItem(
                          value: 'full', child: Text('Fully occupied')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _availabilityFilter = value);
                      }
                    },
                  ),
                ),
                Text('${visibleRooms.length} of ${currentRooms.length} rooms'),
              ],
            ),
            const SizedBox(height: 14),
          ],
          if (_viewMode == RoomViewMode.list) ...[
            if (visibleRooms.isEmpty)
              const EmptyState(
                icon: Icons.search_off_outlined,
                title: 'No matching rooms',
                message: 'Try another search or availability filter.',
              )
            else
              AdaptiveGrid(
                minTileWidth: 260,
                children: visibleRooms.map(roomCard).toList(),
              ),
          ] else
            RoomFloorPlanView(
              rooms: currentRooms,
              onRoomTap: _openRoomDetail,
            ),
        ],
      );
    }

    return PageFrame(
      title: 'Room monitoring',
      subtitle: _viewMode == RoomViewMode.list
          ? 'Live rooms, bed spaces, occupancy, and availability'
          : 'Interactive building layout, occupancy, and room status',
      onRefresh: () => _loadRooms(showSpinner: currentRooms == null),
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
    if (kIsWeb && MediaQuery.sizeOf(context).width >= 1024) {
      final openFull = await showStaffQuickPanel<bool>(
        context,
        builder: (panelContext) => RoomQuickPreview(
          room: room,
          onClose: () => Navigator.of(panelContext).pop(),
          onFullDetails: () => Navigator.of(panelContext).pop(true),
        ),
      );

      if (!mounted || openFull != true) return;
    }

    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RoomDetailPage(
          initialRoom: room,
          service: service,
        ),
      ),
    );

    if (mounted) {
      await _loadRooms();
    }
  }
}

/// Quick, read-only summary. All room/bed mutations remain in RoomDetailPage.
class RoomQuickPreview extends StatelessWidget {
  const RoomQuickPreview({
    required this.room,
    required this.onFullDetails,
    required this.onClose,
    super.key,
  });

  final RoomRecord room;
  final VoidCallback onFullDetails;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Column(
        key: const Key('room-quick-preview'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Room ${room.number}',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              IconButton(
                tooltip: 'Close quick details',
                onPressed: onClose,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(room.floor, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          InfoRow(
            label: 'Occupied beds',
            value: '${room.occupied} of ${room.capacity}',
            icon: Icons.bed_outlined,
          ),
          InfoRow(
            label: 'Available beds',
            value: '${room.physicallyAvailable}',
            icon: Icons.event_available_outlined,
          ),
          if (room.description.trim().isNotEmpty)
            InfoRow(
              label: 'Notes',
              value: room.description,
              icon: Icons.notes_outlined,
            ),
          const Divider(height: 32),
          Text('Bed spaces', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (room.beds.isEmpty)
            const Text('No bed spaces configured.')
          else
            ...room.beds.map(
              (bed) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                    bed.occupied ? Icons.person_outline : Icons.bed_outlined),
                title: Text(bed.label),
                subtitle: Text(bed.occupied
                    ? (bed.tenantName ?? 'Occupied')
                    : bedStatusLabel(bed.status)),
              ),
            ),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const Key('room-quick-full-details'),
            onPressed: onFullDetails,
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open room management'),
          ),
        ],
      );
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

  Future<void> _moveTenant(BedRecord bed) async {
    if (bed.tenantId == null) {
      showAppSnackBar(context, 'No tenant assigned to this bed space.');
      return;
    }
    final tenantName = bed.tenantName ?? 'Tenant';

    try {
      final availableRooms =
          await const TenantService().loadAvailableBedsGroupedByRoom();
      if (!mounted) return;

      if (availableRooms.isEmpty) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('No available beds'),
            content: const Text(
              'All other beds are currently occupied or unavailable. Please add or free up a bed before moving this tenant.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      final selected = await showModalBottomSheet<AvailableBed>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) => RoomBedSelectorSheet(
          rooms: availableRooms,
          tenantName: tenantName,
        ),
      );

      if (selected == null || !mounted) return;

      await widget.service.reassignTenantBed(
        tenantId: bed.tenantId!,
        newBedId: selected.id,
      );

      if (mounted) {
        showAppSnackBar(
          context,
          'Moved $tenantName to Room ${selected.room} • ${selected.label}',
        );
        await _refreshRoom();
      }
    } catch (error) {
      if (mounted) {
        showAppSnackBar(context, tenantAssignmentError(error));
      }
    }
  }

  Future<void> _endAssignment(BedRecord bed) async {
    if (bed.tenantId == null) return;
    final tenantName = bed.tenantName ?? 'Tenant';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End bed assignment?'),
        content: Text(
          'Are you sure you want to end $tenantName\'s assignment to ${bed.label}? This bed will become available for other tenants.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('End assignment'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await widget.service.endTenantAssignment(tenantId: bed.tenantId!);
      if (mounted) {
        showAppSnackBar(context, 'Ended assignment for $tenantName.');
        await _refreshRoom();
      }
    } catch (error) {
      if (mounted) {
        showAppSnackBar(context, tenantAssignmentError(error));
      }
    }
  }

  void _showOccupiedBedActions(BedRecord bed) {
    final tenantName = bed.tenantName ?? 'Tenant';
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color:
                      theme.colorScheme.onSurfaceVariant.withValues(alpha: .3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      const Color(0xFF56886B).withValues(alpha: .15),
                  foregroundColor: const Color(0xFF56886B),
                  child: const Icon(Icons.person),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Room ${room.number} • ${bed.label}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Occupant: $tenantName'
                        '${bed.tenantPhone != null && bed.tenantPhone!.isNotEmpty ? ' (${bed.tenantPhone})' : ''}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 8),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0x192563EB),
                foregroundColor: Color(0xFF2563EB),
                child: Icon(Icons.swap_horiz_rounded),
              ),
              title: const Text(
                'Move to another bed',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle:
                  const Text('Reassign this tenant to any open bed space'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _moveTenant(bed);
              },
            ),
            const SizedBox(height: 4),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.error.withValues(alpha: .12),
                foregroundColor: theme.colorScheme.error,
                child: const Icon(Icons.person_remove_outlined),
              ),
              title: Text(
                'End assignment',
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text('Remove tenant and mark bed as available'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _endAssignment(bed);
              },
            ),
            const SizedBox(height: 4),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                foregroundColor: theme.colorScheme.onSurfaceVariant,
                child: const Icon(Icons.edit_outlined),
              ),
              title: const Text(
                'Edit bed label',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Change bed space name or label'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                editBed(bed);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Room ${room.number}',
      subtitle:
          '${room.floor} • ${room.beds.length}/${room.capacity} bed spaces',
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
            subtitle:
                'Manage availability, labels, and maintenance for each bed',
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
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: bed.occupied
                          ? () => _showOccupiedBedActions(bed)
                          : () => editBed(bed),
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
                              bed.occupied ? Icons.person : Icons.bed_outlined,
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
                                if (bed.occupied) ...[
                                  Text(
                                    bed.tenantName != null &&
                                            bed.tenantName!.isNotEmpty
                                        ? bed.tenantName!
                                        : 'Occupied by active assignment',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13.5,
                                      color: Color(0xFF56886B),
                                    ),
                                  ),
                                  if (bed.tenantPhone != null &&
                                      bed.tenantPhone!.isNotEmpty)
                                    Text(
                                      bed.tenantPhone!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(fontSize: 12),
                                    ),
                                ] else
                                  Text(
                                    'Status: ${bedStatusLabel(bed.status)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.color,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          StatusPill(
                            bed.occupied
                                ? 'Occupied'
                                : bedStatusLabel(bed.status),
                            icon: bed.occupied
                                ? Icons.lock_outline
                                : Icons.check_circle_outline,
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: bed.occupied
                                ? 'Move or manage assignment'
                                : 'Edit bed',
                            onPressed: bed.occupied
                                ? () => _showOccupiedBedActions(bed)
                                : () => editBed(bed),
                            icon: Icon(
                              bed.occupied
                                  ? Icons.swap_horiz_rounded
                                  : Icons.edit_outlined,
                              color:
                                  bed.occupied ? const Color(0xFF2563EB) : null,
                            ),
                          ),
                        ],
                      ),
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
