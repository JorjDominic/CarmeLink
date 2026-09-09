import 'package:flutter/material.dart';

import '../../controllers/session_controller.dart';
import '../../models/models.dart';

/// Stops a role-specific workspace from rendering for the wrong session.
/// Supabase RLS remains the authoritative data-security boundary.
class RoleGuard extends StatelessWidget {
  const RoleGuard({required this.allowedRoles, required this.child, super.key});

  final Set<UserRole> allowedRoles;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final user = SessionController.instance.currentUser;
    if (user != null && allowedRoles.contains(user.role)) return child;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline,
                    size: 48, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                Text('Access denied',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                const Text(
                  'This page is not available for your account role.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
