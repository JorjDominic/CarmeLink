import 'package:flutter/material.dart';

/// Layout only. Both panes retain their own data, actions and navigation.
class WorkspaceColumns extends StatelessWidget {
  const WorkspaceColumns(
      {required this.aside,
      required this.content,
      this.asideWidth = 300,
      super.key});
  final Widget aside;
  final Widget content;
  final double asideWidth;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, bounds) {
        if (bounds.maxWidth < 1000 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.3) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [aside, const SizedBox(height: 20), content]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: asideWidth, child: aside),
          const SizedBox(width: 24),
          Expanded(child: content),
        ]);
      });
}
