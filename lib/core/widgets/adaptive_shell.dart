import 'package:flutter/material.dart';

import '../../controllers/session_controller.dart';
import '../../views/shared/shared_views.dart';
import 'common_widgets.dart';

import '../runtime/app_surface.dart';

class AppDestination {
  const AppDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.page,
    this.isWorkInProgress = false,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;
  final bool isWorkInProgress;
}

class CarmelitaNavScope extends InheritedWidget {
  const CarmelitaNavScope({
    required this.openMenu,
    this.openMessages,
    required this.selectIndex,
    required super.child,
    super.key,
  });

  final Future<void> Function() openMenu;
  final VoidCallback? openMessages;
  final ValueChanged<int> selectIndex;

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
        selectIndex != oldWidget.selectIndex;
  }
}

class AdaptiveRoleShell extends StatefulWidget {
  const AdaptiveRoleShell({
    required this.destinations,
    required this.roleLabel,
    required this.messagePage,
    this.webDestinations = const [],
    super.key,
  });

  final List<AppDestination> destinations;
  final String roleLabel;
  final Widget messagePage;

  /// Extra desktop-only navigation to existing role-authorized pages.
  /// Mobile destinations and the in-app backend services stay unchanged.
  final List<AppDestination> webDestinations;

  static Widget? activeMessagePage;

  static void openActiveMessages(BuildContext context) {
    final page = activeMessagePage;
    if (page == null) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  State<AdaptiveRoleShell> createState() => _AdaptiveRoleShellState();
}

class _AdaptiveRoleShellState extends State<AdaptiveRoleShell> {
  int index = 0;

  void _select(int value) {
    if (value == index) return;
    setState(() => index = value);
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

  void _openMessages() {
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
    final desktopWeb = webPortal && MediaQuery.sizeOf(context).width >= 1200;
    final activeDestinations = webPortal
        ? [...widget.destinations, ...widget.webDestinations]
        : widget.destinations;
    final activeIndex = index < activeDestinations.length ? index : 0;
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
      selectIndex: _select,
      child: Scaffold(
        extendBody: !webPortal,
        body: webPortal
            ? desktopWeb
                ? Row(
                    children: [
                      _WebStaffSidebar(
                        roleLabel: widget.roleLabel,
                        destinations: activeDestinations,
                        mainDestinationCount: widget.destinations.length,
                        selectedIndex: activeIndex,
                        onSelected: _select,
                        onOpenMessages: _openMessages,
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: page),
                    ],
                  )
                : Column(
                    children: [
                      _CompactWebNavigationBar(
                        roleLabel: widget.roleLabel,
                        onMenu: _openMenu,
                      ),
                      Expanded(child: page),
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
    required this.onMenu,
  });

  final String roleLabel;
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
class _WebStaffSidebar extends StatelessWidget {
  const _WebStaffSidebar({
    required this.roleLabel,
    required this.destinations,
    required this.mainDestinationCount,
    required this.selectedIndex,
    required this.onSelected,
    required this.onOpenMessages,
  });

  final String roleLabel;
  final List<AppDestination> destinations;
  final int mainDestinationCount;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onOpenMessages;

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SizedBox(
      key: const Key('web-staff-sidebar'),
      width: 248,
      child: Material(
        color: colors.surface,
        child: SafeArea(
          right: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 16, 16),
                child: Row(
                  children: [
                    Icon(Icons.apartment_rounded,
                        color: colors.primary, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CarmeLink',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              )),
                          Text('$roleLabel workspace',
                              style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  key: const Key('web-staff-navigation'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 5, 12, 10),
                      child: Text('MANAGEMENT',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.primary,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.bold,
                          )),
                    ),
                    ...List.generate(destinations.length, (itemIndex) {
                      final item = destinations[itemIndex];
                      final selected = itemIndex == selectedIndex;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (itemIndex == mainDestinationCount)
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(12, 14, 12, 10),
                              child: Text('STAFF TOOLS',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colors.primary,
                                    letterSpacing: 1.4,
                                    fontWeight: FontWeight.bold,
                                  )),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Material(
                              color: selected
                                  ? colors.primary.withValues(alpha: .10)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              child: ListTile(
                                key: Key('web-staff-destination-$itemIndex'),
                                dense: true,
                                minTileHeight: 48,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                selected: selected,
                                selectedColor: colors.primary,
                                leading: Icon(
                                  selected ? item.selectedIcon : item.icon,
                                  size: 21,
                                ),
                                title: Text(item.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                trailing: item.isWorkInProgress
                                    ? const _WipBadge()
                                    : null,
                                onTap: () => onSelected(itemIndex),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                    const Divider(height: 24),
                    ListTile(
                      key: const Key('web-staff-messages'),
                      dense: true,
                      leading: const Icon(Icons.chat_bubble_outline),
                      title: const Text('Messages'),
                      onTap: onOpenMessages,
                    ),
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.notifications_outlined),
                      title: const Text('Notifications'),
                      onTap: () => _open(context, const NotificationsPage()),
                    ),
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.settings_outlined),
                      title: const Text('Settings'),
                      onTap: () => _open(context, const SettingsPage()),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Staff portal · $roleLabel',
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FloatingIslandNavigation extends StatelessWidget {
  const _FloatingIslandNavigation({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<AppDestination> destinations;
  final int selectedIndex;
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
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;
  final bool isWorkInProgress;

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
    required this.onSelect,
  });

  final String roleLabel;
  final List<AppDestination> destinations;
  final int currentIndex;
  final VoidCallback onOpenMessages;
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
            leading: const Icon(Icons.chat_bubble_outline),
            title: const Text('Messages'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onOpenMessages,
          ),
          ListTile(
            minTileHeight: 54,
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notifications'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const NotificationsPage(),
                ),
              );
            },
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
