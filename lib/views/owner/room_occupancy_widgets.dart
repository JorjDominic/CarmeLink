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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    Widget heading(String title, IconData icon, {String? trailing}) => Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 10),
          child: Row(children: [
            Icon(icon, size: 17, color: colors.primary),
            const SizedBox(width: 8),
            Expanded(
                child: Text(title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700))),
            if (trailing != null)
              Text(trailing, style: theme.textTheme.labelMedium),
          ]),
        );
    final content =
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (!compact) ...[
        Text('ROOM OVERVIEW',
            style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 1.3,
                color: colors.primary,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('Room ${room.number}',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        Text(room.floor,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant)),
        const SizedBox(height: 14),
      ],
      Wrap(spacing: 6, runSpacing: 6, children: [
        _RoomTag(
            label: occupancyModeLabel(room.arrangement),
            icon: Icons.meeting_room_outlined),
      ]),
      if (!compact) ...[
        const SizedBox(height: 8),
        Text(room.occupancyLabel, style: theme.textTheme.labelLarge),
      ],
      const SizedBox(height: 12),
      LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth >= 700
            ? 5
            : constraints.maxWidth >= 440
                ? 3
                : 2;
        final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
        return Wrap(spacing: 8, runSpacing: 8, children: [
          for (final fact in <(String, String, IconData)>[
            ('Physical capacity', '${room.capacity} beds', Icons.bed_outlined),
            ('Assigned tenants', '${room.occupied}', Icons.people_outline),
            (
              'Available for assignment',
              '${room.physicallyAvailable}',
              Icons.event_available_outlined
            ),
            (
              'Unused beds',
              '${room.unusedBeds}',
              Icons.bedroom_parent_outlined
            ),
            (
              'Contractually reserved beds',
              '${room.contractuallyReservedBeds}',
              Icons.lock_outline
            ),
          ])
            SizedBox(
                width: width,
                child: _OccupancyFact(
                    label: fact.$1, value: fact.$2, icon: fact.$3)),
        ]);
      }),
      if (room.hasReservation) ...[
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline, size: 15, color: colors.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
              child: Text('Entire room reserved for the contracted occupants.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant))),
        ]),
      ],
      if (room.contractMembers.isNotEmpty) ...[
        if (showFinancial && group?.totalRentCents != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(12)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('AGREED ROOM RENTAL',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: colors.primary, letterSpacing: .8)),
              const SizedBox(height: 4),
              Text(_monthlyRent(group!.totalRentCents!),
                  style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800, color: colors.primary)),
            ]),
          ),
        ],
        heading('Contracted occupants', Icons.people_outline,
            trailing: '${room.contractMembers.length}'),
        for (final member in room.contractMembers) ...[
          _ContractOccupantTile(
              member: member,
              showFinancial: showFinancial,
              assigned: room.beds.any((bed) =>
                  bed.occupied &&
                  bed.tenantId == member.tenantId &&
                  bed.id == member.bedId)),
          if (member != room.contractMembers.last) const Divider(height: 20),
        ],
        if (!compact) ...[
          const Divider(height: 28),
          Text(
              'Contract obligations remain unchanged when an occupant leaves. Changes require an approved amendment.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant)),
        ],
      ] else if (room.occupied > 0) ...[
        heading('Assigned occupants', Icons.people_outline),
        for (final bed in room.beds.where((bed) => bed.occupied))
          _RoomInformationRow(
              label: bed.label, value: bed.tenantName ?? 'Assigned tenant'),
      ],
    ]);
    if (compact) return content;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(18)),
      child: content,
    );
  }
}

class _ContractOccupantTile extends StatelessWidget {
  const _ContractOccupantTile(
      {required this.member,
      required this.showFinancial,
      required this.assigned});
  final RoomContractMember member;
  final bool showFinancial, assigned;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CircleAvatar(
          radius: 16,
          backgroundColor: colors.primary.withValues(alpha: .08),
          child: Icon(Icons.person_outline, size: 18, color: colors.primary)),
      const SizedBox(width: 10),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(member.name,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        Wrap(spacing: 6, runSpacing: 6, children: [
          _RoomTag(label: member.bedLabel, icon: Icons.bed_outlined),
          _RoomTag(label: member.status, icon: Icons.description_outlined),
        ]),
        if (!assigned)
          Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text('Not currently assigned',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant))),
        if (showFinancial && member.rentCents != null)
          Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_monthlyRent(member.rentCents!),
                  style: theme.textTheme.labelLarge?.copyWith(
                      color: colors.primary, fontWeight: FontWeight.w700))),
      ])),
    ]);
  }
}

class _RoomTag extends StatelessWidget {
  const _RoomTag({required this.label, required this.icon});
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(7)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: colors.onSurfaceVariant),
        const SizedBox(width: 5),
        Flexible(
            child: Text(label, style: Theme.of(context).textTheme.labelSmall)),
      ]),
    );
  }
}

// Format the supplied cents without changing allocation or rounding.
String _monthlyRent(int cents) {
  final parts = rentCentsText(cents).split('.');
  final whole = parts.first.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'), (match) => '${match[1]},');
  return '\u20b1$whole.${parts.last}/month';
}

class _RoomInformationRow extends StatelessWidget {
  const _RoomInformationRow({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              flex: 2,
              child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          const SizedBox(width: 8),
          Expanded(
              flex: 3,
              child:
                  Text(value, style: Theme.of(context).textTheme.bodyMedium)),
        ]),
      );
}

class _OccupancyFact extends StatelessWidget {
  const _OccupancyFact(
      {required this.label, required this.value, required this.icon});
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: colors.primary),
        const SizedBox(height: 6),
        Text(value,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: colors.onSurfaceVariant)),
      ]),
    );
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
