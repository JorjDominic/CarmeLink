import 'package:flutter/material.dart';

import '../theme/web_theme.dart';

/// Website-only branding. Adapts to narrow app bars and the demo sidebar.
class WebBrand extends StatelessWidget {
  const WebBrand({super.key, this.compact = false, this.onTap});

  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // AppBar and demo sidebar titles can be as narrow as 211 logical pixels.
        // A single fixed-size image + cursive wordmark overflows that space.
        final available = constraints.maxWidth;
        final narrow = available.isFinite && available < 400;
        final iconOnly = available.isFinite && available < 170;
        final emblemSize = iconOnly
            ? 36.0
            : narrow
                ? 38.0
                : compact
                    ? 46.0
                    : 53.0;

        return Semantics(
          button: onTap != null,
          label: onTap == null
              ? 'Carmelita Dormitory logo'
              : 'Carmelita Dormitory, return to home',
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: emblemSize,
                    width: emblemSize,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: WebPalette.border),
                    ),
                    child: Image.asset(
                      'assets/web/brand/carmelita_logo.jpg',
                      fit: BoxFit.contain,
                      semanticLabel: 'Carmelita Dormitory logo',
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.home_outlined,
                        color: WebPalette.plum,
                      ),
                    ),
                  ),
                  if (!iconOnly) ...[
                    SizedBox(width: narrow ? 8 : 10),
                    // Flexible prevents a wide script font from demanding more
                    // space than the parent AppBar/sidebar actually provides.
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Carmelita's",
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: WebPalette.ink,
                              fontFamily: narrow ? null : 'GreatVibes',
                              fontWeight: narrow ? FontWeight.w700 : null,
                              fontSize: narrow
                                  ? 16
                                  : compact
                                      ? 29
                                      : 35,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'DORMITORY',
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: WebPalette.muted,
                              fontWeight: FontWeight.w800,
                              fontSize: narrow
                                  ? 8
                                  : compact
                                      ? 8
                                      : 9,
                              letterSpacing: narrow
                                  ? 1.1
                                  : compact
                                      ? 1.8
                                      : 2.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
