import 'package:flutter/material.dart';

/// Read-only presentation shared by the existing role-specific notice boards.
class NoticeContent extends StatelessWidget {
  const NoticeContent(
      {required this.title,
      required this.body,
      required this.color,
      super.key});
  final String title;
  final String body;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .04),
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        child: LayoutBuilder(builder: (context, bounds) {
          final heading = Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700));
          final content = Text(body,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(height: 1.45));
          if (bounds.maxWidth >= 720 &&
              MediaQuery.textScalerOf(context).scale(1) <= 1.3) {
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: bounds.maxWidth * .28, child: heading),
              const SizedBox(width: 24),
              Expanded(child: content),
            ]);
          }
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [heading, const SizedBox(height: 8), content]);
        }),
      );
}
