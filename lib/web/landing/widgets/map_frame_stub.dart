import 'package:flutter/material.dart';

import '../../theme/web_theme.dart';

/// Used in Flutter's VM widget tests and in non-HTML build targets.
Widget buildMapFrame(String url) => const ColoredBox(
      color: WebPalette.sand,
      child: Center(
        child: Text(
          'Interactive map available in the web browser.',
          textAlign: TextAlign.center,
        ),
      ),
    );
