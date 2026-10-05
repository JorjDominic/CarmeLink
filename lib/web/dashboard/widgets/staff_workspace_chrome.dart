import 'package:flutter/material.dart';

import '../../../core/widgets/adaptive_shell.dart';
import '../staff_portal_theme.dart';

/// Presentation layer for the REAL owner/caretaker web workspace.
/// Never substitutes demo data or changes the existing role's destinations.
class StaffWorkspaceChrome extends StatelessWidget {
  const StaffWorkspaceChrome({
    super.key,
    required this.roleLabel,
    required this.onSignOut,
    required this.child,
  });

  final String roleLabel;
  final Future<void> Function() onSignOut;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final spacious = width >= 900;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onSurface = scheme.onSurface;
    final border = theme.dividerColor;
    final nav = CarmelitaNavScope.maybeOf(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              key: const Key('staff-workspace-header'),
              padding: EdgeInsets.symmetric(
                horizontal: spacious ? 26 : 10,
                vertical: spacious ? 15 : 8,
              ),
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border(bottom: BorderSide(color: border)),
              ),
              child: Row(
                children: [
                  Container(
                    width: spacious ? 46 : 36,
                    height: spacious ? 46 : 36,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      border: Border.all(color: border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Image.asset(
                      'assets/web/brand/carmelita_logo.jpg',
                      fit: BoxFit.contain,
                      semanticLabel: 'Carmelita Dormitory logo',
                      errorBuilder: (context, error, stack) => Icon(
                        Icons.apartment_rounded,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (spacious)
                          Text(
                            'CARMELITA / MANAGEMENT',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 10,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        Text(
                          spacious ? 'Staff workspace' : roleLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: onSurface,
                            fontSize: spacious ? 20 : 13,
                            letterSpacing: spacious ? -.4 : 0,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (spacious) ...[
                    Container(
                      key: const Key('staff-workspace-role'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: border),
                      ),
                      child: Text(
                        roleLabel,
                        style: TextStyle(
                          color: scheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  _HeaderCountedIconButton(
                    key: const Key('staff-workspace-messages'),
                    tooltip: 'Messages',
                    icon: Icons.chat_bubble_outline,
                    unreadCount: nav?.unreadMessageCount ?? 0,
                    onPressed: nav?.openMessages,
                  ),
                  _HeaderCountedIconButton(
                    key: const Key('staff-workspace-notifications'),
                    tooltip: 'Notifications',
                    icon: Icons.notifications_none_rounded,
                    unreadCount: nav?.unreadNotificationCount ?? 0,
                    onPressed: nav?.openNotifications,
                  ),
                  IconButton(
                    key: const Key('web-header-account'),
                    tooltip: 'Account',
                    onPressed:
                        nav == null ? null : () => nav.selectLabel('Profile'),
                    icon: const Icon(Icons.account_circle_outlined),
                  ),
                  if (spacious)
                    TextButton.icon(
                      key: const Key('staff-workspace-logout'),
                      onPressed: onSignOut,
                      icon: const Icon(Icons.logout_outlined, size: 18),
                      label: const Text('Logout'),
                    )
                  else
                    IconButton(
                      key: const Key('staff-workspace-logout'),
                      tooltip: 'Logout',
                      onPressed: onSignOut,
                      icon: const Icon(Icons.logout_outlined, size: 21),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Theme(
                data: StaffPortalTheme.from(theme),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCountedIconButton extends StatelessWidget {
  const _HeaderCountedIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.unreadCount,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final int unreadCount;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon),
        ),
        if (unreadCount > 0)
          Positioned(
            right: 3,
            top: 3,
            child: IgnorePointer(
              child: Container(
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.error,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: scheme.surface, width: 1.5),
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: TextStyle(
                    color: scheme.onError,
                    fontSize: 9,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
