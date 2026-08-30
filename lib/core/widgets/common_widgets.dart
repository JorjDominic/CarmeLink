import 'package:flutter/material.dart';

import '../../controllers/session_controller.dart';
import '../../data/mock_data.dart';
import '../../models/models.dart';
import '../constants/app_assets.dart';
import '../constants/app_colors.dart';
import '../responsive/breakpoints.dart';
import '../theme/app_theme.dart';
import 'adaptive_shell.dart';

Color mutedAccentForIcon(BuildContext context, IconData icon) {
  if (icon == Icons.payments_outlined ||
      icon == Icons.receipt_long_outlined ||
      icon == Icons.account_balance_wallet_outlined) {
    return const Color(0xFFAA8A45);
  }
  if (icon == Icons.warning_amber_outlined ||
      icon == Icons.priority_high_rounded ||
      icon == Icons.emergency_outlined) {
    return const Color(0xFFAA6870);
  }
  if (icon == Icons.build_outlined ||
      icon == Icons.handyman_outlined ||
      icon == Icons.tune_outlined) {
    return const Color(0xFFB47A52);
  }
  if (icon == Icons.shield_outlined ||
      icon == Icons.schedule_outlined ||
      icon == Icons.gavel_outlined) {
    return const Color(0xFF7D70A0);
  }
  if (icon == Icons.person_outline ||
      icon == Icons.groups_outlined ||
      icon == Icons.bed_outlined ||
      icon == Icons.home_outlined) {
    return const Color(0xFF56886B);
  }
  if (icon == Icons.sensor_door_outlined ||
      icon == Icons.videocam_outlined ||
      icon == Icons.memory_outlined ||
      icon == Icons.timeline_outlined) {
    return const Color(0xFF568F8E);
  }
  return const Color(0xFF627FA8);
}

class CarmelitaLogo extends StatelessWidget {
  const CarmelitaLogo({
    this.height = 56,
    super.key,
  });

  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Colors.white),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Image.asset(
              AppAssets.logo,
              height: height,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

class MutedDashboardItem {
  const MutedDashboardItem(
      {required this.label,
      required this.value,
      required this.detail,
      required this.icon,
      required this.color,
      this.onTap});
  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
}

class MutedDashboardGrid extends StatelessWidget {
  const MutedDashboardGrid(
      {required this.items,
      this.compact = false,
      this.denseFourColumn = false,
      super.key});
  final List<MutedDashboardItem> items;
  final bool compact;
  final bool denseFourColumn;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final columns = denseFourColumn
            ? items.length.clamp(1, 4)
            : constraints.maxWidth < 600
                ? (constraints.maxWidth < 320 ? 1 : 2)
                : items.length.clamp(2, 4);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: compact
                ? (constraints.maxWidth < 500 ? 1.45 : 1.7)
                : denseFourColumn && constraints.maxWidth < 500
                    ? .65
                    : constraints.maxWidth < 500
                        ? 1.05
                        : 1.15,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return InkWell(
              onTap: item.onTap,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: EdgeInsets.all(compact ? 8 : 10),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: .035),
                  border: Border.all(color: item.color.withValues(alpha: .10)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          padding: EdgeInsets.all(compact ? 5 : 7),
                          decoration: BoxDecoration(
                              color: item.color.withValues(alpha: .09),
                              borderRadius: BorderRadius.circular(9)),
                          child: Icon(item.icon,
                              color: item.color, size: compact ? 18 : 19)),
                      const Spacer(),
                      Text(item.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                  color: item.color,
                                  fontWeight: FontWeight.w900,
                                  fontSize: compact ? 19 : 17)),
                      const SizedBox(height: 2),
                      Text(item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                  fontSize: compact ? 12 : 10,
                                  fontWeight: FontWeight.w800)),
                      Text(item.detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontSize: compact ? 11 : 9)),
                    ]),
              ),
            );
          },
        );
      });
}

