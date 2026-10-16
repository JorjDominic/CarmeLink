import 'package:flutter/material.dart';
import '../../core/utils/contract_occupancy_policy.dart';
import '../../services/room_service.dart';

/// Presentation only: no rental calculation or contract mutation.
class RoomOccupancySummary extends StatelessWidget {
  const RoomOccupancySummary(
      {required this.room,
      this.compact = false,
      this.showFinancial = false,
      super.key});
  final RoomRecord room;
  final bool compact, showFinancial;
  @override
  Widget build(BuildContext context) {
    final group = room.occupancy;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (!compact)
        Text(room.occupancyLabel,
            style: Theme.of(context).textTheme.titleMedium),
      Text(
          'Physical capacity: ${room.capacity} beds • Assigned tenants: ${room.occupied}'),
      Text(
          'Available for assignment: ${room.physicallyAvailable} • Unused beds: ${room.unusedBeds}'),
      Text('Contractually reserved beds: ${room.contractuallyReservedBeds}'),
      if (room.hasReservation)
        const Text('Entire room reserved for the contracted occupants.'),
      if (room.contractGroups.isNotEmpty) ...[
        Text('${room.contractMembers.length} contracted occupant(s)'),
        if (showFinancial && group?.totalRentCents != null)
          Text(
              'Agreed room rental: PHP ${rentCentsText(group!.totalRentCents!)} / month'),
        for (final member in room.contractMembers)
          Text('${member.name} • ${member.bedLabel} • ${member.status}'
              '${room.beds.any((bed) => bed.occupied && bed.tenantId == member.tenantId && bed.id == member.bedId) ? '' : ' • Not currently assigned'}'
              '${showFinancial && member.rentCents != null ? ' • PHP ${rentCentsText(member.rentCents!)} / month' : ''}'),
        if (!compact)
          const Text(
              'Contract obligations remain unchanged when an occupant leaves. Changes require an approved amendment.'),
      ] else ...[
        for (final bed in room.beds.where((bed) => bed.occupied))
          Text('${bed.tenantName ?? 'Assigned tenant'} • ${bed.label}'),
      ],
    ]);
  }
}

class RoomOccupancyHistoryView extends StatefulWidget {
  const RoomOccupancyHistoryView(
      {required this.roomId,
      required this.service,
      this.revision = 0,
      this.showFinancial = false,
      super.key});
  final String roomId;
  final RoomService service;
  final int revision;
  final bool showFinancial;
  @override
  State<RoomOccupancyHistoryView> createState() =>
      _RoomOccupancyHistoryViewState();
}

typedef _History = ({
  List<RoomContractOccupancy> contracts,
  List<RoomAssignmentHistory> assignments
});

class _RoomOccupancyHistoryViewState extends State<RoomOccupancyHistoryView> {
  Future<_History>? _history;
  bool _expanded = false;
  Future<_History> _load() async {
    final values = await Future.wait([
      widget.service.listOccupancyHistory(widget.roomId),
      widget.service.listAssignmentHistory(widget.roomId),
    ]);
    return (
      contracts: values[0].cast<RoomContractOccupancy>(),
      assignments: values[1].cast<RoomAssignmentHistory>()
    );
  }

  Future<_History> _startLoad() {
    final future = _load();
    // Expansion builds FutureBuilder on the next frame. Handle immediate
    // failures until it subscribes; the builder still displays the error.
    future.ignore();
    return future;
  }

  @override
  void didUpdateWidget(covariant RoomOccupancyHistoryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_expanded &&
        (oldWidget.revision != widget.revision ||
            oldWidget.roomId != widget.roomId)) _history = _startLoad();
  }

  @override
  Widget build(BuildContext context) => ExpansionTile(
        key: const Key('room-occupancy-history'),
        title: const Text('Occupancy history'),
        subtitle:
            const Text('Contract arrangements and original bed assignments'),
        onExpansionChanged: (expanded) => setState(() {
          _expanded = expanded;
          if (expanded) _history = _startLoad();
        }),
        children: [
          if (_history != null)
            FutureBuilder<_History>(
                future: _history,
                builder: (context, snapshot) {
                  if (snapshot.hasError)
                    return Column(children: [
                      Text(roomServiceError(snapshot.error!)),
                      TextButton(
                          onPressed: () => setState(() {
                                _history = _startLoad();
                              }),
                          child: const Text('Retry history')),
                    ]);
                  if (!snapshot.hasData)
                    return const Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator());
                  final history = snapshot.data!;
                  return Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (history.contracts.isEmpty &&
                                history.assignments.isEmpty)
                              const Text('No occupancy history recorded.'),
                            for (final group in history.contracts) ...[
                              Text(
                                  '${occupancyModeLabel(group.mode)} arrangement • ${group.released ? 'Released' : 'Reserved'}',
                                  style:
                                      Theme.of(context).textTheme.titleSmall),
                              Text('${group.startsOn} to ${group.endsOn}'),
                              for (final member in group.members)
                                Text(
                                    '${member.name} • ${member.bedLabel} • ${member.contractNumber ?? member.contractId ?? 'Contract pending'} • ${member.status}'
                                    '${widget.showFinancial && member.rentCents != null ? ' • PHP ${rentCentsText(member.rentCents!)} / month' : ''}'),
                              const Divider(),
                            ],
                            for (final assignment in history.assignments)
                              Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                      '${assignment.name} • ${assignment.bedLabel} • ${assignment.status}\n${assignment.startsOn} to ${assignment.endsOn ?? 'Ongoing'}')),
                          ]));
                })
        ],
      );
}
