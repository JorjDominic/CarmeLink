import 'package:flutter/material.dart';

import '../../controllers/session_controller.dart';
import '../../models/models.dart';
import 'staff_web_portal_shell.dart';
import 'widgets/staff_workspace_chrome.dart';

/// Web-only composition; mobile role shells are intentionally left untouched.
class StaffWorkspacePage extends StatelessWidget {
  const StaffWorkspacePage(
      {super.key, required this.role, required this.onBack});

  final UserRole role;
  final VoidCallback onBack;

  Future<bool> _confirmLogout(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Logout?'),
            content: const Text(
              'You will be signed out and returned to the CarmeLink landing page.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                icon: const Icon(Icons.logout_outlined),
                label: const Text('Logout'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _logout(BuildContext context) async {
    if (!await _confirmLogout(context)) return;
    try {
      await SessionController.instance.signOut();
      if (!context.mounted) return;
      onBack();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logout failed. Please retry.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StaffWebPortalShell(
      role: role,
      workspaceBuilder: (scopedContext, workspace) => StaffWorkspaceChrome(
        roleLabel: role == UserRole.owner ? 'Owner' : 'Caretaker',
        onSignOut: () => _logout(scopedContext),
        child: workspace,
      ),
    );
  }
}
