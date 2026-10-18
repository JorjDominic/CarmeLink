import 'package:flutter/material.dart';

/// Displays supplied values without calculating or formatting financial data.
class FinancialSummary extends StatelessWidget {
  const FinancialSummary({required this.items, super.key});

  final List<(String, String, IconData, String)> items;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, bounds) {
        final theme = Theme.of(context);
        final colors = theme.colorScheme;
        final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
        final columns = largeText || bounds.maxWidth < 520
            ? 1
            : bounds.maxWidth >= 1000
                ? items.length
                : 2;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          for (final item in items)
            SizedBox(
              width: (bounds.maxWidth - 12 * (columns - 1)) / columns,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border.all(color: colors.outlineVariant),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: .08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child:
                                Icon(item.$3, size: 20, color: colors.primary),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(item.$1,
                                  style: theme.textTheme.labelLarge)),
                        ]),
                    const SizedBox(height: 12),
                    Text(item.$2,
                        style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ])),
                    if (item.$4.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(item.$4,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
            ),
        ]);
      });
}
