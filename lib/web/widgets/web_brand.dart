import 'package:flutter/material.dart';

import '../theme/web_theme.dart';

/// Shared logo/wordmark for the public site and staff login.
class WebBrand extends StatelessWidget {
  const WebBrand({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Image.asset(
            'assets/branding/carmelita_logo.jpg',
            width: compact ? 34 : 42,
            height: compact ? 34 : 42,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          compact ? 'CarmeLink staff' : 'CARMELITA',
          style: TextStyle(
            color: WebPalette.ink,
            fontSize: compact ? 17 : 19,
            fontWeight: FontWeight.w800,
            letterSpacing: compact ? 0 : 1.2,
          ),
        ),
      ],
    );
  }
}
