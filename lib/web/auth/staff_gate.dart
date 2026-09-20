import 'package:flutter/material.dart';
import '../../views/shared/shared_views.dart';
import '../../controllers/session_controller.dart';
import '../../models/models.dart';
import '../app/web_routes.dart';
import '../dashboard/staff_workspace_page.dart';
import 'staff_access_page.dart';

/// UI-level access guard. Supabase RLS must separately enforce all DB access.
class StaffGate extends StatefulWidget {
  const StaffGate({super.key});

  @override
  State<StaffGate> createState() => _StaffGateState();
}

class _StaffGateState extends State<StaffGate> {
  final SessionController _session = SessionController.instance;
  bool _finishedInitialRestore = false;

  void _goHome() => Navigator.of(context).pushNamedAndRemoveUntil(
        WebRoutes.home,
        (route) => false,
      );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _session,
      builder: (context, _) {
        if (!_session.loading) _finishedInitialRestore = true;

        // Do not confuse the sign-in loading state with initial session restore:
        // keep the form mounted so error and text state remain intact.
        if (_session.loading && !_finishedInitialRestore) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        if (_session.passwordRecovery) {
          return ChangePasswordPage(
            recoveryMode: true,
            onComplete: _session.completePasswordRecovery,
          );
        }

        final user = _session.currentUser;
        if (user == null) {
          return StaffAccessPage(onBack: _goHome);
        }
        if (user.role == UserRole.owner || user.role == UserRole.caretaker) {
          return StaffWorkspacePage(role: user.role, onBack: _goHome);
        }
        return _NonStaffPage(onBack: _goHome);
      },
    );
  }
}

class _NonStaffPage extends StatelessWidget {
  const _NonStaffPage({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 44),
                const SizedBox(height: 16),
                const Text('Staff access only',
                    style:
                        TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text(
                  'This portal is for owner and caretaker accounts. '
                  'Tenant and guardian accounts should use the mobile application.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () async {
                    try {
                      await SessionController.instance.signOut();
                      if (context.mounted) onBack();
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Sign-out failed. Please retry.')),
                        );
                      }
                    }
                  },
                  child: const Text('Sign out and return'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
