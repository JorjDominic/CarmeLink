import 'dart:async';

import 'package:flutter/material.dart';

import '../../controllers/messaging_controller.dart';
import '../../controllers/session_controller.dart';
import '../../views/shared/shared_views.dart';
import '../../services/app_notification_service.dart';
import 'common_widgets.dart';

import '../runtime/app_surface.dart';

class AppDestination {
  const AppDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.page,
    this.isWorkInProgress = false,
    this.webGroup,
    this.webDescription,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;
  final bool isWorkInProgress;

  /// Browser-only grouping metadata. Mobile navigation ignores these fields.
  final String? webGroup;
  final String? webDescription;
}

class CarmelitaNavScope extends InheritedWidget {
  const CarmelitaNavScope({
    required this.openMenu,
    this.openMessages,
    this.openNotifications,
    this.unreadMessageCount = 0,
    this.unreadNotificationCount = 0,
    required this.selectIndex,
    required this.selectLabel,
    required super.child,
    super.key,
  });

  final Future<void> Function() openMenu;
  final VoidCallback? openMessages;
  final VoidCallback? openNotifications;
  final int unreadMessageCount;
  final int unreadNotificationCount;
  final ValueChanged<int> selectIndex;
  final ValueChanged<String> selectLabel;

  static CarmelitaNavScope? maybeOf(
    BuildContext context,
  ) {
    return context.dependOnInheritedWidgetOfExactType<CarmelitaNavScope>();
  }

  @override
  bool updateShouldNotify(
    CarmelitaNavScope oldWidget,
  ) {
    return openMenu != oldWidget.openMenu ||
        openMessages != oldWidget.openMessages ||
        openNotifications != oldWidget.openNotifications ||
        unreadMessageCount != oldWidget.unreadMessageCount ||
        unreadNotificationCount != oldWidget.unreadNotificationCount ||
        selectIndex != oldWidget.selectIndex ||
        selectLabel != oldWidget.selectLabel;
  }
}

class AdaptiveRoleShell extends StatefulWidget {
  const AdaptiveRoleShell({
    required this.destinations,
    required this.roleLabel,
    required this.messagePage,
    this.webDestinations = const [],
    this.notificationPageBuilder,
    super.key,
  });

  final List<AppDestination> destinations;
  final String roleLabel;
  final Widget messagePage;

  /// Extra desktop-only navigation to existing role-authorized pages.
  /// Mobile destinations and the in-app backend services stay unchanged.
  final List<AppDestination> webDestinations;

  /// Role-aware destination resolver for live in-app notifications. Web keeps
  /// the destination inside the persistent workspace; mobile pushes it on the
  /// role shell navigator.
  final Widget? Function(AppNotificationItem notification)?
      notificationPageBuilder;

  static Widget? activeMessagePage;

  static void openActiveMessages(BuildContext context) {
    final scopedAction = CarmelitaNavScope.maybeOf(context)?.openMessages;
    if (scopedAction != null) {
      scopedAction();
      return;
    }
    final page = activeMessagePage;
    if (page == null) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  static void openNotifications(BuildContext context) {
    final scopedAction = CarmelitaNavScope.maybeOf(context)?.openNotifications;
    if (scopedAction != null) {
      scopedAction();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const NotificationsPage()),
    );
  }

  @override
  State<AdaptiveRoleShell> createState() => _AdaptiveRoleShellState();
}

class _AdaptiveRoleShellState extends State<AdaptiveRoleShell> {
  int index = 0;
  StreamSubscription<List<AppNotificationItem>>? _notificationSubscription;
  Timer? _notificationPollTimer;
  bool _notificationStartInFlight = false;
  final Set<String> _seenNotificationIds = <String>{};
  bool _notificationsSeeded = false;
  int _unreadNotificationCount = 0;
  bool _messagingStarted = false;
  String? _workspaceLabelOverride;
  String? _workspaceGroupOverride;

  // Desktop sidebar disclosure belongs to the persistent shell rather than the
  // sidebar widget. This keeps the user's open/closed groups unchanged while
  // workspace pages switch. Empty by default = a tidy collapsed sidebar.
  final Set<String> _expandedWebGroups = <String>{};

