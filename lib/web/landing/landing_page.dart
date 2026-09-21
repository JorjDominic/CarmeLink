import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/web_theme.dart';
import '../widgets/reveal_on_scroll.dart';
import '../widgets/web_brand.dart';
import '../widgets/web_external_links.dart';
import 'landing_content.dart';
import 'widgets/editorial_photo_gallery.dart';
import 'widgets/photo_lightbox.dart';
import 'widgets/property_photo_tile.dart';

/// Public website only. Staff authentication and mobile screens stay untouched.
/// Room prices, availability and booking confirmations are intentionally absent.
class LandingPage extends StatefulWidget {
  const LandingPage({super.key, required this.onStaffPortal});

  final VoidCallback onStaffPortal;

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _home = GlobalKey();
  final GlobalKey _about = GlobalKey();
  final GlobalKey _rooms = GlobalKey();
  final GlobalKey _spaces = GlobalKey();
  final GlobalKey _gallery = GlobalKey();
  final GlobalKey _faq = GlobalKey();
  final GlobalKey _contact = GlobalKey();
  bool _entered = false;
  bool _ctaEntered = false;
  bool _photoEntered = false;
  bool _scrolled = false;
  PropertyCategory? _filter;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _entered = true);
      Future<void>.delayed(const Duration(milliseconds: 140), () {
        if (mounted) setState(() => _photoEntered = true);
      });
      Future<void>.delayed(const Duration(milliseconds: 230), () {
        if (mounted) setState(() => _ctaEntered = true);
      });
    });
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final scrolled = _scroll.offset > 24;
    if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _go(GlobalKey key) {
    final target = key.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 480),
      curve: Curves.easeInOutCubic,
      alignment: 0.02,
    );
  }

  void _showPhoto(PropertyPhoto photo, {List<PropertyPhoto>? selection}) {
    final photos = selection ?? LandingContent.photos;
    final index = photos.indexOf(photo);
    if (index < 0) return;
    showDialog<void>(
      context: context,
      builder: (_) => PhotoLightbox(photos: photos, initialIndex: index),
    );
  }

  Widget _nav(String title, GlobalKey key) => TextButton(
        onPressed: () => _go(key),
        style: TextButton.styleFrom(
          foregroundColor: WebPalette.ink,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      );

  Widget _primary(String label, VoidCallback action,
      {IconData icon = Icons.arrow_outward, bool inverse = false}) {
    return FilledButton.icon(
      onPressed: action,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      style: FilledButton.styleFrom(
        backgroundColor: inverse ? WebPalette.background : WebPalette.plum,
        foregroundColor: inverse ? WebPalette.plum : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 19),
      ),
    );
  }

  Widget _outline(String label, VoidCallback action,
          {bool inverse = false, IconData icon = Icons.arrow_outward}) =>
      OutlinedButton.icon(
        onPressed: action,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        style: OutlinedButton.styleFrom(
          foregroundColor: inverse ? Colors.white : WebPalette.plum,
          side: BorderSide(
            color: inverse ? const Color(0x99FFFFFF) : WebPalette.border,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 19),
        ),
      );

  Widget _eyebrow(String label, {Color color = WebPalette.plumLight}) => Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.7,
          height: 1.4,
        ),
      );

  Widget _headline(String text,
          {double size = 52, Color color = WebPalette.ink}) =>
      Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w900,
          letterSpacing: size > 50 ? -2.8 : -1.4,
          height: 1.08,
        ),
      );

  Widget _body(String text, {Color color = WebPalette.muted, double size = 16}) =>
      Text(text,
          style: TextStyle(color: color, fontSize: size, height: 1.65));

  Widget _section(GlobalKey key, Widget child,
      {Color color = WebPalette.background, double vertical = 92}) {
    return Container(
      key: key,
      width: double.infinity,
      color: color,
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.sizeOf(context).width < 600 ? 18 : 24,
        vertical: MediaQuery.sizeOf(context).width < 600
            ? vertical * .76
            : vertical,
      ),
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1220),
        child: child,
      ),
    );
  }

  Widget _image(String asset,
      {double? height, BoxFit fit = BoxFit.cover, String label = 'Dormitory photo'}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(19),
      child: Image.asset(
        asset,
        width: double.infinity,
        height: height,
        fit: fit,
        alignment: Alignment.topCenter,
        semanticLabel: label,
        errorBuilder: (_, __, ___) => Container(
          width: double.infinity,
          height: height ?? 240,
          color: WebPalette.sand,
          alignment: Alignment.center,
          child: const Text('Photo unavailable'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 1060;
    final wide = width >= 800;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      backgroundColor: WebPalette.background,
      appBar: AppBar(
        toolbarHeight: 82,
        titleSpacing: desktop ? 40 : 14,
        backgroundColor: _scrolled ? WebPalette.surface : WebPalette.background,
        elevation: _scrolled ? 2 : 0,
        shadowColor: WebPalette.ink.withValues(alpha: .12),
        title: WebBrand(compact: !desktop, onTap: () => _go(_home)),
        actions: desktop
            ? [
                _nav('Discover', _about),
                _nav('Rooms', _rooms),
                _nav('The spaces', _spaces),
                _nav('Gallery', _gallery),
                _nav('Good to know', _faq),
                const SizedBox(width: 13),
                Padding(
                  padding: const EdgeInsets.only(right: 40),
                  child: _primary('Inquire', () => _go(_contact)),
                ),
              ]
            : [
                if (width >= 470)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: TextButton(
                      onPressed: () => _go(_contact),
                      child: const Text('Inquire'),
                    ),
                  ),
                PopupMenuButton<String>(
                  tooltip: 'Open website navigation',
                  icon: const Icon(Icons.menu_rounded, color: WebPalette.ink),
                  onSelected: (value) {
                    final sections = <String, GlobalKey>{
                      'home': _home,
                      'discover': _about,
                      'rooms': _rooms,
                      'spaces': _spaces,
                      'gallery': _gallery,
                      'faq': _faq,
                      'contact': _contact,
                    };
                    final key = sections[value];
                    if (key != null) _go(key);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'home', child: Text('Home')),
                    PopupMenuItem(value: 'discover', child: Text('Discover')),
                    PopupMenuItem(value: 'rooms', child: Text('Rooms')),
                    PopupMenuItem(value: 'spaces', child: Text('The spaces')),
                    PopupMenuItem(value: 'gallery', child: Text('Gallery')),
                    PopupMenuItem(value: 'faq', child: Text('Good to know')),
                    PopupMenuItem(value: 'contact', child: Text('Inquire')),
                  ],
                ),
                const SizedBox(width: 9),
              ],
      ),
      body: Scrollbar(
        controller: _scroll,
        child: SingleChildScrollView(
          controller: _scroll,
          child: Column(
            children: [
              _hero(desktop, reducedMotion),
              RevealOnScroll(child: _aboutSection(wide)),
              _highlights(wide),
              RevealOnScroll(child: _roomsSection(wide)),
              RevealOnScroll(child: _spacesSection(wide)),
              RevealOnScroll(child: _gallerySection(wide)),
              RevealOnScroll(child: _faqSection(wide)),
              RevealOnScroll(child: _contactSection(wide)),
              _footer(wide),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero(bool desktop, bool reducedMotion) {
    final introduction = AnimatedOpacity(
      opacity: _entered || reducedMotion ? 1 : 0,
      duration: reducedMotion ? Duration.zero : const Duration(milliseconds: 650),
      child: AnimatedSlide(
        offset: _entered || reducedMotion ? Offset.zero : const Offset(0, 0.055),
        duration: reducedMotion ? Duration.zero : const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _eyebrow("Carmelita's Dormitory  /  Baliwag, Bulacan"),
            const SizedBox(height: 28),
            Semantics(
              label: 'A place to feel at home.',
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _headline('A place to', size: desktop ? 67 : 42),
                    Text(
                      'feel at home.',
                      style: TextStyle(
                        fontFamily: 'GreatVibes',
                        color: WebPalette.plum,
                        fontSize: desktop
                            ? 86
                            : MediaQuery.sizeOf(context).width < 390 ? 50 : 60,
                        height: 1.12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 23),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 470),
              child: _body(
                'A closer look at your possible home away from home. '
                'Explore the actual property, discover the spaces, and ask us about a room.',
                size: 17,
              ),
            ),
            const SizedBox(height: 32),
            AnimatedOpacity(
              opacity: _ctaEntered || reducedMotion ? 1 : 0,
              duration: reducedMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 580),
              curve: Curves.easeOutCubic,
              child: AnimatedSlide(
                offset: _ctaEntered || reducedMotion
                    ? Offset.zero
                    : const Offset(0, 0.09),
                duration: reducedMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 580),
                curve: Curves.easeOutCubic,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _primary('Explore the rooms', () => _go(_rooms)),
                        _outline('Get in touch', () => _go(_contact)),
                      ],
                    ),
                    const SizedBox(height: 34),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          height: 2,
                          width: 31,
                          color: WebPalette.gold,
                        ),
                        const SizedBox(width: 13),
                        const Flexible(
                          child: Text(
                            'REAL PHOTOS. REAL SPACES. YOUR NEXT CHAPTER.',
                            style: TextStyle(
                              color: WebPalette.muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // Composition is deliberately offset: the inset room photo has its own
    // white frame instead of accidentally blending into the courtyard photo.
    final photography = LayoutBuilder(
      builder: (context, constraints) {
        final height = desktop ? 525.0 : 380.0;
        final insetWidth = constraints.maxWidth * (desktop ? 0.38 : 0.42);
        return AnimatedOpacity(
          opacity: _photoEntered || reducedMotion ? 1 : 0,
          duration: reducedMotion
              ? Duration.zero
              : const Duration(milliseconds: 850),
          curve: Curves.easeOutCubic,
          child: AnimatedScale(
            scale: _photoEntered || reducedMotion ? 1 : 0.975,
            duration: reducedMotion
                ? Duration.zero
                : const Duration(milliseconds: 850),
            curve: Curves.easeOutCubic,
            child: SizedBox(
              height: height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: desktop ? 38 : 22,
                    top: 0,
                    bottom: desktop ? 38 : 28,
                    child: _image(
                      'assets/web/photos/courtyard.jpg',
                      label: 'The actual Carmelita Dormitory courtyard',
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    width: insetWidth,
                    height: desktop ? 215 : 155,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: WebPalette.background,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: WebPalette.ink.withValues(alpha: .15),
                            blurRadius: 24,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.asset(
                          'assets/web/photos/bunk_corner.jpg',
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          semanticLabel: 'An actual dormitory bunk bed',
                          errorBuilder: (_, __, ___) => const Center(
                            child: Text('Photo unavailable'),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    top: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: WebPalette.background,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Text(
                        'CARMELITA  /  01',
                        style: TextStyle(
                          color: WebPalette.ink,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    return _section(
      _home,
      desktop
          ? Row(
              children: [
                Expanded(flex: 11, child: Padding(
                  padding: const EdgeInsets.only(right: 62), child: introduction,
                )),
                Expanded(flex: 10, child: photography),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                introduction,
                const SizedBox(height: 40),
                photography,
              ],
            ),
      color: WebPalette.cream,
      vertical: desktop ? 67 : 43,
    );
  }

  Widget _highlights(bool wide) => Container(
        color: WebPalette.plum,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 19),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1220),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 24,
              runSpacing: 14,
              children: const [
                _Highlight(Icons.photo_library_outlined, 'REAL PROPERTY PHOTOS'),
                _Highlight(Icons.chat_bubble_outline, 'ASK ABOUT ROOM AVAILABILITY'),
                _Highlight(Icons.place_outlined, 'BALIWAG, BULACAN'),
              ],
            ),
          ),
        ),
      );

  Widget _aboutSection(bool wide) {
    final image = Stack(
      children: [
        _image(
          'assets/web/photos/room_overview.jpg',
          height: wide ? 460 : 310,
          label: 'An actual dormitory bedroom interior',
        ),
        Positioned(
          bottom: 18,
          right: 18,
          child: Material(
            color: WebPalette.background,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => _showPhoto(LandingContent.photos[1]),
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.open_in_full, size: 16, color: WebPalette.plum),
                  SizedBox(width: 8),
                  Text('View photo', style: TextStyle(
                    fontWeight: FontWeight.w700, color: WebPalette.ink,
                  )),
                ]),
              ),
            ),
          ),
        ),
      ],
    );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _eyebrow('01  /  The residence'),
        const SizedBox(height: 17),
        _headline('More than just\nfour walls.', size: wide ? 52 : 39),
        const SizedBox(height: 19),
        _body(
          "Get to know Carmelita's Dormitory through photographs of its rooms "
          'and shared spaces. Explore the property first, then contact the team '
          'for up-to-date information before making plans.',
        ),
        const SizedBox(height: 24),
        TextButton.icon(
          onPressed: () => _go(_gallery),
          icon: const Icon(Icons.arrow_outward, size: 18),
          label: const Text('See the photo gallery'),
          style: TextButton.styleFrom(foregroundColor: WebPalette.plum),
        ),
      ],
    );
    return _section(
      _about,
      wide
          ? Row(children: [
              Expanded(child: image),
              const SizedBox(width: 68),
              Expanded(child: text),
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              image,
              const SizedBox(height: 33),
              text,
            ]),
    );
  }

  Widget _roomCard(PropertyPhoto photo, String heading, String copy) => Container(
        decoration: BoxDecoration(
          color: WebPalette.background,
          border: Border.all(color: WebPalette.border),
          borderRadius: BorderRadius.circular(22),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PropertyPhotoTile(
              photo: photo,
              height: 310,
              onOpen: () => _showPhoto(photo),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 23, 12, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _headline(heading, size: 27),
                  const SizedBox(height: 10),
                  _body(copy, size: 15),
                  const SizedBox(height: 13),
                  TextButton.icon(
                    onPressed: () => _go(_contact),
                    icon: const Icon(Icons.arrow_outward, size: 17),
                    label: const Text('Ask about this space'),
                    style: TextButton.styleFrom(foregroundColor: WebPalette.plum),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _roomsSection(bool wide) => _section(
        _rooms,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _eyebrow('02  /  Inside Carmelita'),
            const SizedBox(height: 16),
            _headline('Find your kind of space.', size: wide ? 55 : 38),
            const SizedBox(height: 15),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 730),
              child: _body(
                'Browse actual room photographs. Contact staff to confirm which '
                'rooms or bed spaces are currently available. Prices are provided on inquiry.',
              ),
            ),
            const SizedBox(height: 36),
            if (wide)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _roomCard(
                  LandingContent.photos[1],
                  'Inside the rooms',
                  'A closer view of the room layout and sleeping spaces.',
                )),
                const SizedBox(width: 22),
                Expanded(child: _roomCard(
                  LandingContent.photos[2],
                  'Study and settle in',
                  'Take a look at the desk and window in this room photograph.',
                )),
              ])
            else ...[
              _roomCard(
                LandingContent.photos[1],
                'Inside the rooms',
                'A closer view of the room layout and sleeping spaces.',
              ),
              const SizedBox(height: 20),
              _roomCard(
                LandingContent.photos[2],
                'Study and settle in',
                'Take a look at the desk and window in this room photograph.',
              ),
            ],
          ],
        ),
        color: WebPalette.cream,
      );

  Widget _spacesSection(bool wide) => _section(
        _spaces,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _eyebrow('03  /  Around the property'),
            const SizedBox(height: 16),
            _headline('Little details. Everyday spaces.', size: wide ? 53 : 37),
            const SizedBox(height: 16),
            _body('Discover a shared outdoor space through real photographs of the residence.'),
            const SizedBox(height: 33),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 12,
                    child: PropertyPhotoTile(
                      photo: LandingContent.photos[3],
                      height: 420,
                      onOpen: () => _showPhoto(LandingContent.photos[3]),
                    ),
                  ),
                  const SizedBox(width: 54),
                  Expanded(flex: 8, child: _spacesCopy()),
                ],
              )
            else ...[
              PropertyPhotoTile(
                photo: LandingContent.photos[3],
                height: 285,
                onOpen: () => _showPhoto(LandingContent.photos[3]),
              ),
              const SizedBox(height: 25),
              _spacesCopy(),
            ],
          ],
        ),
      );

  Widget _spacesCopy() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _eyebrow('The outdoor space'),
          const SizedBox(height: 15),
          _headline('Room to unwind.', size: 35),
          const SizedBox(height: 18),
          _body(
            'Take a look at the outdoor seating area, then browse the full '
            'gallery for room layouts and more perspectives of the property.',
          ),
          const SizedBox(height: 23),
          TextButton.icon(
            onPressed: () => _go(_gallery),
            icon: const Icon(Icons.arrow_outward, size: 18),
            label: const Text('Explore the full gallery'),
            style: TextButton.styleFrom(foregroundColor: WebPalette.plum),
          ),
        ],
      );

  Widget _filterButton(String label, PropertyCategory? category) {
    final selected = category == _filter;
    return OutlinedButton(
      onPressed: () => setState(() => _filter = category),
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? Colors.white : WebPalette.plum,
        backgroundColor: selected ? WebPalette.plum : Colors.transparent,
        side: BorderSide(color: selected ? WebPalette.plum : WebPalette.border),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      ),
      child: Text(label),
    );
  }

  Widget _gallerySection(bool wide) {
    final visible = LandingContent.photos
        .where((photo) => _filter == null || photo.category == _filter)
        .toList(growable: false);
    return _section(
      _gallery,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _eyebrow('04  /  A closer look'),
          const SizedBox(height: 16),
          _headline('The story, in pictures.', size: wide ? 56 : 38),
          const SizedBox(height: 16),
          _body(
            'Real images supplied by Carmelita Dormitory. Choose a category, '
            'browse the photographs, and select a featured image to enlarge it.',
          ),
          const SizedBox(height: 27),
          Wrap(spacing: 9, runSpacing: 9, children: [
            _filterButton('All photos', null),
            _filterButton('Rooms', PropertyCategory.rooms),
            _filterButton('Property', PropertyCategory.property),
            _filterButton('Shared areas', PropertyCategory.shared),
          ]),
          const SizedBox(height: 25),
          EditorialPhotoGallery(
            key: ValueKey(_filter),
            photos: visible,
            onOpen: (photo) => _showPhoto(photo, selection: visible),
          ),
        ],
      ),
      color: WebPalette.cream,
    );
  }

  Widget _faqSection(bool wide) => _section(
        _faq,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _eyebrow('05  /  For students and families'),
            const SizedBox(height: 16),
            _headline('Good to know, before you go.', size: wide ? 54 : 37),
            const SizedBox(height: 18),
            _body('Important details can change. These answers explain how to verify them with staff.'),
            const SizedBox(height: 28),
            _faqTile(
              'How do I check room availability?',
              'Use the official Facebook page to ask staff which rooms or bed spaces are currently available.',
            ),
            _faqTile(
              'Can I ask about room rates and inclusions?',
              'Yes. Send the team an inquiry for current prices, inclusions, and payment requirements. Rates are not displayed on this website.',
            ),
            _faqTile(
              'How do I arrange a dormitory viewing?',
              'Contact staff through the official Facebook page and request a viewing. Wait for their confirmation before visiting.',
            ),
            _faqTile(
              'Where can I ask about curfew and house rules?',
              'Request the current official rules directly from staff before reserving. The website does not publish unverified policy details.',
            ),
            _faqTile(
              'How do I find Carmelita Dormitory?',
              'Use the Google Maps directions link below. Please confirm the location pin with staff before traveling.',
            ),
          ],
        ),
      );

  Widget _faqTile(String question, String answer) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: WebPalette.border),
            borderRadius: BorderRadius.circular(13),
          ),
          child: ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            tilePadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 5),
            title: Text(question,
                style: const TextStyle(
                  color: WebPalette.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                )),
            childrenPadding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
            children: [Align(alignment: Alignment.centerLeft, child: _body(answer))],
          ),
        ),
      );

  Widget _contactSection(bool wide) => _section(
        _contact,
        wide
            ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Expanded(flex: 11, child: _contactText(wide)),
                const SizedBox(width: 50),
                Expanded(flex: 9, child: _locationCard()),
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _contactText(wide),
                const SizedBox(height: 35),
                _locationCard(),
              ]),
        color: WebPalette.plum,
        vertical: 85,
      );

  Widget _contactText(bool wide) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _eyebrow('06  /  Your next step', color: WebPalette.gold),
          const SizedBox(height: 20),
          _headline('Your next chapter\nstarts with a hello.',
              size: wide ? 52 : 37, color: Colors.white),
          const SizedBox(height: 22),
          _body(
            "Ask about room availability, living arrangements, or a possible visit "
            "through Carmelita's official Facebook page. Staff will confirm the details.",
            color: WebPalette.cream,
          ),
          const SizedBox(height: 29),
          Wrap(spacing: 11, runSpacing: 11, children: [
            _primary(
              'Visit our Facebook page',
              () => WebExternalLinks.open(context, LandingContent.facebookUrl),
              icon: Icons.facebook,
              inverse: true,
            ),
            _outline(
              'Get directions',
              () => WebExternalLinks.open(context, LandingContent.mapsUrl),
              icon: Icons.map_outlined,
              inverse: true,
            ),
          ]),
          const SizedBox(height: 19),
          const Text(
            'No online booking or inquiry form is active yet. Requests are handled by staff.',
            style: TextStyle(color: WebPalette.sand, fontSize: 12, height: 1.5),
          ),
        ],
      );

  Widget _locationCard() => Container(
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: WebPalette.background,
          borderRadius: BorderRadius.circular(23),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: SizedBox(
                height: 230,
                child: _image(
                  'assets/web/photos/property_exterior.jpg',
                  label: 'Exterior of Carmelita Dormitory',
                ),
              ),
            ),
            const SizedBox(height: 21),
            _eyebrow('Visit the residence'),
            const SizedBox(height: 11),
            _headline("Carmelita's Dormitory", size: 25),
            const SizedBox(height: 9),
            _body('Dr. Luis Reyes St., Brgy. Concepcion, Baliwag, Bulacan', size: 14),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => WebExternalLinks.open(context, LandingContent.mapsUrl),
              icon: const Icon(Icons.navigation_outlined, size: 18),
              label: const Text('Open Google Maps'),
              style: TextButton.styleFrom(foregroundColor: WebPalette.plum),
            ),
            const Text(
              'Confirm the exact map pin with staff before visiting.',
              style: TextStyle(color: WebPalette.muted, fontSize: 12),
            ),
          ],
        ),
      );

  Widget _footer(bool wide) => Container(
        width: double.infinity,
        color: WebPalette.background,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1220),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 25,
            runSpacing: 20,
            children: [
              WebBrand(compact: true, onTap: () => _go(_home)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Property information subject to staff confirmation.',
                      style: TextStyle(color: WebPalette.muted, fontSize: 12)),
                  const SizedBox(height: 7),
                  const Text('Carmelita Dormitory · Baliwag, Bulacan',
                      style: TextStyle(color: WebPalette.muted, fontSize: 12)),
                ],
              ),
              Wrap(spacing: 6, children: [
                TextButton(
                  onPressed: () => WebExternalLinks.open(context, LandingContent.facebookUrl),
                  child: const Text('Facebook'),
                ),
                TextButton(
                  onPressed: () => WebExternalLinks.open(context, LandingContent.mapsUrl),
                  child: const Text('Maps'),
                ),
                TextButton(
                  onPressed: widget.onStaffPortal,
                  style: TextButton.styleFrom(foregroundColor: WebPalette.muted),
                  child: const Text('Staff sign in'),
                ),
              ]),
            ],
          ),
        ),
      );
}

class _Highlight extends StatelessWidget {
  const _Highlight(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: WebPalette.gold, size: 18),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              )),
        ],
      );
}
