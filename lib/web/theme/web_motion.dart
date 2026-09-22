import 'package:flutter/material.dart';

/// Motion tokens for the public website only. This file does not change the
/// shared/mobile theme, typography or color palette.
abstract final class WebMotion {
  static const Duration feedback = Duration(milliseconds: 180);
  static const Duration caption = Duration(milliseconds: 240);
  static const Duration gallery = Duration(milliseconds: 420);
  static const Duration reveal = Duration(milliseconds: 480);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve travel = Curves.easeInOutCubic;

  /// Removes nonessential motion when requested by the visitor/device.
  static Duration duration(BuildContext context, Duration normal) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : normal;
}
