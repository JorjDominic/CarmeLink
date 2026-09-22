import 'package:flutter/material.dart';

import '../../theme/web_theme.dart';
import '../../theme/web_motion.dart';
import '../landing_content.dart';

/// One featured image with manual navigation and a compact thumbnail rail.
/// No autoplay: visitors control how quickly photographs change.
class EditorialPhotoGallery extends StatefulWidget {
  const EditorialPhotoGallery({
    super.key,
    required this.photos,
    required this.onOpen,
  });

  final List<PropertyPhoto> photos;
  final ValueChanged<PropertyPhoto> onOpen;

  @override
  State<EditorialPhotoGallery> createState() => _EditorialPhotoGalleryState();
}

class _EditorialPhotoGalleryState extends State<EditorialPhotoGallery> {
  late final PageController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (index < 0 || index >= widget.photos.length || index == _index) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(index);
    } else {
      _controller.animateToPage(
        index,
        duration: WebMotion.gallery,
        curve: WebMotion.travel,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) {
      return const Text('No photos in this category.');
    }
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 700;
    final photo = widget.photos[_index];
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        ClipRRect(
          key: const ValueKey('gallery-featured-stage'),
          borderRadius: BorderRadius.circular(wide ? 24 : 16),
          child: AspectRatio(
            // A contained stage avoids the previous oversized photo while
            // keeping a filled editorial frame and a full-photo lightbox.
            aspectRatio: wide ? 1.65 : 1.08,
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.photos.length,
              onPageChanged: (index) => setState(() => _index = index),
              itemBuilder: (context, index) {
                final item = widget.photos[index];
                return Semantics(
                  button: true,
                  label: 'Enlarge photo: ${item.title}',
                  child: Material(
                    color: WebPalette.sand,
                    child: InkWell(
                      onTap: () => widget.onOpen(item),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(
                            color: WebPalette.sand,
                            child: Image.asset(
                              item.path,
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                              semanticLabel: item.description,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Text('Photo unavailable'),
                              ),
                            ),
                          ),
                          // Limit the caption shade to its own short band;
                          // do not darken most of the photograph.
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            height: wide ? 145 : 120,
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      WebPalette.ink.withValues(alpha: .82),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: wide ? 36 : 19,
                            right: wide ? 36 : 19,
                            bottom: wide ? 30 : 19,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        item.title,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: wide ? 30 : 22,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        item.description,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Icon(Icons.open_in_full,
                                    color: Colors.white, size: 22),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            AnimatedSwitcher(
              duration: WebMotion.duration(context, WebMotion.caption),
              switchInCurve: WebMotion.enter,
              switchOutCurve: WebMotion.enter,
              child: Text(
                '${(_index + 1).toString().padLeft(2, '0')} / ${widget.photos.length.toString().padLeft(2, '0')}',
                key: ValueKey<int>(_index),
                style: const TextStyle(
                  color: WebPalette.muted,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 1.8,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: AnimatedSwitcher(
                duration: WebMotion.duration(context, WebMotion.caption),
                switchInCurve: WebMotion.enter,
                switchOutCurve: WebMotion.enter,
                child: Text(
                  photo.title,
                  key: ValueKey<String>(photo.path),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: WebPalette.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            IconButton.outlined(
              tooltip: 'Previous gallery photo',
              onPressed: _index == 0 ? null : () => _select(_index - 1),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              tooltip: 'Next gallery photo',
              onPressed: _index == widget.photos.length - 1
                  ? null
                  : () => _select(_index + 1),
              icon: const Icon(Icons.arrow_forward_rounded),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 83,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: widget.photos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 9),
            itemBuilder: (context, index) {
              final item = widget.photos[index];
              final selected = index == _index;
              return Tooltip(
                message: item.title,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: ValueKey('gallery-thumbnail-$index'),
                    onTap: () => _select(index),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: WebMotion.duration(context, WebMotion.feedback),
                      curve: WebMotion.enter,
                      width: 112,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: selected ? WebPalette.plum : WebPalette.border,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: ColoredBox(
                          color: WebPalette.sand,
                          child: Image.asset(
                            item.path,
                            fit: BoxFit.cover,
                            semanticLabel: 'Select ${item.title}',
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
          ],
        ),
      ),
    );
  }
}
