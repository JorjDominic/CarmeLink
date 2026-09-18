import 'package:flutter/material.dart';

import '../theme/web_theme.dart';

/// Compact, legible website wordmark. The small emblem is intentionally omitted.
/// Existing mobile branding and source image assets are unchanged.
class WebBrand extends StatelessWidget {
  const WebBrand({super.key, this.compact = false, this.onTap});

  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Carmelita's",
              style: TextStyle(
                color: WebPalette.ink,
                fontFamily: 'GreatVibes',
                fontSize: compact ? 32 : 38,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'D O R M I T O R Y',
              style: TextStyle(
                color: WebPalette.muted,
                fontWeight: FontWeight.w700,
                fontSize: compact ? 7 : 8,
                letterSpacing: compact ? 0.6 : 0.9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
