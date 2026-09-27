import 'package:flutter/material.dart';
import '../../controllers/guardian_controller.dart';
import '../../core/widgets/adaptive_shell.dart';
import '../../core/widgets/role_guard.dart';
import '../../models/models.dart';
import '../../services/app_notification_service.dart';
import '../shared/shared_views.dart';
import 'guardian_pages.dart';

class GuardianShell extends StatefulWidget {
  const GuardianShell({super.key});

  @override
  State<GuardianShell> createState() => _GuardianShellState();
}

class _GuardianShellState extends State<GuardianShell> {
  @override
  void initState() {
    super.initState();
    GuardianController.instance.loadData();
    GuardianController.instance.loadCurfewRequests();
  }


  Widget? _notificationDestination(AppNotificationItem notification) {
    final routeType = notification.routeType?.trim();
    final route = (routeType == null || routeType.isEmpty
            ? notification.notificationType.trim()
            : routeType)
        .toLowerCase();
    return switch (route) {
      'message' || 'conversation' => const GuardianConversationPage(),
      'payment' => const GuardianPaymentStatusPage(),
      'curfew' || 'gate' || 'gate_event' || 'safety' =>
        const GuardianPresenceMonitoringPage(),
      'announcement' => const GuardianAnnouncementsPage(),
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) => RoleGuard(
        allowedRoles: {UserRole.guardian},
        child: AdaptiveRoleShell(
          roleLabel: 'Guardian',
          notificationPageBuilder: _notificationDestination,
          messagePage: GuardianMessagesPage(),
          destinations: [
            AppDestination(
                label: 'Home',
                icon: Icons.home_outlined,
                selectedIcon: Icons.home,
                page: GuardianDashboardPage()),
            AppDestination(
                label: 'Curfew',
                icon: Icons.schedule_outlined,
                selectedIcon: Icons.schedule,
                page: GuardianPresenceMonitoringPage(),
                isWorkInProgress: true),
            AppDestination(
                label: 'Notices',
                icon: Icons.campaign_outlined,
                selectedIcon: Icons.campaign,
                page: GuardianAnnouncementsPage()),
            AppDestination(
                label: 'Messages',
                icon: Icons.chat_bubble_outline,
                selectedIcon: Icons.chat_bubble,
                page: GuardianMessagesPage()),
            AppDestination(
                label: 'Profile',
                icon: Icons.person_outline,
                selectedIcon: Icons.person,
                page: ProfilePage()),
          ],
        ),
      );
}
