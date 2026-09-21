import 'package:flutter/material.dart';

import '../../controllers/session_controller.dart';
import '../../models/models.dart';
import 'staff_web_portal_shell.dart';
import 'widgets/staff_workspace_chrome.dart';

/// Web-only composition; mobile role shells are intentionally left untouched.
class StaffWorkspacePage extends StatelessWidget {
  const StaffWorkspacePage({super.key, required this.role, required this.onBack});

  final UserRole role;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => StaffWorkspaceChrome(
        roleLabel: role == UserRole.owner ? 'Owner' : 'Caretaker',
        onPublicWebsite: onBack,
        onSignOut: () async {
          try {
            await SessionController.instance.signOut();
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Sign-out failed. Please retry.'),
              ));
            }
          }
        },
        child: StaffWebPortalShell(role: role),
      );
}
