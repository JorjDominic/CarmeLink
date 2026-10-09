import 'package:flutter/material.dart';

/// Keeps long notes inside a scrolling field and dialog content, while the
/// dialog actions remain outside the scrolling area when the keyboard opens.
class ReviewNotesDialog extends StatelessWidget {
  const ReviewNotesDialog({
    required this.title,
    required this.controller,
    required this.label,
    required this.maxLength,
    required this.actions,
    this.hint,
    this.saving = false,
    super.key,
  });

  final String title, label;
  final String? hint;
  final TextEditingController controller;
  final int maxLength;
  final bool saving;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(title),
        scrollable: true,
        content: SizedBox(
          width: 440,
          child: TextField(
            controller: controller,
            enabled: !saving,
            minLines: 3,
            maxLines: 6,
            maxLength: maxLength,
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              alignLabelWithHint: true,
            ),
          ),
        ),
        actions: actions,
      );
}
