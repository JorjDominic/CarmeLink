// This file is loaded ONLY by the HTML website renderer, never by mobile or
// Flutter VM widget tests. No extra Flutter dependencies or API keys needed.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

int _nextViewId = 0;

Widget buildMapFrame(String url) => _IframeSurface(url: url);

/// Register once per actual iframe. Rebuilds from scrolling must not reload it.
class _IframeSurface extends StatefulWidget {
  const _IframeSurface({required this.url});

  final String url;

  @override
  State<_IframeSurface> createState() => _IframeSurfaceState();
}

class _IframeSurfaceState extends State<_IframeSurface> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'carmelita-location-map-${_nextViewId++}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      return html.IFrameElement()
        ..src = widget.url
        ..title = 'Interactive map showing the Carmelita neighborhood'
        ..setAttribute('loading', 'lazy')
        ..setAttribute('referrerpolicy', 'strict-origin-when-cross-origin')
        ..setAttribute('allowfullscreen', '')
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%';
    });
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}
