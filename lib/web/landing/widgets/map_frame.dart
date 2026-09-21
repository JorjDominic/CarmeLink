import 'package:flutter/material.dart';

import 'map_frame_stub.dart'
    if (dart.library.html) 'map_frame_web.dart' as implementation;

/// Website-only map surface. Widget tests use the non-browser placeholder;
/// standard JavaScript Flutter web builds use a native, interactive iframe.
class MapFrame extends StatelessWidget {
  const MapFrame({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) => implementation.buildMapFrame(url);
}
