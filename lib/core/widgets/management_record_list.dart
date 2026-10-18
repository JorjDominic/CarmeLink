import 'package:flutter/material.dart';
import 'numbered_pagination.dart';

/// Pages the already-loaded presentation list; never fetches or alters records.
class ManagementRecordList<T> extends StatefulWidget {
  const ManagementRecordList(
      {required this.items,
      required this.itemBuilder,
      required this.itemLabel,
      this.bottomClearance = 0,
      super.key});
  final List<T> items;
  final Widget Function(T) itemBuilder;
  final String itemLabel;
  final double bottomClearance;
  @override
  State<ManagementRecordList<T>> createState() =>
      _ManagementRecordListState<T>();
}

class _ManagementRecordListState<T> extends State<ManagementRecordList<T>> {
  static const pageSize = 6;
  int page = 1;
  @override
  void didUpdateWidget(covariant ManagementRecordList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) page = 1;
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900 &&
                    MediaQuery.textScalerOf(context).scale(1) <= 1.3
                ? 2
                : 1;
            final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(spacing: 12, runSpacing: 12, children: [
              for (final item
                  in widget.items.skip((page - 1) * pageSize).take(pageSize))
                SizedBox(width: width, child: widget.itemBuilder(item)),
            ]);
          }),
          const SizedBox(height: 12),
          NumberedPaginationBar(
              currentPage: page,
              totalItems: widget.items.length,
              pageSize: pageSize,
              itemLabel: widget.itemLabel,
              onPageChanged: (value) => setState(() => page = value)),
          if (widget.bottomClearance > 0)
            SizedBox(height: widget.bottomClearance),
        ],
      );
}
