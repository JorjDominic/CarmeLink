import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/web_theme.dart';
import '../landing_content.dart';

/// Real photo viewer. Arrow keys navigate; Escape closes; photos are local.
class PhotoLightbox extends StatefulWidget {
  const PhotoLightbox({
    super.key,
    required this.photos,
    required this.initialIndex,
  });

  final List<PropertyPhoto> photos;
  final int initialIndex;

  @override
  State<PhotoLightbox> createState() => _PhotoLightboxState();
}

class _PhotoLightboxState extends State<PhotoLightbox> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
  }

  void _move(int direction) {
    final next = _index + direction;
    if (next < 0 || next >= widget.photos.length) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(next);
      return;
    }
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photos[_index];
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _move(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _move(1),
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.pop(context),
      },
      child: Focus(
        autofocus: true,
        child: Dialog(
          insetPadding: const EdgeInsets.all(12),
          backgroundColor: WebPalette.ink,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240, maxHeight: 840),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${photo.title}  ·  ${_index + 1}/${widget.photos.length}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close gallery',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: widget.photos.length,
                    onPageChanged: (index) => setState(() => _index = index),
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Image.asset(
                        widget.photos[index].path,
                        fit: BoxFit.contain,
                        semanticLabel: widget.photos[index].description,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Text('Photo unavailable', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Previous photo',
                        onPressed: _index == 0 ? null : () => _move(-1),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      Expanded(
                        child: Text(
                          photo.description,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Next photo',
                        onPressed: _index == widget.photos.length - 1 ? null : () => _move(1),
                        icon: const Icon(Icons.arrow_forward, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
