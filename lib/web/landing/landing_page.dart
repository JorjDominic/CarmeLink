import 'package:flutter/material.dart';

import '../theme/web_theme.dart';
import '../widgets/web_brand.dart';

/// Public marketing site. All photos come from the existing Flutter assets.
/// No prices, vacancy claims, contact details or inquiry submissions are faked.
class LandingPage extends StatefulWidget {
  const LandingPage({super.key, required this.onStaffPortal});

  final VoidCallback onStaffPortal;

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  static const _ink = WebPalette.ink;
  static const _purple = WebPalette.primary;
  static const _muted = WebPalette.muted;
  static const _soft = WebPalette.soft;

  final _homeKey = GlobalKey();
  final _aboutKey = GlobalKey();
  final _roomsKey = GlobalKey();
  final _amenitiesKey = GlobalKey();
  final _galleryKey = GlobalKey();
  final _rulesKey = GlobalKey();
  final _contactKey = GlobalKey();

  void _go(GlobalKey key) {
    final target = key.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOutCubic,
      alignment: 0.04,
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 950;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        toolbarHeight: 76,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        titleSpacing: wide ? 40 : 16,
        title: InkWell(
          onTap: () => _go(_homeKey),
          child: const WebBrand(),
        ),
        actions: wide
            ? [
                _navText('Home', () => _go(_homeKey)),
                _navText('About', () => _go(_aboutKey)),
                _navText('Rooms', () => _go(_roomsKey)),
                _navText('Amenities', () => _go(_amenitiesKey)),
                _navText('Gallery', () => _go(_galleryKey)),
                _navText('House Rules', () => _go(_rulesKey)),
                _navText('Contact', () => _go(_contactKey)),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(right: 32),
                  child: FilledButton.icon(
                    onPressed: widget.onStaffPortal,
                    style: FilledButton.styleFrom(backgroundColor: _purple),
                    icon: const Icon(Icons.login, size: 17),
                    label: const Text('Staff portal'),
                  ),
                ),
              ]
            : [
                PopupMenuButton<String>(
                  tooltip: 'Open navigation',
                  icon: const Icon(Icons.menu, color: _ink),
                  onSelected: (value) {
                    if (value == 'staff') {
                      widget.onStaffPortal();
                      return;
                    }
                    final key = {
                      'home': _homeKey, 'about': _aboutKey,
                      'rooms': _roomsKey, 'amenities': _amenitiesKey,
                      'gallery': _galleryKey, 'rules': _rulesKey,
                      'contact': _contactKey,
                    }[value];
                    if (key != null) _go(key);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'home', child: Text('Home')),
                    PopupMenuItem(value: 'about', child: Text('About')),
                    PopupMenuItem(value: 'rooms', child: Text('Rooms')),
                    PopupMenuItem(value: 'amenities', child: Text('Amenities')),
                    PopupMenuItem(value: 'gallery', child: Text('Gallery')),
                    PopupMenuItem(value: 'rules', child: Text('House rules')),
                    PopupMenuItem(value: 'contact', child: Text('Contact')),
                    PopupMenuDivider(),
                    PopupMenuItem(value: 'staff', child: Text('Staff portal')),
                  ],
                ),
                const SizedBox(width: 12),
              ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _hero(wide),
            _about(wide),
            _rooms(wide),
            _amenities(wide),
            _gallery(wide),
            _houseRules(),
            _contact(wide),
            _footer(wide),
          ],
        ),
      ),
    );
  }

  Widget _navText(String title, VoidCallback onTap) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(foregroundColor: _ink),
    child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
  );

  Widget _frame({
    required GlobalKey key,
    required Widget child,
    Color color = Colors.white,
    double vertical = 78,
  }) {
    return Container(
      key: key,
      color: color,
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 22, vertical: vertical),
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1160), child: child,
      ),
    );
  }

  Widget _eyebrow(String text) => Text(text.toUpperCase(),
    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12,
        letterSpacing: 2, color: _purple),
  );

  Widget _heading(String title, {double fontSize = 36}) => Text(title,
    style: TextStyle(color: _ink, fontSize: fontSize, height: 1.16,
        fontWeight: FontWeight.w800, letterSpacing: -0.8),
  );

  Widget _body(String text) => Text(text,
    style: const TextStyle(color: _muted, fontSize: 16, height: 1.65),
  );

  Widget _photo(String asset, {double height = 330}) => ClipRRect(
    borderRadius: BorderRadius.circular(22),
    child: Image.asset(asset, height: height, width: double.infinity,
        fit: BoxFit.cover),
  );

  Widget _hero(bool wide) {
    final introduction = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrow('Welcome to Carmelita Dormitory'),
        const SizedBox(height: 18),
        _heading('A place to settle in and feel at home.',
            fontSize: wide ? 51 : 38),
        const SizedBox(height: 22),
        _body('Explore our dormitory, view room photos, and find out how to reach the team for current availability and information.'),
        const SizedBox(height: 28),
        Wrap(spacing: 12, runSpacing: 10, children: [
          FilledButton.icon(
            onPressed: () => _go(_roomsKey),
            style: FilledButton.styleFrom(
              backgroundColor: _purple,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 17),
            ),
            icon: const Icon(Icons.bed_outlined),
            label: const Text('Explore rooms'),
          ),
          OutlinedButton(
            onPressed: () => _go(_contactKey),
            style: OutlinedButton.styleFrom(
              foregroundColor: _purple,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 17),
            ),
            child: const Text('Contact information'),
          ),
        ]),
      ],
    );
    final photo = Stack(
      children: [
        _photo('assets/images/exterior.jpg', height: wide ? 460 : 285),
        Positioned(
          left: 14, bottom: 14,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.home_outlined, color: _purple, size: 19),
                SizedBox(width: 8),
                Text('Carmelita Dormitory',
                    style: TextStyle(fontWeight: FontWeight.w700, color: _ink)),
              ]),
            ),
          ),
        ),
      ],
    );
    return _frame(
      key: _homeKey, color: _soft, vertical: wide ? 80 : 45,
      child: wide
          ? Row(children: [
              Expanded(child: Padding(
                padding: const EdgeInsets.only(right: 55), child: introduction,
              )),
              Expanded(child: photo),
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              introduction, const SizedBox(height: 32), photo,
            ]),
    );
  }

  Widget _about(bool wide) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _eyebrow('About us'), const SizedBox(height: 12),
        _heading('Get to know the dormitory.'), const SizedBox(height: 20),
        _body('Take a look at the property and rooms through the photos below. For the latest room availability, rates, and arrangements, please confirm the details with dormitory staff.'),
        const SizedBox(height: 22),
        TextButton.icon(
          onPressed: () => _go(_galleryKey),
          icon: const Icon(Icons.arrow_forward),
          label: const Text('See photo gallery'),
          style: TextButton.styleFrom(foregroundColor: _purple),
        ),
      ],
    );
    return _frame(
      key: _aboutKey,
      child: wide
          ? Row(children: [
              Expanded(child: _photo('assets/images/dorm_overview.jpg')),
              const SizedBox(width: 55), Expanded(child: content),
            ])
          : Column(children: [
              _photo('assets/images/dorm_overview.jpg', height: 260),
              const SizedBox(height: 30), content,
            ]),
    );
  }

  Widget _rooms(bool wide) {
    return _frame(
      key: _roomsKey, color: _soft,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _eyebrow('Rooms'), const SizedBox(height: 12),
        _heading('Take a look inside.'), const SizedBox(height: 14),
        _body('These are property images, not a live inventory. Staff can confirm room types, bed-space availability, and current prices.'),
        const SizedBox(height: 30),
        wide
            ? Row(children: [
                Expanded(child: _imageCard('assets/images/room.jpg', 'Room view')),
                const SizedBox(width: 20),
                Expanded(child: _imageCard('assets/images/bedspace_poster.jpg', 'Bed-space information')),
              ])
            : Column(children: [
                _imageCard('assets/images/room.jpg', 'Room view'),
                const SizedBox(height: 20),
                _imageCard('assets/images/bedspace_poster.jpg', 'Bed-space information'),
              ]),
      ]),
    );
  }

  Widget _imageCard(String asset, String title) => Container(
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFE9E1EC)),
    ),
    padding: const EdgeInsets.all(12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _photo(asset, height: 245),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        child: Text(title, style: const TextStyle(
          fontSize: 19, fontWeight: FontWeight.w700, color: _ink,
        )),
      ),
    ]),
  );

  Widget _amenities(bool wide) {
    final items = [
      (Icons.bed_outlined, 'Room arrangements',
          'Ask staff about available room layouts and occupancy.'),
      (Icons.wifi_outlined, 'Facilities',
          'Confirm which facilities and utilities are included.'),
      (Icons.info_outline, 'Living details',
          'Check fees, schedules, and other living arrangements before reserving.'),
    ];
    return _frame(
      key: _amenitiesKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _eyebrow('Amenities & information'), const SizedBox(height: 12),
        _heading('Know what to ask before moving in.'), const SizedBox(height: 12),
        _body('Amenities are subject to confirmation by the dormitory team. This page does not claim unverified inclusions.'),
        const SizedBox(height: 30),
        wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (final item in items) Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: _infoCard(item.$1, item.$2, item.$3),
                  ),
                )],
              )
            : Column(children: [
                for (final item in items) Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _infoCard(item.$1, item.$2, item.$3),
                ),
              ]),
      ]),
    );
  }

  Widget _infoCard(IconData icon, String title, String description) => Container(
    width: double.infinity,
    constraints: const BoxConstraints(minHeight: 178),
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: _soft, borderRadius: BorderRadius.circular(20),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: _purple, size: 30),
      const SizedBox(height: 16),
      Text(title, style: const TextStyle(
          fontSize: 18, fontWeight: FontWeight.w700, color: _ink)),
      const SizedBox(height: 9),
      Text(description, style: const TextStyle(color: _muted, height: 1.5)),
    ]),
  );

  Widget _gallery(bool wide) => _frame(
    key: _galleryKey, color: _soft,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _eyebrow('Gallery'), const SizedBox(height: 12),
      _heading('Explore the property.'), const SizedBox(height: 28),
      GridView.count(
        crossAxisCount: wide ? 3 : 1,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: wide ? 1.32 : 1.65,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _galleryPhoto('assets/images/courtyard.jpg', 'Courtyard'),
          _galleryPhoto('assets/images/room.jpg', 'Room'),
          _galleryPhoto('assets/images/dorm_overview.jpg', 'Dormitory'),
        ],
      ),
    ]),
  );

  Widget _galleryPhoto(String asset, String description) => Semantics(
    label: description,
    child: _photo(asset, height: 280),
  );

  Widget _houseRules() => _frame(
    key: _rulesKey,
    child: Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: _soft, borderRadius: BorderRadius.circular(22),
      ),
      child: Row(children: [
        const Icon(Icons.menu_book_outlined, color: _purple, size: 35),
        const SizedBox(width: 22),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _eyebrow('House rules'), const SizedBox(height: 8),
            _heading('Review the rules before your stay.', fontSize: 27),
            const SizedBox(height: 10),
            _body('Please request the current house rules, curfew policy, and reservation terms from authorized staff. The official wording has not been supplied for publication yet.'),
          ],
        )),
      ]),
    ),
  );

  Widget _contact(bool wide) => _frame(
    key: _contactKey, color: _soft,
    child: wide
        ? Row(children: [
            Expanded(child: _contactText()),
            const SizedBox(width: 50),
            Expanded(child: _photo('assets/images/reservation_poster.jpg', height: 360)),
          ])
        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _contactText(), const SizedBox(height: 24),
            _photo('assets/images/reservation_poster.jpg', height: 280),
          ]),
  );

  Widget _contactText() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _eyebrow('Contact'), const SizedBox(height: 12),
      _heading('Interested in a room?'), const SizedBox(height: 18),
      _body('For inquiries or reservations, refer to the property’s official contact information. A verified contact link and online inquiry form will be added after approval.'),
      const SizedBox(height: 14),
      const Text('No inquiry is submitted through this page yet.',
          style: TextStyle(fontWeight: FontWeight.w600, color: _ink)),
    ],
  );

  Widget _footer(bool wide) => Container(
    width: double.infinity,
    color: _ink,
    padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 24),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 24, runSpacing: 12,
      children: [
        const Text('CARMELITA DORMITORY',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800,
                letterSpacing: 1.1)),
        TextButton(
          onPressed: widget.onStaffPortal,
          child: const Text('Staff portal', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}
