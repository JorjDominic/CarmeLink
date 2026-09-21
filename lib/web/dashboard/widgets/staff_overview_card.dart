import 'package:flutter/material.dart';

import '../../theme/web_motion.dart';
import '../../theme/web_theme.dart';

/// Web-only metric. Values must originate from the live controller, never
/// fabricated defaults. An unavailable dataset is NOT represented as zero.
class StaffOverviewCard extends StatefulWidget {
  const StaffOverviewCard({
    super.key,
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<StaffOverviewCard> createState() => _StaffOverviewCardState();
}

class _StaffOverviewCardState extends State<StaffOverviewCard> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) => setState(() => hovered = true),
        onExit: (_) => setState(() => hovered = false),
        child: AnimatedContainer(
          key: Key('staff-metric-${widget.label.toLowerCase().replaceAll(' ', '-')}'),
          duration: WebMotion.duration(context, WebMotion.feedback),
          curve: WebMotion.enter,
          decoration: BoxDecoration(
            color: hovered ? WebPalette.cream : WebPalette.surface,
            border: Border.all(
              color: hovered ? WebPalette.plum : WebPalette.border,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: hovered
                ? [BoxShadow(
                    color: WebPalette.ink.withValues(alpha: .055),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  )]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      Icon(widget.icon, color: WebPalette.plum, size: 21),
                      const Spacer(),
                      const Icon(Icons.arrow_outward,
                          color: WebPalette.muted, size: 17),
                    ]),
                    const SizedBox(height: 20),
                    Text(widget.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: WebPalette.ink,
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.7,
                        )),
                    const SizedBox(height: 4),
                    Text(widget.label,
                        style: const TextStyle(
                          color: WebPalette.ink,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        )),
                    const SizedBox(height: 4),
                    Text(widget.detail,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: WebPalette.muted,
                          fontSize: 12,
                          height: 1.4,
                        )),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class StaffActionRow extends StatelessWidget {
  const StaffActionRow({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
    this.value,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;
  final String? value;

  @override
  Widget build(BuildContext context) => Material(
        color: WebPalette.surface,
        child: InkWell(
          key: Key('staff-action-${title.toLowerCase().replaceAll(' ', '-')}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: WebPalette.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: WebPalette.sand,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: WebPalette.plum, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: WebPalette.ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(description,
                        style: const TextStyle(
                          color: WebPalette.muted,
                          fontSize: 12,
                          height: 1.4,
                        )),
                  ],
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: 6),
                Text(value!,
                    style: const TextStyle(
                        color: WebPalette.plum,
                        fontWeight: FontWeight.w800)),
              ],
              const SizedBox(width: 7),
              const Icon(Icons.chevron_right, color: WebPalette.muted, size: 19),
            ]),
          ),
        ),
      );
}
