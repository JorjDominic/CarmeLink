import 'package:flutter/material.dart';

import '../theme/web_theme.dart';

/// Website-only text branding. Keeps the existing wordmark without a logo.
class WebBrand extends StatelessWidget {
  const WebBrand({super.key, this.compact = false, this.onTap});

  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The branding is also used in narrow app bars and sidebar slots.
        final available = constraints.maxWidth;
        final narrow = available.isFinite && available < 400;
        final extraNarrow = available.isFinite && available < 170;

        final wordmarkSize = extraNarrow
            ? 23.0
            : narrow
                ? 28.0
                : compact
                    ? 29.0
                    : 35.0;

        final subtitleSize = extraNarrow
            ? 7.0
            : narrow || compact
                ? 8.0
                : 9.0;
        final subtitleSpacing = extraNarrow
            ? 1.1
            : narrow
                ? 1.1
                : compact
                    ? 1.8
                    : 2.3;

        return Semantics(
          button: onTap != null,
          label: onTap == null
              ? "Carmelita's Dormitory"
              : "Carmelita's Dormitory, return to home",
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 3),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Carmelita's",
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: WebPalette.ink,
                      fontFamily: 'GreatVibes',
                      fontSize: wordmarkSize,
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
                      fontSize: subtitleSize,
                      letterSpacing: subtitleSpacing,
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
}
