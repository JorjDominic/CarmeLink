import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/web_theme.dart';
import '../widgets/web_brand.dart';
import 'demo_catalog.dart';
import 'demo_store.dart';
import 'demo_ui.dart';

class DemoPortal extends StatefulWidget {
  const DemoPortal({super.key, required this.role, this.store});
  final String role;
  final DemoStore? store;

  @override
  State<DemoPortal> createState() => _DemoPortalState();
}

class _DemoPortalState extends State<DemoPortal> {
  late final DemoStore _store;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? DemoStore();
  }
  String _selected = 'overview';

  bool get _owner => widget.role == 'Owner';

  @override
  void dispose() {
    if (widget.store == null) _store.dispose();
    super.dispose();
  }

  void _navigate(String id) {
    if (id != 'overview' && id != 'floor' && id != 'reports' &&
        !DemoCatalog.forRole(widget.role).any((m) => m.id == id)) return;
    if (id == 'reports' && !_owner) return;
    setState(() => _selected = id);
  }

  void _reset() async {
    final confirmed = await showDialog<bool>(context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset all demo records?'),
        content: const Text('This replaces all your local sample edits with the original fictional data.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reset demo')),
        ],
      ));
    if (confirmed != true || !mounted) return;
    _store.reset();
    _navigate('overview');
  }

  Widget _sidebar({bool closeOnSelect = false}) {
    final modules = DemoCatalog.forRole(widget.role);
    Widget nav(String id, String label, IconData icon) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: _selected == id ? WebPalette.sand : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          dense: true,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          selected: _selected == id,
          selectedColor: WebPalette.plum,
          leading: Icon(icon, size: 20),
          title: Text(label, style: const TextStyle(fontSize: 13,
              fontWeight: FontWeight.w600)),
          onTap: () {
            _navigate(id);
            if (closeOnSelect) Navigator.of(context).pop();
          },
        ),
      ),
    );
    return Container(
      width: 255,
      color: WebPalette.surface,
      child: Column(children: [
        const SizedBox(height: 20),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 19),
            child: Align(alignment: Alignment.centerLeft,
              child: WebBrand(compact: true))),
        const SizedBox(height: 14),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 17),
            child: Align(alignment: Alignment.centerLeft,
              child: DemoBadge(compact: true))),
        const SizedBox(height: 14),
        const Divider(),
        Expanded(child: ListView(children: [
          nav('overview', 'Overview', Icons.space_dashboard_outlined),
          nav('floor', 'Interactive floor plan', Icons.grid_view_outlined),
          const Padding(padding: EdgeInsets.fromLTRB(24, 18, 12, 6),
            child: Text('MANAGEMENT', style: TextStyle(color: WebPalette.muted,
              letterSpacing: 1, fontSize: 10, fontWeight: FontWeight.w800))),
          ...modules.map((m) => nav(m.id, m.title, m.icon)),
          if (_owner) ...[
            const Padding(padding: EdgeInsets.fromLTRB(24, 18, 12, 6),
              child: Text('OWNER', style: TextStyle(color: WebPalette.muted,
                letterSpacing: 1, fontSize: 10, fontWeight: FontWeight.w800))),
            nav('reports', 'Analytics', Icons.analytics_outlined),
          ],
          const SizedBox(height: 20),
        ])),
        const Divider(height: 1),
        Material(
          color: WebPalette.surface,
          child: ListTile(
          leading: const Icon(Icons.restart_alt_outlined),
          title: const Text('Reset sample data'),
          onTap: () {
            if (closeOnSelect) Navigator.pop(context);
            _reset();
          },
          ),
        ),
        Material(
          color: WebPalette.surface,
          child: ListTile(
          leading: const Icon(Icons.logout_outlined),
          title: const Text('Switch demo role'),
          onTap: () {
            if (closeOnSelect) Navigator.pop(context);
            Navigator.of(context).pop();
          },
          ),
        ),
        const SizedBox(height: 12),
      ]),
    );
  }

  Widget _page() {
    if (_selected == 'overview') {
      return _Overview(store: _store, role: widget.role, onNavigate: _navigate);
    }
    if (_selected == 'floor') {
      return _FloorPlan(store: _store, onNavigate: _navigate);
    }
    if (_selected == 'reports' && _owner) {
      return _Reports(store: _store, onNavigate: _navigate);
    }
    final matching = DemoCatalog.forRole(widget.role)
        .where((m) => m.id == _selected);
    if (matching.isEmpty) {
      return const Center(child: Text('This area is not available for this role.'));
    }
    return DemoModulePage(module: matching.first,
      role: widget.role, store: _store);
  }

  @override
  Widget build(BuildContext context) {
    final large = MediaQuery.sizeOf(context).width >= 980;
    return Scaffold(
      drawer: large ? null : Drawer(child: SafeArea(child: _sidebar(closeOnSelect: true))),
      appBar: AppBar(
        toolbarHeight: 70,
        backgroundColor: WebPalette.surface,
        title: Row(children: [
          if (!large) const SizedBox.shrink(),
          Text('Staff workspace', style: TextStyle(
            fontWeight: FontWeight.w700, fontSize: large ? 19 : 16)),
          if (large) ...[
            const SizedBox(width: 16),
            const DemoBadge(compact: true),
          ],
        ]),
        actions: [
          if (!large)
            const Padding(padding: EdgeInsets.only(right: 8),
              child: Center(child: DemoBadge(compact: true))),
          Padding(padding: const EdgeInsets.only(right: 18),
            child: Chip(avatar: const CircleAvatar(
                backgroundColor: WebPalette.sand,
                child: Icon(Icons.person_outline, size: 17)),
              label: Text('Demo ${widget.role}'))),
        ],
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1),
          child: Divider(height: 1)),
      ),
      body: Row(children: [
        if (large) _sidebar(),
        if (large) const VerticalDivider(width: 1),
        Expanded(child: AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero : const Duration(milliseconds: 220),
          child: KeyedSubtree(key: ValueKey(_selected), child: _page()),
        )),
      ]),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.store, required this.role,
      required this.onNavigate});
  final DemoStore store;
  final String role;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => ListView(
      padding: const EdgeInsets.all(28), children: [
        Text('Good day, Demo $role.', style: const TextStyle(
          color: WebPalette.ink, fontSize: 34, letterSpacing: -1.4,
          fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('Your dormitory at a glance · fictional local data',
          style: TextStyle(color: WebPalette.muted)),
        const SizedBox(height: 22),
        Container(
          height: 190,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(24),
            color: WebPalette.plum),
          child: Stack(fit: StackFit.expand, children: [
            Image.asset('assets/web/photos/courtyard.jpg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) =>
                const ColoredBox(color: WebPalette.plum)),
            ColoredBox(color: WebPalette.ink.withValues(alpha: .65)),
            Padding(padding: const EdgeInsets.all(26),
              child: Column(mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('CARMELITA · OPERATIONS',
                    style: TextStyle(color: Colors.white70, fontSize: 11,
                      letterSpacing: 2, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  const Text('A clearer view of every day.',
                    style: TextStyle(color: Colors.white, fontSize: 27,
                      fontWeight: FontWeight.w800)),
                  const SizedBox(height: 9),
                  const Text('Demo only. Nothing here updates the real dormitory.',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                ])),
          ]),
        ),
        const SizedBox(height: 22),
        LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth >= 900 ? 4
              : constraints.maxWidth >= 500 ? 2 : 1;
          final cards = <Widget>[
            DemoKpi(label: 'Occupied beds', value: '${store.occupancy}/${store.capacity}',
              icon: Icons.bed_outlined, subtitle: '${store.count('rooms')} rooms',
              onTap: () => onNavigate('rooms')),
            DemoKpi(label: 'Pending payments', value: '${store.paymentReviews}',
              icon: Icons.payments_outlined, subtitle: 'Awaiting demo review',
              onTap: () => onNavigate('payments')),
            DemoKpi(label: 'Open maintenance', value: '${store.maintenanceOpen}',
              icon: Icons.handyman_outlined, subtitle: 'Sample work orders',
              onTap: () => onNavigate('maintenance')),
            DemoKpi(label: 'Visitor requests',
              value: '${store.rows('visitors').where((r) => r['status'] == 'Pending').length}',
              icon: Icons.badge_outlined, subtitle: 'Pending decision',
              onTap: () => onNavigate('visitors')),
          ];
          return GridView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            itemCount: cards.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns, crossAxisSpacing: 12, mainAxisSpacing: 12,
              mainAxisExtent: 162,
            ),
            itemBuilder: (context, i) => cards[i],
          );
        }),
        const SizedBox(height: 26),
        Text('Quick access', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 14),
        Wrap(spacing: 9, runSpacing: 9, children: [
          for (final id in ['tenants', 'rooms', 'payments', 'maintenance',
              'curfew', 'announcements', 'messages', 'notifications'])
            ActionChip(avatar: Icon(DemoCatalog.byId(id).icon, size: 18),
              label: Text(DemoCatalog.byId(id).title),
              onPressed: () => onNavigate(id)),
        ]),
        const SizedBox(height: 24),
        DemoSectionCard(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Next actions', style: TextStyle(fontSize: 20,
              fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            ...<({String title, String subtitle, String id, IconData icon})>[
              (title: 'Review payment receipts', subtitle: '${store.paymentReviews} waiting',
                id: 'payments', icon: Icons.receipt_long_outlined),
              (title: 'Resolve maintenance', subtitle: '${store.maintenanceOpen} active',
                id: 'maintenance', icon: Icons.build_outlined),
              (title: 'Manage curfew requests', subtitle: 'Approve or reject sample requests',
                id: 'curfew', icon: Icons.schedule_outlined),
            ].map((action) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(action.icon, color: WebPalette.plum),
              title: Text(action.title), subtitle: Text(action.subtitle),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () => onNavigate(action.id),
            )),
          ])),
      ],
    ),
  );
}

