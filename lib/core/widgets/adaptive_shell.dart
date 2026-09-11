import 'dart:ui';

import 'package:flutter/material.dart';

import '../../controllers/session_controller.dart';
import '../../views/shared/shared_views.dart';
import 'common_widgets.dart';

class AppDestination {
  const AppDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.page,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;
}

class CarmelitaNavScope extends InheritedWidget {
  const CarmelitaNavScope({
    required this.openMenu,
    this.openMessages,
    required this.selectIndex,
    required super.child,
    super.key,
  });

  final VoidCallback openMenu;
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
    super.key,
  });

  final List<AppDestination> destinations;
  final String roleLabel;
  final Widget messagePage;

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

  void _openMenu() {
    final useSidePanel = MediaQuery.sizeOf(context).width >= 780;

    if (useSidePanel) {
      showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: .28),
        builder: (dialogContext) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.all(
                  Radius.circular(28),
                ),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  width: 360,
                  child: _RoleMenu(
                    roleLabel: widget.roleLabel,
                    destinations: widget.destinations,
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

    showModalBottomSheet<void>(
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
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                controller: scrollController,
                child: _RoleMenu(
                  roleLabel: widget.roleLabel,
                  destinations: widget.destinations,
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
    final destination = widget.destinations[index];

    return CarmelitaNavScope(
      openMenu: _openMenu,
      openMessages: _openMessages,
      selectIndex: _select,
      child: Scaffold(
        extendBody: true,
        body: RepaintBoundary(
          child: KeyedSubtree(
            key: ValueKey(index),
            child: destination.page,
          ),
        ),
        bottomNavigationBar: _FloatingIslandNavigation(
          destinations: widget.destinations,
          selectedIndex: index,
          onSelected: _select,
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
    final dark = Theme.of(context).brightness == Brightness.dark;

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
        child: SizedBox(
          width: maxWidth,
          height: 68,
          child: ClipRRect(
            borderRadius: const BorderRadius.all(
              Radius.circular(30),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 7,
                sigmaY: 7,
              ),
              child: Container(
                width: maxWidth,
                height: 68,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: dark
                      ? const Color(0xFF221E1A).withValues(alpha: .94)
                      : Colors.white.withValues(alpha: .94),
                  borderRadius: const BorderRadius.all(
                    Radius.circular(30),
                  ),
                  border: Border.all(
                    color:
                        Theme.of(context).dividerColor.withValues(alpha: .90),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: dark ? .22 : .09,
                      ),
                      blurRadius: 28,
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
                          onTap: () => onSelected(navIndex),
                        ),
                      );
                    },
                  ),
                ),
              ),
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
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;

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
            child: Icon(
              selected ? selectedIcon : icon,
              key: ValueKey(selected),
              size: 23,
              color: selected
                  ? scheme.primary
                  : scheme.onSurface.withValues(alpha: .56),
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
                trailing: const Icon(Icons.chevron_right_rounded),
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
