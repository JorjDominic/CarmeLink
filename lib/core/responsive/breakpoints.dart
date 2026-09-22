import 'package:flutter/material.dart';

class AppBreakpoints {
  static const double extraSmall = 360;
  static const double phone = 600;
  static const double tablet = 840;
  static const double largeTablet = 1100;

  static double width(BuildContext context) => MediaQuery.sizeOf(context).width;

  static bool isExtraSmall(BuildContext context) => width(context) < extraSmall;

  static bool isPhone(BuildContext context) => width(context) < phone;

  static bool isTablet(BuildContext context) {
    final value = width(context);
    return value >= phone && value < largeTablet;
  }

  static bool isLargeTablet(BuildContext context) =>
      width(context) >= largeTablet;

  static double horizontalPadding(BuildContext context) {
    final value = width(context);
    if (value < extraSmall) return 14;
    if (value < phone) return 18;
    if (value < tablet) return 24;
    return 32;
  }

  static double contentMaxWidth(BuildContext context) {
    final value = width(context);
    if (value < phone) return double.infinity;
    if (value < largeTablet) return 920;
    return 1024;
  }

  static int dashboardColumns(BuildContext context) {
    final value = width(context);
    if (value < 520) return 1;
    if (value < 900) return 2;
    return 3;
  }
}

class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({
    required this.child,
    this.maxWidth,
    this.padding,
    super.key,
  });

  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final horizontal = AppBreakpoints.horizontalPadding(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? AppBreakpoints.contentMaxWidth(context),
        ),
        child: Padding(
          padding:
              padding ?? EdgeInsets.fromLTRB(horizontal, 10, horizontal, 28),
          child: child,
        ),
      ),
    );
  }
}