class MutedActionItem {
  const MutedActionItem(
      {required this.label,
      required this.detail,
      required this.icon,
      required this.color,
      required this.onTap});
  final String label;
  final String detail;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class MutedActionGrid extends StatelessWidget {
  const MutedActionGrid({required this.items, super.key});
  final List<MutedActionItem> items;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: constraints.maxWidth < 520 ? 2.15 : 2.8),
          itemBuilder: (context, index) {
            final item = items[index];
            return CarmelitaCard(
              onTap: item.onTap,
              padding: const EdgeInsets.all(10),
              child: Row(children: [
                Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                        color: item.color.withValues(alpha: .075),
                        borderRadius: BorderRadius.circular(11)),
                    child: Icon(item.icon, color: item.color, size: 21)),
                const SizedBox(width: 9),
                Expanded(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(item.detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontSize: 10)),
                    ])),
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: Theme.of(context).colorScheme.outline),
              ]),
            );
          },
        );
      });
}

class PageFrame extends StatelessWidget {
  const PageFrame({
    required this.title,
    required this.child,
    this.subtitle,
    this.actions,
    this.floatingActionButton,
    this.heroTitle,
    this.useScriptTitle = true,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? heroTitle;
  final bool useScriptTitle;
  final Widget child;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final navScope = CarmelitaNavScope.maybeOf(context);
    final canPop = Navigator.of(context).canPop();
    final extraBottom = navScope == null ? 24.0 : 132.0;
    final isOwner =
        SessionController.instance.currentUser?.role == UserRole.ownerCaretaker;
    final ownerOperationalPage = isOwner && title != 'Dashboard';
    final canShowNotifications =
        SessionController.instance.currentUser != null &&
            title.toLowerCase() != 'notifications';
    final canShowMessages = (navScope != null ||
            (isOwner && AdaptiveRoleShell.activeMessagePage != null)) &&
        title.toLowerCase() != 'messages';
    final ownerSection = isOwner &&
        title != 'Dashboard' &&
        title != 'Operations' &&
        title != 'Profile' &&
        title != 'Notifications';
    final pageChild = ownerSection
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'OWNER / CARETAKER',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 1.25,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 10),
              if (subtitle != null) ...[
                Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 14),
              ],
              child,
            ],
          )
        : child;

    void openNotifications() => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const _GlobalNotificationsPage()),
        );

    void openMessages() {
      if (navScope?.openMessages != null) {
        navScope!.openMessages!.call();
      } else {
        AdaptiveRoleShell.openActiveMessages(context);
      }
    }

    final messageButton = IconButton(
      tooltip: 'Messages',
      onPressed: openMessages,
      icon: const Icon(Icons.chat_bubble_outline),
    );

    final notificationButton = IconButton(
      tooltip: 'Notifications',
      onPressed: openNotifications,
      icon: const Icon(Icons.notifications_outlined),
    );

    Widget? resolvedFloatingActionButton = floatingActionButton;
    if (resolvedFloatingActionButton != null && navScope != null) {
      resolvedFloatingActionButton = Padding(
        padding: const EdgeInsets.only(bottom: 82),
        child: resolvedFloatingActionButton,
      );
    }

    return _PageEntrance(
      enabled: !canPop,
      child: Scaffold(
        extendBody: navScope != null,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          toolbarHeight: 72,
          leadingWidth: 68,
          leading: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: IconButton(
              tooltip: navScope != null
                  ? 'Menu'
                  : canPop
                      ? 'Back'
                      : 'Menu',
              onPressed: () {
                if (navScope != null) {
                  navScope.openMenu();
                } else if (canPop) {
                  Navigator.of(context).maybePop();
                }
              },
              icon: Icon(
                navScope != null
                    ? Icons.menu_rounded
                    : Icons.arrow_back_ios_new_rounded,
              ),
            ),
          ),
          titleSpacing: 4,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                heroTitle ?? title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontFamily: useScriptTitle ? 'GreatVibes' : null,
                      fontSize: useScriptTitle ? 30 : null,
                      fontWeight:
                          useScriptTitle ? FontWeight.w600 : FontWeight.w700,
                    ),
              ),
              if (subtitle != null && !ownerOperationalPage)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
          actions: [
            ...?actions,
            if (canShowMessages) messageButton,
            if (canShowNotifications) notificationButton,
            const SizedBox(width: 10),
          ],
        ),
        floatingActionButton: resolvedFloatingActionButton,
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ResponsiveContent(
              padding: EdgeInsets.fromLTRB(
                AppBreakpoints.horizontalPadding(context),
                6,
                AppBreakpoints.horizontalPadding(context),
                extraBottom,
              ),
              child: RepaintBoundary(child: pageChild),
            ),
          ),
        ),
      ),
    );
  }
}

