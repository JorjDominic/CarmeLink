import 'package:flutter/material.dart';

/// Desktop-only presentation for a short record preview. The caller owns
/// authorization, fetching, and every write; this is deliberately UI-only.
Future<T?> showStaffQuickPanel<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) =>
    showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close quick details',
      barrierColor: Colors.black.withValues(alpha: .30),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (panelContext, _, __) {
        final width = MediaQuery.sizeOf(panelContext).width;
        return SafeArea(
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: width < 464 ? width - 24 : 440,
                height: double.infinity,
                child: Material(
                  key: const Key('staff-quick-panel'),
                  color: Theme.of(panelContext).colorScheme.surface,
                  elevation: 10,
                  clipBehavior: Clip.antiAlias,
                  borderRadius: BorderRadius.circular(20),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: builder(panelContext),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
