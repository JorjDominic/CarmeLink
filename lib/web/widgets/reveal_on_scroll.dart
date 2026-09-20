import 'package:flutter/material.dart';

/// Lightweight one-time reveal. Listens to the existing Scrollable, no packages.
/// Reduced-motion users see content immediately.
class RevealOnScroll extends StatefulWidget {
  const RevealOnScroll({super.key, required this.child});
  final Widget child;

  @override
  State<RevealOnScroll> createState() => _RevealOnScrollState();
}

class _RevealOnScrollState extends State<RevealOnScroll> {
  ScrollPosition? _position;
  bool _revealed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextPosition = Scrollable.maybeOf(context)?.position;
    if (!identical(_position, nextPosition)) {
      _position?.removeListener(_checkVisibility);
      _position = nextPosition;
      _position?.addListener(_checkVisibility);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVisibility());
  }

  void _checkVisibility() {
    if (!mounted || _revealed) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() => _revealed = true);
      return;
    }
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final bottom = top + box.size.height;
    final viewport = MediaQuery.sizeOf(context).height;
    if (top < viewport * 0.93 && bottom > 0) {
      setState(() => _revealed = true);
    }
  }

  @override
  void dispose() {
    _position?.removeListener(_checkVisibility);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return AnimatedOpacity(
      opacity: _revealed ? 1 : 0,
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: _revealed ? Offset.zero : const Offset(0, 0.045),
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