class _PageEntrance extends StatefulWidget {
  const _PageEntrance({required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;

  @override
  State<_PageEntrance> createState() => _PageEntranceState();
}

class _PageEntranceState extends State<_PageEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  late final Animation<double> opacity;
  late final Animation<Offset> position;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    final curve = CurvedAnimation(
      parent: controller,
      curve: Curves.easeOutCubic,
    );
    opacity = CurvedAnimation(
      parent: controller,
      curve: const Interval(0, .72, curve: Curves.easeOut),
    );
    position = Tween<Offset>(
      begin: const Offset(0, .055),
      end: Offset.zero,
    ).animate(curve);
    controller.forward();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }
    return FadeTransition(
      opacity: opacity,
      child: SlideTransition(
        position: position,
        child: widget.child,
      ),
    );
  }
}

class _GlobalNotificationsPage extends StatelessWidget {
  const _GlobalNotificationsPage();

  int _urgency(String type) => type == 'Gate'
      ? 3
      : type == 'Payment'
          ? 2
          : 1;

  @override
  Widget build(BuildContext context) {
    final ranked = [...MockData.notifications]
      ..sort((a, b) => _urgency(b.type).compareTo(_urgency(a.type)));
    return PageFrame(
      title: 'Notifications',
      subtitle: 'Updates ranked by urgency',
      child: CarmelitaCard(
        child: Column(
          children: ranked
              .map((notification) => TimelineTile(
                    icon: notification.type == 'Payment'
                        ? Icons.payments_outlined
                        : notification.type == 'Gate'
                            ? Icons.sensor_door_outlined
                            : Icons.build_outlined,
                    title: notification.title,
                    subtitle:
                        '${notification.body}\n${shortDate(notification.time)} • ${timeText(notification.time)}',
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class CarmelitaCard extends StatelessWidget {
  const CarmelitaCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.emphasis = false,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CarmelitaThemeExtension>();
    final scheme = Theme.of(context).colorScheme;

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 190),
      curve: Curves.easeOutCubic,
      padding: padding,
      decoration: BoxDecoration(
        color:
            emphasis ? scheme.primary.withValues(alpha: .075) : scheme.surface,
        borderRadius: const BorderRadius.all(
          Radius.circular(20),
        ),
        border: Border.all(
          color: emphasis
              ? scheme.primary.withValues(alpha: .22)
              : ext?.border ?? Theme.of(context).dividerColor,
        ),
        boxShadow: Theme.of(context).brightness == Brightness.light
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .032),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: child,
    );

    if (onTap == null) return content;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 1, end: 1),
      duration: const Duration(milliseconds: 120),
      builder: (context, value, _) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: const BorderRadius.all(
              Radius.circular(20),
            ),
            onTap: onTap,
            child: content,
          ),
        );
      },
    );
  }
}

