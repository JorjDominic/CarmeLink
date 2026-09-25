import 'package:flutter/widgets.dart';

enum CarmeLinkAppSurface {
  mobileApp,
  webPortal,
}

class CarmeLinkSurfaceScope extends InheritedWidget {
  const CarmeLinkSurfaceScope({
    required this.surface,
    required super.child,
    super.key,
  });

  final CarmeLinkAppSurface surface;

  static CarmeLinkAppSurface of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<CarmeLinkSurfaceScope>()
            ?.surface ??
        CarmeLinkAppSurface.mobileApp;
  }

  static bool isWebPortal(BuildContext context) {
    return of(context) == CarmeLinkAppSurface.webPortal;
  }

  @override
  bool updateShouldNotify(CarmeLinkSurfaceScope oldWidget) {
    return surface != oldWidget.surface;
  }
}