  GlobalKey<NavigatorState> _webWorkspaceNavigatorKey =
      GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    MessagingController.instance.addListener(_onMessagingChanged);
  }

  void _onMessagingChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _ensureMessagingStarted() async {
    if (_messagingStarted) return;
    _messagingStarted = true;
    await MessagingController.instance.startForCurrentRole();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(_ensureMessagingStarted());
    final shouldListen = SessionController.instance.currentUser != null;
    if (shouldListen &&
        _notificationSubscription == null &&
        !_notificationStartInFlight) {
      unawaited(_startNotificationStream());
    } else if (!shouldListen && _notificationSubscription != null) {
      unawaited(_stopNotificationStream());
    }
  }

  @override
  void didUpdateWidget(covariant AdaptiveRoleShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final hadRealtimeNotifications = oldWidget.notificationPageBuilder != null;
    final hasRealtimeNotifications = widget.notificationPageBuilder != null;
    if (hadRealtimeNotifications != hasRealtimeNotifications) {
      unawaited(_restartNotificationStream());
    }
    if (oldWidget.roleLabel != widget.roleLabel) {
      _expandedWebGroups.clear();
    }
  }

  Future<void> _startNotificationStream() async {
    if (_notificationStartInFlight) return;
    _notificationStartInFlight = true;
    try {
      unawaited(AppNotificationService.instance.cleanupExpiredNotifications());
      // Seed first so existing unread history never appears as a burst of
      // "new" popups when the staff portal opens.
      final initial =
          await AppNotificationService.instance.fetchMyNotifications(limit: 30);
      if (!mounted) return;
      _onNotificationSnapshot(initial);

      _notificationSubscription = AppNotificationService.instance
          .streamMyNotifications(limit: 30)
          .listen(_onNotificationSnapshot);

      // app_notifications may not be enabled in the Realtime publication on
      // every deployed environment yet. Polling is a catch-up fallback only;
      // Realtime still delivers immediately wherever it is enabled.
      _notificationPollTimer = Timer.periodic(
        const Duration(seconds: 60),
        (_) => unawaited(_pollNotifications()),
      );
    } finally {
      _notificationStartInFlight = false;
    }
  }

  Future<void> _pollNotifications() async {
    if (!mounted) return;
    final latest =
        await AppNotificationService.instance.fetchMyNotifications(limit: 30);
    if (mounted) _onNotificationSnapshot(latest);
  }

  Future<void> _refreshUnreadNotificationCount() async {
    final count =
        await AppNotificationService.instance.fetchMyUnreadCount();
    if (!mounted || count == null) return;
    if (_unreadNotificationCount != count) {
      setState(() => _unreadNotificationCount = count);
    }
  }

  void _onNotificationPageChanged(
    List<AppNotificationItem> notifications,
  ) {
    _seenNotificationIds.addAll(notifications.map((item) => item.id));
    unawaited(_refreshUnreadNotificationCount());
  }

  Future<void> _restartNotificationStream() async {
    await _stopNotificationStream();
    if (!mounted) return;
    if (SessionController.instance.currentUser != null) {
      await _startNotificationStream();
    }
  }

  Future<void> _stopNotificationStream() async {
    _notificationPollTimer?.cancel();
    _notificationPollTimer = null;
    await _notificationSubscription?.cancel();
    _notificationSubscription = null;
    _seenNotificationIds.clear();
    _notificationsSeeded = false;
    if (mounted && _unreadNotificationCount != 0) {
      setState(() => _unreadNotificationCount = 0);
    }
  }

  void _onNotificationSnapshot(List<AppNotificationItem> notifications) {
    if (!mounted) return;
    if (_notificationsSeeded &&
        notifications.isEmpty &&
        _seenNotificationIds.isNotEmpty) {
      // fetchMyNotifications returns an empty list on network errors. Keep the
      // last known badge state instead of briefly pretending everything read.
      return;
    }

    if (!_notificationsSeeded) {
      _seenNotificationIds.addAll(notifications.map((item) => item.id));
      _notificationsSeeded = true;
      unawaited(_refreshUnreadNotificationCount());
      return;
    }

    final fresh = notifications
        .where((item) => !_seenNotificationIds.contains(item.id))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _seenNotificationIds.addAll(notifications.map((item) => item.id));

    unawaited(_refreshUnreadNotificationCount());
    if (fresh.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (fresh.length > 3) {
        _showRealtimeNotificationBatch(fresh.length);
        return;
      }
      for (final item in fresh) {
        _showRealtimeNotification(item);
      }
    });
  }

  NotificationsPage _notificationsPage() => NotificationsPage(
        onOpenNotification: _openNotificationDestination,
        onNotificationsChanged: _onNotificationPageChanged,
      );

  Future<void> _openNotificationDestination(AppNotificationItem item) async {
    final destination = widget.notificationPageBuilder?.call(item);
    if (!mounted || destination == null) return;
    if (CarmeLinkSurfaceScope.isWebPortal(context)) {
      final route = (item.routeType?.trim().isNotEmpty == true
              ? item.routeType!
              : item.notificationType)
          .toLowerCase();
      final label = switch (route) {
        'payment' => 'Payment verification',
        'maintenance' => 'Maintenance',
        'visitor' => 'Visitors',
        'curfew' || 'gate' || 'gate_event' => 'Presence & Curfew',
        'conduct_case' || 'safety' => 'Conduct & Cases',
        'inspection' => 'Room inspections',
        'announcement' => 'Announcements',
        'message' || 'conversation' => 'Messages',
        'onboarding' => 'Residents',
        _ => 'Notification details',
      };
      _openWebWorkspacePage(
        destination,
        label: label,
        group: 'Updates',
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => destination),
    );
  }

  void _showRealtimeNotificationBatch(int count) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        content: Text('$count new CarmeLink updates received.'),
        action: SnackBarAction(
          label: 'View',
          onPressed: _openNotifications,
        ),
      ),
    );
  }

  void _showRealtimeNotification(AppNotificationItem item) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final destination = widget.notificationPageBuilder?.call(item);
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            if (item.body.trim().isNotEmpty)
              Text(
                item.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        action: SnackBarAction(
          label: 'View',
          onPressed: () {
            if (destination != null) {
              unawaited(_openNotificationDestination(item));
            } else {
              _openNotifications();
            }
            if (!item.isRead) {
              unawaited(AppNotificationService.instance.markAsRead(item.id));
            }
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    MessagingController.instance.removeListener(_onMessagingChanged);
    _notificationPollTimer?.cancel();
    unawaited(_notificationSubscription?.cancel());
    super.dispose();
  }

  void _toggleWebGroup(String group) {
    setState(() {
      if (_expandedWebGroups.contains(group)) {
        _expandedWebGroups.remove(group);
      } else {
        _expandedWebGroups.add(group);
      }
    });
  }

  void _select(int value) {
    if (value == index) {
      final navigator = _webWorkspaceNavigatorKey.currentState;
      if (navigator != null && navigator.canPop()) {
        navigator.popUntil((route) => route.isFirst);
      }
      if (_workspaceLabelOverride != null || _workspaceGroupOverride != null) {
        setState(() {
          _workspaceLabelOverride = null;
          _workspaceGroupOverride = null;
        });
      }
      return;
    }
    setState(() {
      index = value;
      _workspaceLabelOverride = null;
      _workspaceGroupOverride = null;
      _webWorkspaceNavigatorKey = GlobalKey<NavigatorState>();
    });
  }

  void _selectByLabel(String label) {
    final webPortal = CarmeLinkSurfaceScope.isWebPortal(context);
    final destinations = webPortal
        ? [...widget.destinations, ...widget.webDestinations]
        : widget.destinations;
    final wanted = label.trim().toLowerCase();
    final target = destinations.indexWhere(
      (item) => item.label.trim().toLowerCase() == wanted,
    );
    if (target >= 0) {
      _select(target);
    }
  }

  void _openWebWorkspacePage(
    Widget page, {
    String? label,
    String? group,
  }) {
    if (label != null && mounted) {
      setState(() {
        _workspaceLabelOverride = label;
        _workspaceGroupOverride = group;
      });
    }
    final navigator = _webWorkspaceNavigatorKey.currentState;
    if (navigator != null) {
      navigator.push(MaterialPageRoute<void>(builder: (_) => page));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  Widget _webWorkspace(Widget page, int activeIndex) {
    return Navigator(
      key: _webWorkspaceNavigatorKey,
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        settings: RouteSettings(name: '/staff/workspace/$activeIndex'),
        builder: (_) => page,
      ),
    );
  }

  Future<void> _openMenu() async {
    final webPortal = CarmeLinkSurfaceScope.isWebPortal(context);
    final menuDestinations = webPortal
        ? [...widget.destinations, ...widget.webDestinations]
        : widget.destinations;

    if (webPortal) {
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Close navigation',
        barrierColor: Colors.black.withValues(alpha: .26),
        transitionDuration: const Duration(milliseconds: 360),
        pageBuilder: (dialogContext, animation, secondaryAnimation) {
          final width = MediaQuery.sizeOf(dialogContext).width;
          final drawerWidth = width < 420 ? width - 24 : 372.0;

          return SafeArea(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: drawerWidth,
                  child: Material(
                    color: Theme.of(dialogContext).colorScheme.surface,
                    elevation: 16,
                    clipBehavior: Clip.antiAlias,
                    borderRadius: BorderRadius.circular(24),
                    child: SingleChildScrollView(
                      child: _RoleMenu(
                        roleLabel: widget.roleLabel,
                        destinations: menuDestinations,
                        currentIndex: index,
                        onOpenMessages: () {
                          Navigator.of(dialogContext).pop();
                          _openMessages();
                        },
                        onOpenNotifications: () {
                          Navigator.of(dialogContext).pop();
                          _openNotifications();
                        },
                        unreadMessageCount:
                            MessagingController.instance.unreadMessageCount,
                        unreadNotificationCount: _unreadNotificationCount,
                        onSelect: (value) {
                          Navigator.of(dialogContext).pop();
                          _select(value);
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(-1.06, 0),
                end: Offset.zero,
              ).animate(curved),
              child: RotationTransition(
                turns: Tween<double>(
                  begin: -.025,
                  end: 0,
                ).animate(curved),
                alignment: Alignment.centerLeft,
                child: child,
              ),
            ),
          );
        },
      );
      return;
    }

    final useSidePanel = MediaQuery.sizeOf(context).width >= 780;

    if (useSidePanel) {
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: .28),
        builder: (dialogContext) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: 360,
                child: Material(
                  color: Theme.of(dialogContext).colorScheme.surface,
                  elevation: 16,
                  clipBehavior: Clip.antiAlias,
                  borderRadius: BorderRadius.circular(24),
                  child: _RoleMenu(
                    roleLabel: widget.roleLabel,
                    destinations: menuDestinations,
                    currentIndex: index,
                    onOpenMessages: () {
                      Navigator.of(dialogContext).pop();
                      _openMessages();
                    },
                    onOpenNotifications: () {
                      Navigator.of(dialogContext).pop();
                      _openNotifications();
                    },
                    unreadMessageCount:
                        MessagingController.instance.unreadMessageCount,
                    unreadNotificationCount: _unreadNotificationCount,
                    onSelect: (value) {
                      Navigator.of(dialogContext).pop();
                      _select(value);
                    },
                  ),
                ),
              ),
            ),
          );
        },
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: .72,
          minChildSize: .46,
          maxChildSize: .92,
          expand: false,
          builder: (context, scrollController) {
            return Material(
              color: Theme.of(sheetContext).colorScheme.surface,
              elevation: 16,
              clipBehavior: Clip.antiAlias,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                child: _RoleMenu(
                  roleLabel: widget.roleLabel,
                  destinations: menuDestinations,
                  currentIndex: index,
                  onOpenMessages: () {
                    Navigator.of(sheetContext).pop();
                    _openMessages();
                  },
                  onOpenNotifications: () {
                    Navigator.of(sheetContext).pop();
                    _openNotifications();
                  },
                  unreadMessageCount:
                      MessagingController.instance.unreadMessageCount,
                  unreadNotificationCount: _unreadNotificationCount,
                  onSelect: (value) {
                    Navigator.of(sheetContext).pop();
                    _select(value);
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openNotifications() {
    if (CarmeLinkSurfaceScope.isWebPortal(context)) {
      _openWebWorkspacePage(
        _notificationsPage(),
        label: 'Notifications',
        group: 'Communication',
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => _notificationsPage()),
    );
  }

  void _openMessages() {
    if (CarmeLinkSurfaceScope.isWebPortal(context)) {
      _openWebWorkspacePage(
        widget.messagePage,
        label: 'Messages',
        group: 'Communication',
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => widget.messagePage),
    );
  }

  @override
  Widget build(BuildContext context) {
    AdaptiveRoleShell.activeMessagePage = widget.messagePage;
    // Mobile keeps the original tab count, even when the browser is resized
    // after selecting a desktop-only management destination.
    final webPortal = CarmeLinkSurfaceScope.isWebPortal(context);
    final desktopWeb = webPortal && MediaQuery.sizeOf(context).width >= 1024;
    final activeDestinations = webPortal
        ? [...widget.destinations, ...widget.webDestinations]
        : widget.destinations;
    final activeIndex = index < activeDestinations.length ? index : 0;
    final unreadMessageCount = MessagingController.instance.unreadMessageCount;
    final destination = activeDestinations[activeIndex];
    final page = RepaintBoundary(
      child: KeyedSubtree(
        key: ValueKey(activeIndex),
        child: destination.page,
      ),
    );

    return CarmelitaNavScope(
      openMenu: _openMenu,
      openMessages: _openMessages,
      openNotifications: _openNotifications,
      unreadMessageCount: unreadMessageCount,
      unreadNotificationCount: _unreadNotificationCount,
      selectIndex: _select,
      selectLabel: _selectByLabel,
      child: Scaffold(
        extendBody: !webPortal,
        body: webPortal
            ? desktopWeb
                ? Row(
                    children: [
                      _WebStaffSidebar(
                        roleLabel: widget.roleLabel,
                        unreadMessageCount: unreadMessageCount,
                        unreadNotificationCount: _unreadNotificationCount,
                        destinations: activeDestinations,
                        mainDestinationCount: widget.destinations.length,
                        selectedIndex: activeIndex,
                        expandedGroups: _expandedWebGroups,
                        onGroupToggle: _toggleWebGroup,
                        onSelected: _select,
                        onOpenMessages: _openMessages,
                        onOpenNotifications: _openNotifications,
                        onOpenPage: (label, page) =>
                            _openWebWorkspacePage(
                          page,
                          label: label,
                          group: 'Account',
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: Column(
                          children: [
                            _WebWorkspaceContextBar(
                              roleLabel: widget.roleLabel,
                              groupLabel: _workspaceGroupOverride ??
                                  destination.webGroup ??
                                  'Workspace',
                              pageLabel:
                                  _workspaceLabelOverride ?? destination.label,
                            ),
                            Expanded(
                              child: _webWorkspace(page, activeIndex),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _CompactWebNavigationBar(
                        roleLabel: widget.roleLabel,
                        unreadMessageCount: unreadMessageCount,
                        unreadNotificationCount: _unreadNotificationCount,
                        onMessages: _openMessages,
                        onNotifications: _openNotifications,
                        onMenu: _openMenu,
                      ),
                      Expanded(child: _webWorkspace(page, activeIndex)),
                    ],
                  )
            : Stack(
                fit: StackFit.expand,
                children: [
                  page,
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _FloatingIslandNavigation(
                      destinations: widget.destinations,
                      selectedIndex: activeIndex,
                      unreadMessageCount: unreadMessageCount,
                      onSelected: _select,
                    ),
                  ),
                ],
              ),
        bottomNavigationBar: null,
      ),
    );
  }
}

class _CompactWebNavigationBar extends StatefulWidget {
  const _CompactWebNavigationBar({
    required this.roleLabel,
    required this.unreadMessageCount,
    required this.unreadNotificationCount,
    required this.onMessages,
    required this.onNotifications,
    required this.onMenu,
  });

  final String roleLabel;
  final int unreadMessageCount;
  final int unreadNotificationCount;
  final VoidCallback onMessages;
  final VoidCallback onNotifications;
  final Future<void> Function() onMenu;

  @override
  State<_CompactWebNavigationBar> createState() =>
      _CompactWebNavigationBarState();
}

class _CompactWebNavigationBarState extends State<_CompactWebNavigationBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _menuController;
  bool _menuOpen = false;

  @override
  void initState() {
    super.initState();
    _menuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 260),
    );
  }

  Future<void> _toggleMenu() async {
    if (_menuOpen) return;

    setState(() => _menuOpen = true);
    await _menuController.forward();

    try {
      await widget.onMenu();
    } finally {
      if (!mounted) return;
      await _menuController.reverse();
      if (mounted) {
        setState(() => _menuOpen = false);
      }
    }
  }

  @override
  void dispose() {
    _menuController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      key: const Key('compact-web-navigation-bar'),
      color: scheme.surface,
      elevation: 0,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: theme.dividerColor),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                key: const Key('web-responsive-hamburger'),
                tooltip: _menuOpen ? 'Close navigation' : 'Open navigation',
                onPressed: _menuOpen ? null : _toggleMenu,
                icon: AnimatedIcon(
                  icon: AnimatedIcons.menu_close,
                  progress: CurvedAnimation(
                    parent: _menuController,
                    curve: Curves.easeInOutCubic,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'CarmeLink',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _CountedIconButton(
                tooltip: 'Messages',
                icon: Icons.chat_bubble_outline,
                unreadCount: widget.unreadMessageCount,
                onPressed: widget.onMessages,
              ),
              _NotificationIconButton(
                unreadCount: widget.unreadNotificationCount,
                onPressed: widget.onNotifications,
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Text(
                  widget.roleLabel,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wide-screen web navigation for the existing OwnerShell/CaretakerShell.
/// The destination list belongs to the mobile role shell, so module access,
/// business logic and unfinished-feature labels cannot drift to demo data.
class _WebWorkspaceContextBar extends StatelessWidget {
  const _WebWorkspaceContextBar({
    required this.roleLabel,
    required this.groupLabel,
    required this.pageLabel,
  });

  final String roleLabel;
  final String groupLabel;
  final String pageLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      key: const Key('web-workspace-context-bar'),
      color: colors.surface,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: theme.dividerColor)),
        ),
        child: Row(
          children: [
            Icon(Icons.workspaces_outline, size: 18, color: colors.primary),
            const SizedBox(width: 9),
            Flexible(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 7,
                runSpacing: 2,
                children: [
                  Text(
                    '$roleLabel workspace',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: colors.outline,
                  ),
                  Text(
                    groupLabel,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: colors.outline,
                  ),
                  Text(
                    pageLabel,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colors.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WebStaffSidebar extends StatelessWidget {
  const _WebStaffSidebar({
    required this.roleLabel,
    required this.unreadMessageCount,
    required this.unreadNotificationCount,
    required this.destinations,
    required this.mainDestinationCount,
    required this.selectedIndex,
    required this.expandedGroups,
    required this.onGroupToggle,
    required this.onSelected,
    required this.onOpenMessages,
    required this.onOpenNotifications,
    required this.onOpenPage,
  });

  final String roleLabel;
  final int unreadMessageCount;
  final int unreadNotificationCount;
  final List<AppDestination> destinations;
  final int mainDestinationCount;
  final int selectedIndex;
  final Set<String> expandedGroups;
  final ValueChanged<String> onGroupToggle;
  final ValueChanged<int> onSelected;
  final VoidCallback onOpenMessages;
  final VoidCallback onOpenNotifications;
  final void Function(String label, Widget page) onOpenPage;

  Map<String, List<int>> get _toolGroups {
    final groups = <String, List<int>>{};
    for (var i = mainDestinationCount; i < destinations.length; i++) {
      final item = destinations[i];
      final group = item.webGroup ?? 'Staff tools';
      groups.putIfAbsent(group, () => <int>[]).add(i);
    }
    return groups;
  }

  String _groupKey(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');

  Widget _destinationTile(BuildContext context, int itemIndex) {
    final item = destinations[itemIndex];
    final selected = itemIndex == selectedIndex;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected
            ? colors.primary.withValues(alpha: .10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          key: Key('web-staff-destination-$itemIndex'),
          dense: true,
          minTileHeight: 46,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          selected: selected,
          selectedColor: colors.primary,
          leading: Icon(
            selected ? item.selectedIcon : item.icon,
            size: 20,
          ),
          title: Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: item.webDescription == null
              ? null
              : Text(
                  item.webDescription!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5),
                ),
          trailing: item.isWorkInProgress ? const _WipBadge() : null,
          onTap: () => onSelected(itemIndex),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final groups = _toolGroups;

    return SizedBox(
      key: const Key('web-staff-sidebar'),
      width: 286,
      child: Material(
        color: colors.surface,
        child: SafeArea(
          right: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 16, 14),
                child: Row(
                  children: [
                    Icon(
                      Icons.apartment_rounded,
                      color: colors.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CarmeLink',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '$roleLabel workspace',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  key: const PageStorageKey<String>('web-staff-navigation'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 5, 12, 8),
                      child: Text(
                        'WORKSPACE',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.primary,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ...List.generate(
                      mainDestinationCount,
                      (index) => _destinationTile(context, index),
                    ),
                    const SizedBox(height: 6),
                    const Divider(height: 16),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 5, 12, 7),
                      child: Text(
                        'MANAGEMENT AREAS',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.primary,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    for (final entry in groups.entries) ...[
                      Builder(
                        builder: (context) {
                          final active = entry.value.contains(selectedIndex);
                          final expanded = expandedGroups.contains(entry.key);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Material(
                                color: active
                                    ? colors.primary.withValues(alpha: .055)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(11),
                                child: InkWell(
                                  key: Key(
                                    'web-staff-group-${_groupKey(entry.key)}',
                                  ),
                                  borderRadius: BorderRadius.circular(11),
                                  onTap: () => onGroupToggle(entry.key),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      11,
                                      9,
                                      8,
                                      9,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            entry.key,
                                            style: theme.textTheme.labelLarge
                                                ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: active
                                                  ? colors.primary
                                                  : null,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${entry.value.length}',
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                            color: colors.onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        AnimatedRotation(
                                          duration: const Duration(
                                            milliseconds: 180,
                                          ),
                                          turns: expanded ? .5 : 0,
                                          child: const Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            size: 20,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              if (expanded)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 8,
                                    top: 4,
                                  ),
                                  child: Column(
                                    children: [
                                      for (final itemIndex in entry.value)
                                        _destinationTile(context, itemIndex),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 4),
                            ],
                          );
                        },
                      ),
                    ],
                    const Divider(height: 22),
                    ListTile(
                      key: const Key('web-staff-messages'),
                      dense: true,
                      leading: _MenuIconWithBadge(
                        icon: Icons.chat_bubble_outline,
                        count: unreadMessageCount,
                      ),
                      title: const Text('Messages'),
                      onTap: onOpenMessages,
                    ),
                    ListTile(
                      key: const Key('web-staff-notifications'),
                      dense: true,
                      leading: _MenuIconWithBadge(
                        icon: Icons.notifications_outlined,
                        count: unreadNotificationCount,
                      ),
                      title: const Text('Notifications'),
                      onTap: onOpenNotifications,
                    ),
                    ListTile(
                      key: const Key('web-staff-settings'),
                      dense: true,
                      leading: const Icon(Icons.settings_outlined),
                      title: const Text('Settings'),
                      onTap: () => onOpenPage(
                        'Settings',
                        const SettingsPage(),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Staff portal · $roleLabel',
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountedIconButton extends StatelessWidget {
  const _CountedIconButton({
    required this.tooltip,
    required this.icon,
    required this.unreadCount,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final int unreadCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            tooltip: tooltip,
            onPressed: onPressed,
            icon: Icon(icon),
          ),
          if (unreadCount > 0)
            Positioned(
              right: 2,
              top: 2,
              child: _UnreadCountBadge(count: unreadCount, compact: true),
            ),
        ],
      );
}

class _NotificationIconButton extends StatelessWidget {
  const _NotificationIconButton({
    required this.unreadCount,
    required this.onPressed,
  });

  final int unreadCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: onPressed,
            icon: const Icon(Icons.notifications_outlined),
          ),
          if (unreadCount > 0)
            Positioned(
              right: 2,
              top: 2,
              child: _UnreadCountBadge(count: unreadCount, compact: true),
            ),
        ],
      );
}

class _MenuIconWithBadge extends StatelessWidget {
  const _MenuIconWithBadge({required this.icon, required this.count});

  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 28,
        height: 28,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 21),
            if (count > 0)
              Positioned(
                right: -4,
                top: -4,
                child: _UnreadCountBadge(count: count, compact: true),
              ),
          ],
        ),
      );
}

class _UnreadCountBadge extends StatelessWidget {
  const _UnreadCountBadge({required this.count, this.compact = false});

  final int count;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: BoxConstraints(
        minWidth: compact ? 16 : 24,
        minHeight: compact ? 16 : 20,
      ),
      padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 7),
      decoration: BoxDecoration(
        color: scheme.error,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: scheme.onError,
          fontSize: compact ? 9 : 11,
          height: 1.2,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _FloatingIslandNavigation extends StatelessWidget {
  const _FloatingIslandNavigation({
    required this.destinations,
    required this.selectedIndex,
    required this.unreadMessageCount,
    required this.onSelected,
  });

  final List<AppDestination> destinations;
  final int selectedIndex;
  final int unreadMessageCount;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontalInset = width < 350 ? 8.0 : 14.0;
    final maxWidth = width >= 700 ? 560.0 : width - (horizontalInset * 2);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return SafeArea(
      top: false,
      minimum: EdgeInsets.fromLTRB(
        horizontalInset,
        0,
        horizontalInset,
        10,
      ),
      child: Center(
        heightFactor: 1,
        child: Container(
          width: maxWidth,
          height: 68,
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.all(
              Radius.circular(30),
            ),
            border: Border.all(color: theme.dividerColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: dark ? .22 : .10,
                ),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: List.generate(
              destinations.length,
              (navIndex) {
                final item = destinations[navIndex];
                final selected = navIndex == selectedIndex;

                return Expanded(
                  child: _IslandItem(
                    label: item.label,
                    icon: item.icon,
                    selectedIcon: item.selectedIcon,
                    selected: selected,
                    isWorkInProgress: item.isWorkInProgress,
                    unreadCount: item.label.toLowerCase() == 'messages'
                        ? unreadMessageCount
                        : 0,
                    onTap: () => onSelected(navIndex),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _IslandItem extends StatelessWidget {
  const _IslandItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
    this.isWorkInProgress = false,
    this.unreadCount = 0,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;
  final bool isWorkInProgress;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        borderRadius: const BorderRadius.all(
          Radius.circular(22),
        ),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(
            minWidth: 48,
            minHeight: 48,
          ),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: .12)
                : Colors.transparent,
            borderRadius: const BorderRadius.all(
              Radius.circular(22),
            ),
          ),
          alignment: Alignment.center,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  selected ? selectedIcon : icon,
                  key: ValueKey(selected),
                  size: 23,
                  color: selected
                      ? scheme.primary
                      : scheme.onSurface.withValues(alpha: .56),
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: -9,
                    top: -8,
                    child: _UnreadCountBadge(
                      count: unreadCount,
                      compact: true,
                    ),
                  ),
                if (isWorkInProgress)
                  Positioned(
                    right: -16,
                    top: -9,
                    child: _WipBadge(compact: true),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleMenu extends StatelessWidget {
  const _RoleMenu({
    required this.roleLabel,
    required this.destinations,
    required this.currentIndex,
    required this.onOpenMessages,
    required this.onOpenNotifications,
    required this.unreadMessageCount,
    required this.unreadNotificationCount,
    required this.onSelect,
  });

  final String roleLabel;
  final List<AppDestination> destinations;
  final int currentIndex;
  final VoidCallback onOpenMessages;
  final VoidCallback onOpenNotifications;
  final int unreadMessageCount;
  final int unreadNotificationCount;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final user = SessionController.instance.currentUser;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        18,
        20,
        26,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: const BorderRadius.all(
                  Radius.circular(999),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const CarmelitaLogo(height: 52),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CarmeLink',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontFamily: 'GreatVibes',
                            fontWeight: FontWeight.w600,
                            fontSize: 24,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      roleLabel,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (user != null) ...[
            const SizedBox(height: 18),
            CarmelitaCard(
              emphasis: true,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    child: Text(
                      user.name.substring(0, 1),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          user.email,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          Text(
            'MAIN',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 8),
          ...List.generate(
            destinations.length,
            (navIndex) {
              final item = destinations[navIndex];
              final selected = navIndex == currentIndex;
              return ListTile(
                selected: selected,
                minTileHeight: 54,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                tileColor: selected
                    ? Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: .08)
                    : null,
                leading: Icon(
                  selected ? item.selectedIcon : item.icon,
                  color:
                      selected ? Theme.of(context).colorScheme.primary : null,
                ),
                title: Text(item.label),
                trailing: item.isWorkInProgress
                    ? const _WipBadge()
                    : const Icon(Icons.chevron_right_rounded),
                onTap: () => onSelect(navIndex),
              );
            },
          ),
          const SizedBox(height: 10),
          const Divider(),
          ListTile(
            minTileHeight: 54,
            leading: _MenuIconWithBadge(
              icon: Icons.chat_bubble_outline,
              count: unreadMessageCount,
            ),
            title: const Text('Messages'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onOpenMessages,
          ),
          ListTile(
            minTileHeight: 54,
            leading: _MenuIconWithBadge(
              icon: Icons.notifications_outlined,
              count: unreadNotificationCount,
            ),
            title: const Text('Notifications'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onOpenNotifications,
          ),
          ListTile(
            minTileHeight: 54,
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SettingsPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WipBadge extends StatelessWidget {
  const _WipBadge({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 3 : 7,
          vertical: compact ? 1 : 3,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'WIP',
          style: TextStyle(
            fontSize: compact ? 7 : 10,
            fontWeight: FontWeight.w900,
            letterSpacing: .3,
            color: Theme.of(context).colorScheme.onTertiaryContainer,
          ),
        ),
      );
}