class ElegantHeader extends StatelessWidget {
  const ElegantHeader({
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.trailing,
    this.useScriptTitle = true,
    super.key,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool useScriptTitle;

  Widget _copy(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final titleSize = width < 350 ? 29.0 : 34.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.3,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontFamily: useScriptTitle ? 'GreatVibes' : null,
                fontSize: useScriptTitle ? titleSize + 10 : titleSize,
                fontWeight: useScriptTitle ? FontWeight.w600 : FontWeight.w700,
                height: useScriptTitle ? 1.15 : null,
                letterSpacing: useScriptTitle ? 0 : null,
              ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (trailing == null) {
      return _copy(context);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 360) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: trailing!,
              ),
              const SizedBox(height: 12),
              _copy(context),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _copy(context)),
            const SizedBox(width: 12),
            Flexible(
              flex: 0,
              child: trailing!,
            ),
          ],
        );
      },
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(
    this.title, {
    this.trailing,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(
    this.text, {
    this.icon,
    super.key,
  });

  final String text;
  final IconData? icon;

  Color _color() {
    final value = text.toLowerCase();
    if (value.contains('verified') ||
        value.contains('approved') ||
        value.contains('online') ||
        value.contains('locked') ||
        value == 'in' ||
        value == 'clear' ||
        value.contains('resolved')) {
      return AppColors.success;
    }
    if (value.contains('reject') ||
        value.contains('late') ||
        value.contains('offline') ||
        value.contains('alert') ||
        value.contains('escalated')) {
      return AppColors.danger;
    }
    if (value.contains('pending') ||
        value.contains('ongoing') ||
        value.contains('review') ||
        value.contains('waiting') ||
        value.contains('due') ||
        value.contains('submitted')) {
      return AppColors.warning;
    }
    return AppColors.info;
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 138),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .105),
          borderRadius: const BorderRadius.all(
            Radius.circular(999),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 11.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.detail,
    this.onTap,
    this.highlight = false,
    this.color,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? detail;
  final VoidCallback? onTap;
  final bool highlight;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return CarmelitaCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      emphasis: highlight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final veryNarrow = constraints.maxWidth < 145;
          final iconSize = veryNarrow ? 40.0 : 44.0;

          final accent = color ?? mutedAccentForIcon(context, icon);
          final iconBox = Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .075),
              borderRadius: const BorderRadius.all(
                Radius.circular(14),
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: veryNarrow ? 19 : 21,
              color: accent,
            ),
          );

          final copy = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: veryNarrow ? 18 : 21,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              if (detail != null) ...[
                const SizedBox(height: 4),
                Text(
                  detail!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          );

          if (veryNarrow) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    iconBox,
                    const Spacer(),
                    if (onTap != null)
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 13,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: .30),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                copy,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              iconBox,
              const SizedBox(width: 12),
              Expanded(child: copy),
              if (onTap != null) ...[
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(top: 15),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: .30),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class QuickAction extends StatelessWidget {
  const QuickAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? mutedAccentForIcon(context, icon);
    return CarmelitaCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 14,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .075),
              borderRadius: const BorderRadius.all(
                Radius.circular(14),
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 20,
              color: accent,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 11.5,
                  height: 1.18,
                ),
          ),
        ],
      ),
    );
  }
}

class AdaptiveGrid extends StatelessWidget {
  const AdaptiveGrid({
    required this.children,
    this.minTileWidth = 220,
    super.key,
  });

  final List<Widget> children;
  final double minTileWidth;

  int _columnsFor(double width) {
    if (width < 320) return 1;
    if (width < 600) return 2;

    const spacing = 12.0;
    final estimated = ((width + spacing) / (minTileWidth + spacing)).floor();
    return estimated.clamp(2, 4);
  }

