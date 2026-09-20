import 'package:flutter/material.dart';

import '../../controllers/session_controller.dart';
import '../../models/models.dart';
import '../../views/caretaker/caretaker_shell.dart';
import '../../views/owner/owner_shell.dart';
import '../theme/web_theme.dart';

/// Temporary bridge to existing staff screens; NOT the final desktop dashboard.
class StaffWorkspacePage extends StatelessWidget {
  const StaffWorkspacePage({super.key, required this.role, required this.onBack});

  final UserRole role;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Material(
            color: WebPalette.ink,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'CarmeLink · Staff access',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: onBack,
                      child: const Text('Public website', style: TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () async {
                        try {
                          await SessionController.instance.signOut();
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Sign-out failed. Please retry.')),
                            );
                          }
                        }
                      },
                      child: const Text('Sign out', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: role == UserRole.owner
                ? const OwnerShell()
                : const CaretakerShell(),
          ),
        ],
      ),
    );
  }
}
