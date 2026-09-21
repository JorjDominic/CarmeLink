import 'package:flutter/material.dart';

import '../../theme/web_theme.dart';

/// The public site's editorial opening spread. Uses only existing website
/// photography, WebPalette tokens, Roboto and the registered GreatVibes font.
/// This widget intentionally has no dependency on mobile pages or services.
class SignatureHero extends StatelessWidget {
  const SignatureHero({
    super.key,
    required this.onExploreRooms,
    required this.onContact,
    required this.onDiscover,
    required this.headlineEntered,
    required this.photoEntered,
    required this.actionsEntered,
    required this.reducedMotion,
  });

  final VoidCallback onExploreRooms;
  final VoidCallback onContact;
  final VoidCallback onDiscover;
  final bool headlineEntered;
  final bool photoEntered;
  final bool actionsEntered;
  final bool reducedMotion;

  static const _courtyard = 'assets/web/photos/courtyard.jpg';
  static const _room = 'assets/web/photos/room_overview.jpg';

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final desktop = width >= 980;
          final mobile = width < 620;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _masthead(mobile),
              SizedBox(height: desktop ? 40 : 30),
              _entrance(
                visible: headlineEntered,
                duration: 570,
                offset: const Offset(0, .035),
                child: desktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(flex: 7, child: _title(width)),
                          const SizedBox(width: 56),
                          Expanded(flex: 4, child: _intro(desktop: true)),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _title(width),
                          const SizedBox(height: 23),
                          _intro(desktop: false),
                        ],
                      ),
              ),
              SizedBox(height: desktop ? 38 : 30),
              _entrance(
                visible: photoEntered,
                duration: 710,
                offset: const Offset(0, .018),
                child: desktop
                    ? _desktopPhotoSpread()
                    : _compactPhotoSpread(mobile),
              ),
              const SizedBox(height: 22),
              _footer(mobile),
            ],
          );
        },
      );

  Widget _entrance({
    required Widget child,
    required bool visible,
    required int duration,
    required Offset offset,
  }) {
    final show = visible || reducedMotion;
    final time =
        reducedMotion ? Duration.zero : Duration(milliseconds: duration);
    return AnimatedOpacity(
      opacity: show ? 1 : 0,
      duration: time,
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: show ? Offset.zero : offset,
        duration: time,
        curve: Curves.easeOutCubic,
        child: child,
      ),
    );
  }

  Widget _masthead(bool mobile) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: const [
              Text(
                'CARMELITA\'S  /  THE RESIDENCE',
                style: TextStyle(
                  color: WebPalette.plum,
                  fontSize: 10,
                  letterSpacing: 2.0,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'BALIWAG, BULACAN',
                style: TextStyle(
                  color: WebPalette.muted,
                  fontSize: 10,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: mobile ? 15 : 20),
          const Divider(height: 1, thickness: 1, color: WebPalette.border),
        ],
      );

  Widget _title(double width) {
    final desktop = width >= 980;
    final size = desktop
        ? 84.0
        : width >= 620
            ? 68.0
            : width < 360
                ? 43.0
                : 49.0;
    final scriptSize = desktop
        ? 99.0
        : width >= 620
            ? 89.0
            : 71.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'A place to',
          maxLines: 1,
          style: TextStyle(
            color: WebPalette.ink,
            fontSize: size,
            height: 1.02,
            fontWeight: FontWeight.w900,
            letterSpacing: desktop ? -4.3 : -2.1,
          ),
        ),
        Semantics(
          label: 'feel at home.',
          child: ExcludeSemantics(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'feel at home.',
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: 'GreatVibes',
                    fontSize: scriptSize,
                    height: 1.18,
                    color: WebPalette.plum,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _intro({required bool desktop}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'YOUR NEXT CHAPTER, UP CLOSE.',
            style: TextStyle(
              color: WebPalette.plumLight,
              fontSize: 10,
              letterSpacing: 2.1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Get to know the spaces at Carmelita\'s Dormitory through real photographs. Explore the rooms, then ask us about availability.',
            style:
                TextStyle(color: WebPalette.muted, fontSize: 15.5, height: 1.6),
          ),
          SizedBox(height: desktop ? 24 : 19),
          _entrance(
            visible: actionsEntered,
            duration: 500,
            offset: const Offset(0, .06),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: onExploreRooms,
                  icon: const Icon(Icons.arrow_outward, size: 17),
                  label: const Text('Explore the rooms'),
                  style: FilledButton.styleFrom(
                    backgroundColor: WebPalette.plum,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 19, vertical: 18),
                  ),
                ),
                OutlinedButton(
                  onPressed: onContact,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: WebPalette.plum,
                    side: const BorderSide(color: WebPalette.border),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 19, vertical: 18),
                  ),
                  child: const Text('Get in touch'),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _photograph(String path, String description) => Image.asset(
        path,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        semanticLabel: description,
        errorBuilder: (context, error, stack) => Container(
          color: WebPalette.sand,
          alignment: Alignment.center,
          child: const Text('Photo unavailable',
              style: TextStyle(color: WebPalette.muted)),
        ),
      );

  Widget _desktopPhotoSpread() => SizedBox(
        height: 465,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 8,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(100),
                      bottomRight: Radius.circular(12),
                    ),
                    child: _photograph(
                      _courtyard,
                      'Actual Carmelita Dormitory courtyard photograph',
                    ),
                  ),
                  Positioned(
                    bottom: 18,
                    left: 22,
                    child: Container(
                      color: WebPalette.background,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 11),
                      child: const Text(
                        '01  /  THE COURTYARD',
                        style: TextStyle(
                          color: WebPalette.ink,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.6,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 5,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(12),
                      ),
                      child: _photograph(
                        _room,
                        'Actual Carmelita Dormitory bedroom photograph',
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    flex: 4,
                    child: Container(
                      color: WebPalette.plum,
                      padding: const EdgeInsets.all(23),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(Icons.north_east, color: Colors.white, size: 22),
                          Text(
                            'A closer look\nat life inside.',
                            style: TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w800,
                              height: 1.12,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'ROOMS  /  02',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              letterSpacing: 1.8,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _compactPhotoSpread(bool mobile) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: mobile ? 315 : 415,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(68),
                bottomRight: Radius.circular(10),
              ),
              child: _photograph(
                _courtyard,
                'Actual Carmelita Dormitory courtyard photograph',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: mobile ? 84 : 112,
                height: mobile ? 84 : 112,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                  ),
                  child: _photograph(
                    _room,
                    'Actual Carmelita Dormitory bedroom photograph',
                  ),
                ),
              ),
              const SizedBox(width: 15),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('01  /  THE RESIDENCE',
                        style: TextStyle(
                          color: WebPalette.plum,
                          fontSize: 10,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w900,
                        )),
                    SizedBox(height: 7),
                    Text('See the place for yourself.',
                        style: TextStyle(
                          color: WebPalette.ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        )),
                  ],
                ),
              ),
            ],
          ),
        ],
      );

  Widget _footer(bool mobile) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 1, thickness: 1, color: WebPalette.border),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 4,
            children: [
              const Text(
                'REAL PHOTOS  /  REAL SPACES',
                style: TextStyle(
                  color: WebPalette.muted,
                  fontSize: 10,
                  letterSpacing: 1.3,
                  fontWeight: FontWeight.w800,
                ),
              ),
              TextButton.icon(
                onPressed: onDiscover,
                icon: const Icon(Icons.south_east, size: 16),
                label: const Text('Discover the residence'),
                style: TextButton.styleFrom(
                  foregroundColor: WebPalette.plum,
                  padding: EdgeInsets.symmetric(
                    horizontal: mobile ? 0 : 12,
                    vertical: 9,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
}