  @override
  Widget build(BuildContext context) {
    const spacing = 12.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnsFor(constraints.maxWidth);
        final itemWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          alignment: WrapAlignment.start,
          children: children
              .map(
                (child) => SizedBox(
                  width: itemWidth,
                  child: child,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class ActionGrid extends StatelessWidget {
  const ActionGrid({
    required this.children,
    super.key,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    const spacing = 10.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width < 330
            ? 2
            : width < 700
                ? 4
                : 6;
        final itemWidth = (width - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children
              .map(
                (child) => SizedBox(
                  width: itemWidth,
                  child: child,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class PhotoHero extends StatelessWidget {
  const PhotoHero({
    required this.image,
    required this.title,
    required this.subtitle,
    this.height = 210,
    super.key,
  });

  final String image;
  final String title;
  final String subtitle;
  final double height;

  @override
  Widget build(BuildContext context) {
    final effectiveHeight = AppBreakpoints.isPhone(context)
        ? height.clamp(180, 250).toDouble()
        : height.clamp(220, 320).toDouble();

    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(26)),
      child: SizedBox(
        height: effectiveHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(image, fit: BoxFit.cover),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: .76),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
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

class AttentionCard extends StatelessWidget {
  const AttentionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.status,
    this.onTap,
    this.compact = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? status;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accent = mutedAccentForIcon(context, icon);
    return CarmelitaCard(
      onTap: onTap,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 9 : 14,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stackStatus = constraints.maxWidth < 320;
          final iconSize = compact ? 36.0 : 44.0;

          final leading = Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .075),
              borderRadius: BorderRadius.circular(compact ? 12 : 15),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: accent,
              size: compact ? 19 : 24,
            ),
          );

          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: compact
                    ? Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        )
                    : Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: compact ? 2 : 4),
              Text(
                subtitle,
                style: compact
                    ? Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          height: 1.25,
                        )
                    : Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          );

          if (stackStatus && status != null) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                leading,
                SizedBox(width: compact ? 9 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      copy,
                      SizedBox(height: compact ? 7 : 10),
                      StatusPill(status!),
                    ],
                  ),
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              leading,
              SizedBox(width: compact ? 9 : 13),
              Expanded(child: copy),
              if (status != null) ...[
                SizedBox(width: compact ? 7 : 10),
                StatusPill(status!),
              ] else if (onTap != null) ...[
                const SizedBox(width: 8),
                const Padding(
                  padding: EdgeInsets.only(top: 13),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class ConversationListCard extends StatelessWidget {
  const ConversationListCard({
    required this.name,
    required this.role,
    required this.lastMessage,
    required this.onTap,
    super.key,
  });

  final String name;
  final String role;
  final ChatMessage lastMessage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CarmelitaCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          radius: 22,
          backgroundColor:
              Theme.of(context).colorScheme.primary.withValues(alpha: .10),
          foregroundColor: Theme.of(context).colorScheme.primary,
          child: Text(
            name.substring(0, 1).toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              timeText(lastMessage.sentAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        subtitle: Text(
          '$role • ${lastMessage.body}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow({
    required this.label,
    required this.value,
    this.icon,
    super.key,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 370;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (icon != null) ...[
                      Icon(
                        icon,
                        size: 18,
                        color: mutedAccentForIcon(context, icon!),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 19,
                    color: mutedAccentForIcon(context, icon!),
                  ),
                  const SizedBox(width: 10),
                ],
                SizedBox(
                  width: 118,
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class TimelineTile extends StatelessWidget {
  const TimelineTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.color,
    this.compact = true,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final Color? color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? mutedAccentForIcon(context, icon);
    return ListTile(
      dense: compact,
      visualDensity: compact ? const VisualDensity(vertical: -3) : null,
      minLeadingWidth: compact ? 36 : null,
      contentPadding: EdgeInsets.symmetric(
        horizontal: compact ? 0 : 2,
        vertical: compact ? 0 : 3,
      ),
      leading: Container(
        width: compact ? 36 : 42,
        height: compact ? 36 : 42,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: .075),
          borderRadius: const BorderRadius.all(Radius.circular(14)),
        ),
        child: Icon(
          icon,
          size: compact ? 18 : 21,
          color: accent,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: compact ? 12.5 : null,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: compact ? const TextStyle(fontSize: 11) : null,
      ),
      trailing: trailing,
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final accent = mutedAccentForIcon(context, icon);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 42),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .075),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 34,
                color: accent,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

void showAppSnackBar(
  BuildContext context,
  String message,
) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

String money(double value) => '₱${value.toStringAsFixed(0)}';

String shortDate(DateTime value) => '${value.month}/${value.day}/${value.year}';

String timeText(DateTime value) {
  final hour =
      value.hour == 0 ? 12 : (value.hour > 12 ? value.hour - 12 : value.hour);
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${value.hour >= 12 ? 'PM' : 'AM'}';
}
