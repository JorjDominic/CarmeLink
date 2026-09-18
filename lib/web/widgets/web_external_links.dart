import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens real external destinations; never displays a fake successful inquiry.
abstract final class WebExternalLinks {
  static Future<void> open(BuildContext context, String link) async {
    try {
      final opened = await launchUrl(
        Uri.parse(link),
        mode: LaunchMode.platformDefault,
        webOnlyWindowName: '_blank',
      );
      if (opened) return;
    } catch (_) {
      // Show a usable fallback below. We intentionally do not claim success.
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Could not open the link. You can copy it instead.'),
        action: SnackBarAction(
          label: 'Copy link',
          onPressed: () => Clipboard.setData(ClipboardData(text: link)),
        ),
      ),
    );
  }
}