class _FloorPlan extends StatelessWidget {
  const _FloorPlan({required this.store, required this.onNavigate});
  final DemoStore store;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: store,
    builder: (context, _) => ListView(padding: const EdgeInsets.all(28), children: [
      const Text('Room floor plan', style: TextStyle(fontSize: 32,
        color: WebPalette.ink, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      const Text('Illustrative room grid, not a measured building blueprint.',
        style: TextStyle(color: WebPalette.muted)),
      const SizedBox(height: 22),
      ...['Ground', 'Second', 'Third'].map((floor) {
        final rooms = store.rows('rooms').where((r) => r['floor'] == floor).toList();
        if (rooms.isEmpty) return const SizedBox.shrink();
        return Padding(padding: const EdgeInsets.only(bottom: 25),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$floor floor', style: const TextStyle(fontSize: 19,
              fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            LayoutBuilder(builder: (context, constraints) => GridView.builder(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              itemCount: rooms.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: constraints.maxWidth >= 900 ? 5
                  : constraints.maxWidth >= 540 ? 3 : 2,
                crossAxisSpacing: 10, mainAxisSpacing: 10,
                mainAxisExtent: 143,
              ),
              itemBuilder: (context, i) {
                final room = rooms[i];
                final occupied = store.occupiedIn(room['id']!);
                final capacity = int.tryParse(room['capacity'] ?? '') ?? 0;
                return InkWell(onTap: () => onNavigate('rooms'),
                  borderRadius: BorderRadius.circular(18),
                  child: DemoSectionCard(padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.meeting_room_outlined, color: WebPalette.plum),
                        const Spacer(),
                        Text(room['name']!, style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                        Text('$occupied/$capacity beds · ${room['status']}',
                          style: const TextStyle(color: WebPalette.muted, fontSize: 11)),
                      ])),
                );
              },
            )),
          ]));
      }),
    ]));
}

