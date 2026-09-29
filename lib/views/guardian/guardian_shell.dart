import 'dart:async';

import 'package:flutter/material.dart';
import '../../controllers/guardian_controller.dart';
import '../../core/widgets/adaptive_shell.dart';
import '../../core/widgets/role_guard.dart';
import '../../models/models.dart';
import '../../services/app_notification_service.dart';
import '../shared/shared_views.dart';
import 'guardian_pages.dart';
import 'guardian_documents_page.dart';

class GuardianShell extends StatefulWidget {
  const GuardianShell({super.key});

  @override
  State<GuardianShell> createState() => _GuardianShellState();
}

class _GuardianShellState extends State<GuardianShell>
    with WidgetsBindingObserver {
  bool _refreshInFlight = false;
  bool _refreshAgain = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refreshLiveData());
  }

  Future<void> _refreshLiveData() async {
    if (_refreshInFlight) {
      _refreshAgain = true;
      return;
    }

    do {
      _refreshAgain = false;
      _refreshInFlight = true;
      try {
        await GuardianController.instance.loadData(force: true);
      } finally {
        _refreshInFlight = false;
      }
    } while (_refreshAgain && mounted);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshLiveData());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
      'curfew' ||
      'gate' ||
      'gate_event' ||
      'safety' =>
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
                label: 'Documents',
                icon: Icons.folder_outlined,
                selectedIcon: Icons.folder,
                page: GuardianDocumentsPage()),
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
