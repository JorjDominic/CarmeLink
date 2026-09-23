import 'dart:async';

import 'package:flutter/material.dart';

import 'auth_views.dart';

/// Mobile pre-login flow:
/// short brand splash -> sign in.
///
/// The old WelcomePage is intentionally bypassed so opening the app does not
/// require an extra tap before authentication.
class MobileAuthEntry extends StatefulWidget {
  const MobileAuthEntry({
    this.skipSplash = false,
    super.key,
  });

  final bool skipSplash;

  @override
  State<MobileAuthEntry> createState() => _MobileAuthEntryState();
}

class _MobileAuthEntryState extends State<MobileAuthEntry> {
  Timer? _timer;
  late bool _showSignIn;

  @override
  void initState() {
    super.initState();
    _showSignIn = widget.skipSplash;

    if (!_showSignIn) {
      _timer = Timer(const Duration(milliseconds: 1100), () {
        if (!mounted) return;
        setState(() => _showSignIn = true);
      });
    }
  }

  @override
  void didUpdateWidget(covariant MobileAuthEntry oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.skipSplash && !oldWidget.skipSplash && !_showSignIn) {
      _timer?.cancel();
      setState(() => _showSignIn = true);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: _showSignIn
          ? const SignInPage(key: ValueKey('signin'))
          : const SplashPage(key: ValueKey('splash')),
    );
  }
}
