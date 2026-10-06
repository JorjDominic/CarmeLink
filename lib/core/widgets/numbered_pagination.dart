import 'package:flutter/material.dart';

/// Compact numbered pagination for bounded management lists.
///
/// Keeps long owner/staff lists usable on mobile while still exposing direct
/// page numbers on larger screens.
class NumberedPaginationBar extends StatelessWidget {
  const NumberedPaginationBar({
    super.key,
    required this.currentPage,
    required this.totalItems,
    required this.pageSize,
    required this.onPageChanged,
    this.itemLabel = 'items',
  });

  final int currentPage;
  final int totalItems;
  final int pageSize;
  final ValueChanged<int> onPageChanged;
  final String itemLabel;

  int get _pageCount {
    if (totalItems <= 0 || pageSize <= 0) return 1;
    return (totalItems + pageSize - 1) ~/ pageSize;
  }

  int _safePage(int pageCount) {
    if (currentPage < 1) return 1;
    if (currentPage > pageCount) return pageCount;
    return currentPage;
  }

  List<int> _visiblePages(int page, int pageCount, int maxButtons) {
    if (pageCount <= maxButtons) {
      return List<int>.generate(pageCount, (index) => index + 1);
    }

    var start = page - (maxButtons ~/ 2);
    if (start < 1) start = 1;
    var end = start + maxButtons - 1;
    if (end > pageCount) {
      end = pageCount;
      start = end - maxButtons + 1;
    }
    return List<int>.generate(end - start + 1, (index) => start + index);
  }

  @override
  Widget build(BuildContext context) {
    if (totalItems <= pageSize || totalItems <= 0) {
      return const SizedBox.shrink();
    }

    final pageCount = _pageCount;
    final page = _safePage(pageCount);
    final firstItem = ((page - 1) * pageSize) + 1;
    final rawLast = page * pageSize;
    final lastItem = rawLast > totalItems ? totalItems : rawLast;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxButtons = constraints.maxWidth < 420 ? 3 : 5;
        final pages = _visiblePages(page, pageCount, maxButtons);

        Widget pageButton(int value) {
          final selected = value == page;
          final child = Text('$value');
          return selected
              ? FilledButton(
                  onPressed: null,
                  style: FilledButton.styleFrom(
                    disabledBackgroundColor:
                        Theme.of(context).colorScheme.primary,
                    disabledForegroundColor:
                        Theme.of(context).colorScheme.onPrimary,
                    minimumSize: const Size(38, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: child,
                )
              : OutlinedButton(
                  onPressed: () => onPageChanged(value),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(38, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: child,
                );
        }

        final controls = <Widget>[
          IconButton(
            tooltip: 'First page',
            onPressed: page > 1 ? () => onPageChanged(1) : null,
            icon: const Icon(Icons.first_page_rounded),
          ),
          IconButton(
            tooltip: 'Previous page',
            onPressed: page > 1 ? () => onPageChanged(page - 1) : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          ...pages.map(pageButton),
          IconButton(
            tooltip: 'Next page',
            onPressed: page < pageCount ? () => onPageChanged(page + 1) : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
          IconButton(
            tooltip: 'Last page',
            onPressed: page < pageCount ? () => onPageChanged(pageCount) : null,
            icon: const Icon(Icons.last_page_rounded),
          ),
        ];

        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Showing $firstItem-$lastItem of $totalItems $itemLabel',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: controls
                      .map(
                        (control) => Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: control,
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
