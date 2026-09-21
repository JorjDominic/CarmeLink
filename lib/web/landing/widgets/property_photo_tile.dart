import 'package:flutter/material.dart';

import '../../theme/web_theme.dart';
import '../../theme/web_motion.dart';
import '../landing_content.dart';

/// Photo fills its tailored frame; no extra hover zoom is applied.
class PropertyPhotoTile extends StatefulWidget {
  const PropertyPhotoTile({
    super.key,
    required this.photo,
    required this.onOpen,
    this.height = 270,
    this.showCaption = true,
  });

  final PropertyPhoto photo;
  final VoidCallback onOpen;
  final double? height;
  final bool showCaption;

  @override
  State<PropertyPhotoTile> createState() => _PropertyPhotoTileState();
}

class _PropertyPhotoTileState extends State<PropertyPhotoTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      label: 'Open photo: ${widget.photo.title}',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: WebPalette.cream,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onOpen,
            child: SizedBox(
              height: widget.height,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: WebPalette.sand,
                    child: Image.asset(
                      widget.photo.path,
                      // Use a moderate editorial crop instead of letterboxing.
                      // The caller chooses a taller frame for square photos.
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      semanticLabel: widget.photo.description,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Text('Photo unavailable'),
                      ),
                    ),
                  ),
                  if (widget.showCaption) ...[
                    // Keep the photo bright outside the caption area.
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 90,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                WebPalette.ink.withValues(alpha: .79),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 18,
                      right: 18,
                      bottom: 16,
                      child: AnimatedSlide(
                        offset: _hovered && !reduceMotion
                            ? const Offset(0, -0.075)
                            : Offset.zero,
                        duration: WebMotion.duration(context, WebMotion.feedback),
                        curve: WebMotion.enter,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.photo.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const Icon(Icons.north_east, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