class _Reports extends StatelessWidget {
  const _Reports({required this.store, required this.onNavigate});
  final DemoStore store;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: store,
    builder: (context, _) {
      final occupancy = store.capacity == 0 ? 0.0 : store.occupancy / store.capacity;
      return ListView(padding: const EdgeInsets.all(28), children: [
        const Text('Analytics', style: TextStyle(fontSize: 32,
          fontWeight: FontWeight.w800, color: WebPalette.ink)),
        const SizedBox(height: 7),
        const Text('Calculated from the current in-memory demo records.',
          style: TextStyle(color: WebPalette.muted)),
        const SizedBox(height: 22),
        LayoutBuilder(builder: (context, constraints) {
          final cols = constraints.maxWidth >= 820 ? 3 : constraints.maxWidth >= 540 ? 2 : 1;
          final values = [
            DemoKpi(label: 'Bed occupancy', value: '${(occupancy * 100).toStringAsFixed(1)}%',
              icon: Icons.bed_outlined, onTap: () => onNavigate('rooms')),
            DemoKpi(label: 'Verified sample income',
              value: '₱${store.verifiedIncome.toStringAsFixed(0)}',
              icon: Icons.trending_up_outlined, onTap: () => onNavigate('payments')),
            DemoKpi(label: 'Sample expenses',
              value: '₱${store.expenses.toStringAsFixed(0)}',
              icon: Icons.receipt_long_outlined, onTap: () => onNavigate('expenses')),
          ];
          return GridView.builder(shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: values.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols, crossAxisSpacing: 12, mainAxisSpacing: 12,
              mainAxisExtent: 137),
            itemBuilder: (context, i) => values[i],
          );
        }),
        const SizedBox(height: 22),
        DemoSectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Occupancy breakdown', style: TextStyle(fontSize: 20,
              fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            LinearProgressIndicator(value: occupancy.clamp(0.0, 1.0).toDouble(),
              minHeight: 14, borderRadius: BorderRadius.circular(10),
              backgroundColor: WebPalette.sand,
              color: WebPalette.plum),
            const SizedBox(height: 9),
            Text('${store.occupancy} occupied · ${store.capacity - store.occupancy} available bed slots',
              style: const TextStyle(color: WebPalette.muted)),
            const SizedBox(height: 22),
            const Text('Records by area', style: TextStyle(fontSize: 19,
              fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            ...DemoCatalog.modules.map((module) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(module.icon, color: WebPalette.plum),
              title: Text(module.title),
              trailing: Text('${store.count(module.id)} records'),
              onTap: () => onNavigate(module.id),
            )),
            const SizedBox(height: 16),
            OutlinedButton.icon(onPressed: () async {
              final buffer = StringBuffer('Area,Count\r\n');
              for (final m in DemoCatalog.modules) {
                buffer.writeln('"${m.title}",${store.count(m.id)}');
              }
              await Clipboard.setData(ClipboardData(text: buffer.toString()));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Sample report copied to clipboard.')));
              }
            }, icon: const Icon(Icons.copy_all_outlined),
              label: const Text('Copy summary CSV')),
          ])),
      ]);
    },
  );
}
