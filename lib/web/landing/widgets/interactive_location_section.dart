import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/web_theme.dart';
import '../../widgets/web_external_links.dart';
import '../location_map_config.dart';
import 'map_frame.dart';

/// Public map with a marker at the Google Maps place shared by the team.
/// The building entrance is still subject to confirmation with staff.
class InteractiveLocationSection extends StatefulWidget {
  const InteractiveLocationSection({super.key});

  @override
  State<InteractiveLocationSection> createState() =>
      _InteractiveLocationSectionState();
}

class _InteractiveLocationSectionState
    extends State<InteractiveLocationSection> {
  void _expandMap() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final size = MediaQuery.sizeOf(dialogContext);
        return Dialog(
          insetPadding: const EdgeInsets.all(12),
          clipBehavior: Clip.antiAlias,
          backgroundColor: WebPalette.background,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: SizedBox(
              height: math.max(240.0, size.height * .86),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(15, 10, 8, 8),
                    child: Row(children: [
                      const Expanded(
                        child: const Text('Explore Carmelita’s location',
                            maxLines: 2,
                            style: TextStyle(
                                color: WebPalette.ink,
                                fontSize: 17,
                                fontWeight: FontWeight.w800)),
                      ),
                      IconButton(
                        tooltip: 'Close expanded map',
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ]),
                  ),
                  Expanded(
                    child: MapFrame(url: LocationMapConfig.embedUrl),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      LocationMapConfig.hasVerifiedPin
                          ? 'Confirm the entrance location with staff before visiting.'
                          : 'Neighborhood view only — the dormitory entrance pin '
                              'still needs confirmation from staff.',
                      style: const TextStyle(
                          color: WebPalette.muted, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900;
    final map = _mapPanel();
    final details = _informationPanel(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('06  /  FIND US',
            style: TextStyle(
                color: WebPalette.plumLight,
                fontSize: 11,
                letterSpacing: 2.7,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 15),
        Text('A closer look at where we are.',
            style: TextStyle(
                color: WebPalette.ink,
                fontSize: wide ? 52 : 35,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.2,
                height: 1.1)),
        const SizedBox(height: 17),
        const Text(
          'Explore the area here, or open Google Maps when you are ready '
          'to plan a visit.',
          style: TextStyle(fontSize: 16, color: WebPalette.muted, height: 1.6),
        ),
        const SizedBox(height: 28),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 12, child: map),
              const SizedBox(width: 26),
              Expanded(flex: 7, child: details),
            ],
          )
        else ...[
          map,
          const SizedBox(height: 18),
          details,
        ],
      ],
    );
  }

  Widget _mapPanel() => Container(
        decoration: BoxDecoration(
          color: WebPalette.sand,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: WebPalette.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 11, 10, 9),
              child: Row(children: [
                const Icon(Icons.map_outlined,
                    color: WebPalette.plum, size: 20),
                const SizedBox(width: 7),
                const Expanded(
                    child: const Text('Carmelita • Baliwag',
                        maxLines: 2,
                        style: TextStyle(
                            color: WebPalette.ink,
                            fontWeight: FontWeight.w800))),
                TextButton.icon(
                  onPressed: _expandMap,
                  icon: const Icon(Icons.open_in_full, size: 17),
                  label: const Text('Expand map'),
                  style: TextButton.styleFrom(
                      foregroundColor: WebPalette.plum,
                      padding: const EdgeInsets.symmetric(horizontal: 6)),
                ),
              ]),
            ),
            // The iframe loads automatically as this section approaches the
            // viewport. The HTML iframe itself uses loading="lazy" so we do
            // not download map tiles on the initial hero view.
            SizedBox(
              height: MediaQuery.sizeOf(context).width < 600 ? 280 : 405,
              child: MapFrame(url: LocationMapConfig.embedUrl),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 9, 14, 13),
              child: Text(
                'Drag to move the map; use its controls to zoom. '
                'Scroll the page outside this map.',
                style: TextStyle(color: WebPalette.muted, fontSize: 12),
              ),
            ),
          ],
        ),
      );

  Widget _informationPanel(BuildContext context) => Container(
        padding: const EdgeInsets.all(23),
        decoration: BoxDecoration(
          color: WebPalette.surface,
          border: Border.all(color: WebPalette.border),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.place_outlined, color: WebPalette.plum, size: 29),
            const SizedBox(height: 19),
            const Text('Carmelita’s Dormitory',
                style: TextStyle(
                    color: WebPalette.ink,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    height: 1.16)),
            const SizedBox(height: 13),
            const Text(LocationMapConfig.propertyAddress,
                style: TextStyle(
                    color: WebPalette.muted, fontSize: 14, height: 1.6)),
            const SizedBox(height: 16),
            Text(
              LocationMapConfig.hasVerifiedPin
                  ? 'Google Maps place pin shared for the property. Confirm the '
                      'entrance with staff before traveling.'
                  : 'Map shows the Concepcion neighborhood, not an exact '
                      'dormitory marker. Confirm the entrance pin with staff '
                      'before your visit.',
              style: const TextStyle(
                  color: WebPalette.muted, fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => WebExternalLinks.open(
                    context, LocationMapConfig.directionsUri.toString()),
                icon: const Icon(Icons.navigation_outlined, size: 18),
                label: Text(MediaQuery.sizeOf(context).width < 380 ||
                        (MediaQuery.sizeOf(context).width >= 900 &&
                            MediaQuery.sizeOf(context).width < 1160)
                    ? 'Get directions'
                    : 'Directions in Google Maps'),
              ),
            ),
            const SizedBox(height: 9),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => WebExternalLinks.open(
                    context, LocationMapConfig.dormToUniversityUri.toString()),
                icon: const Icon(Icons.route_outlined, size: 18),
                label: const Text('Dormitory to NU route'),
              ),
            ),
          ],
        ),
      );
}
