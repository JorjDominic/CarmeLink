import 'package:flutter/material.dart';

import '../../theme/web_theme.dart';
import '../landing_content.dart';

/// Tappable photograph with keyboard-focusable ink response and subtle hover.
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
                  AnimatedScale(
                    scale: _hovered && !reduceMotion ? 1.045 : 1,
                    duration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 230),
                    curve: Curves.easeOutCubic,
                    child: Image.asset(
                      widget.photo.path,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      semanticLabel: widget.photo.description,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Text('Photo unavailable'),
                      ),
                    ),
                  ),
                  if (widget.showCaption) ...[
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, WebPalette.ink.withValues(alpha: .79)],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 18,
                      right: 18,
                      bottom: 16,
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
