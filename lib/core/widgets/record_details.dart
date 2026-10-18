import 'package:flutter/material.dart';

/// Presentation of already-computed record values. No formatting or policy is
/// applied here: callers retain their existing amounts, statuses and dates.
class RecordFacts extends StatelessWidget {
  const RecordFacts(
      {required this.items, this.emphasizeFirst = false, super.key});

  final List<(String, String)> items;
  final bool emphasizeFirst;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    // Table supports intrinsic measurement inside AlertDialog. Each cell still
    // takes its width from its parent rather than from the screen width.
    final columns = MediaQuery.textScalerOf(context).scale(1) > 1.3 ? 1 : 2;
    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      children: [
        for (var row = 0; row < items.length; row += columns)
          TableRow(children: [
            for (var column = 0; column < columns; column++)
              if (row + column >= items.length)
                const SizedBox.shrink()
              else
                Padding(
                  padding: EdgeInsets.only(
                      right: column < columns - 1 ? 8 : 0, bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: emphasizeFirst && row + column == 0
                          ? colors.primary.withValues(alpha: .08)
                          : colors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(items[row + column].$1,
                              style: theme.textTheme.labelMedium
                                  ?.copyWith(color: colors.onSurfaceVariant)),
                          const SizedBox(height: 5),
                          Text(items[row + column].$2,
                              style: (emphasizeFirst && row + column == 0
                                      ? theme.textTheme.titleLarge
                                      : theme.textTheme.bodyMedium)
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                        ]),
                  ),
                ),
          ]),
      ],
    );
  }
}

class RecordSection extends StatelessWidget {
  const RecordSection(
      {required this.title,
      required this.icon,
      required this.child,
      super.key});
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
              child: Text(title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}
