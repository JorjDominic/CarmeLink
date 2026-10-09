import 'dart:async';

import 'package:flutter/material.dart';

import '../../controllers/session_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../core/constants/app_assets.dart';
import '../../core/runtime/app_surface.dart';
import '../../core/widgets/adaptive_shell.dart';
import '../../core/widgets/common_widgets.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/geofence_service.dart';
import '../../services/guardian_alert_service.dart';
import '../../services/profile_service.dart';
import '../../services/app_notification_service.dart';
import '../../services/onboarding_invitation_service.dart';
import '../../services/contract_onboarding_service.dart';
import 'package:carmelitas_dormitory_system/views/shared/retention_settings_page.dart';
import '../tenant/onboarding_form_page.dart';
import '../tenant/tenant_requirements_page.dart';
import 'profile_edit_page.dart';
import 'move_out_settlement_page.dart';
import 'signature_pad_dialog.dart';
import 'notification_destination.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
    super.key,
    this.onOpenNotification,
    this.onNotificationsChanged,
    this.service,
  });

  final Future<void> Function(AppNotificationItem notification)?
      onOpenNotification;
  final ValueChanged<List<AppNotificationItem>>? onNotificationsChanged;
  final AppNotificationService? service;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  static const int _pageSize = 15;

  AppNotificationService get _service =>
      widget.service ?? AppNotificationService.instance;
  StreamSubscription<List<AppNotificationItem>>? _subscription;
  Timer? _pollTimer;
  List<AppNotificationItem> _notifications = const [];
  bool _loading = true;
  bool _refreshing = false;
  bool _loadingMore = false;
  bool _markingAllRead = false;
  bool _hasMore = false;
  int? _serverUnreadCount;
  int _unreadCountRevision = 0;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    unawaited(_service.cleanupExpiredNotifications());
    await _loadInitial();
    if (!mounted) return;

    _subscription = _service.streamMyNotifications(limit: 30).listen(
          _applyRealtimeSnapshot,
          onError: (_) {},
        );

    // Realtime is primary. This is only a catch-up fallback for deployments
    // where the realtime publication is temporarily unavailable.
    _pollTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => unawaited(_refreshLatest()),
    );
  }

  Future<void> _loadInitial() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final latest = await _service.fetchMyNotificationsPage(limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _notifications = latest;
        _hasMore = latest.length == _pageSize;
        _loading = false;
        _errorText = null;
      });
      _notifySnapshot();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorText =
            'Could not refresh notifications. Check your connection and try again.';
      });
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _refreshLatest() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final latest = await _service.fetchMyNotificationsPage(limit: _pageSize);
      if (!mounted) return;
      _mergeLatest(latest);
    } catch (_) {
      // Keep the last known list during background catch-up failures.
    } finally {
      _refreshing = false;
    }
  }

  void _mergeLatest(List<AppNotificationItem> latest) {
    final byId = <String, AppNotificationItem>{
      for (final item in _notifications) item.id: item,
      for (final item in latest) item.id: item,
    };
    final merged = byId.values.toList()..sort(compareNotificationsNewestFirst);
    setState(() {
      _notifications = List<AppNotificationItem>.unmodifiable(merged);
      _loading = false;
      _errorText = null;
      if (merged.length <= _pageSize) {
        _hasMore = latest.length == _pageSize;
      }
    });
    _notifySnapshot();
  }

  void _applyRealtimeSnapshot(List<AppNotificationItem> latest) {
    if (!mounted) return;
    _mergeLatest(latest);
  }

  Future<void> _loadPrevious() async {
    if (_loadingMore || !_hasMore || _notifications.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final older = await _service.fetchMyNotificationsPage(
        limit: _pageSize,
        before: _notifications.last.createdAt,
        beforeId: _notifications.last.id,
      );
      if (!mounted) return;
      final existingIds = _notifications.map((item) => item.id).toSet();
      final uniqueOlder = older
          .where((item) => !existingIds.contains(item.id))
          .toList(growable: false);
      setState(() {
        _notifications = List<AppNotificationItem>.unmodifiable(
          [..._notifications, ...uniqueOlder],
        );
        _hasMore = older.length == _pageSize;
      });
      _notifySnapshot();
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'Could not load previous notifications.');
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _notifySnapshot() {
    widget.onNotificationsChanged?.call(
      List<AppNotificationItem>.unmodifiable(_notifications),
    );
    unawaited(_refreshUnreadCount());
  }

  Future<void> _refreshUnreadCount() async {
    final revision = ++_unreadCountRevision;
    final count = await _service.fetchMyUnreadCount();
    if (!mounted || revision != _unreadCountRevision || count == null) return;
    setState(() => _serverUnreadCount = count);
  }

  AppNotificationItem _withReadAt(
    AppNotificationItem item,
    DateTime? readAt,
  ) =>
      AppNotificationItem(
        id: item.id,
        recipientId: item.recipientId,
        notificationType: item.notificationType,
        title: item.title,
        body: item.body,
        routeType: item.routeType,
        routeId: item.routeId,
        data: item.data,
        createdAt: item.createdAt,
        readAt: readAt,
      );

  Future<void> _markRead(AppNotificationItem item) async {
    if (item.isRead) return;
    final before = _notifications;
    final now = DateTime.now();
    setState(() {
      _notifications = _notifications
          .map((entry) => entry.id == item.id ? _withReadAt(entry, now) : entry)
          .toList(growable: false);
    });
    _notifySnapshot();

    final saved = await _service.tryMarkAsRead(item.id);
    if (!saved && mounted) {
      setState(() => _notifications = _restoreFailedRead(before, now));
      _notifySnapshot();
      showAppSnackBar(context, 'Could not mark this notification as read.');
    } else if (mounted) {
      // Refresh the shell badge after the write, not only during optimism.
      _notifySnapshot();
    }
  }

  List<AppNotificationItem> _restoreFailedRead(
      List<AppNotificationItem> before, DateTime optimisticReadAt) {
    final original = {for (final entry in before) entry.id: entry};
    return _notifications.map((entry) {
      final previous = original[entry.id];
      // Preserve fresh realtime rows and independently confirmed read state.
      if (previous == null || entry.readAt != optimisticReadAt) return entry;
      return _withReadAt(entry, previous.readAt);
    }).toList(growable: false);
  }

  Future<void> _markAllRead() async {
    if (_markingAllRead ||
        ((_serverUnreadCount ?? 0) == 0 &&
            !_notifications.any((item) => !item.isRead))) return;
    final before = _notifications;
    final now = DateTime.now();
    setState(() {
      _markingAllRead = true;
      _notifications = _notifications
          .map((entry) => entry.isRead ? entry : _withReadAt(entry, now))
          .toList(growable: false);
    });
    _notifySnapshot();

    final saved = await _service.tryMarkAllAsRead();
    if (!mounted) return;
    setState(() {
      _markingAllRead = false;
      if (!saved) _notifications = _restoreFailedRead(before, now);
    });
    _notifySnapshot();
    if (!saved) {
      showAppSnackBar(context, 'Could not mark all notifications as read.');
    } else {
      unawaited(_refreshLatest());
    }
  }

  IconData _iconForType(String type) => switch (type.toLowerCase()) {
        'announcement' => Icons.campaign_outlined,
        'payment' => Icons.payments_outlined,
        'maintenance' => Icons.build_outlined,
        'curfew' => Icons.schedule_outlined,
        'visitor' => Icons.group_outlined,
        'gate' => Icons.sensor_door_outlined,
        'safety' => Icons.warning_amber_rounded,
        'message' => Icons.chat_bubble_outline,
        'onboarding' => Icons.assignment_ind_outlined,
        _ => Icons.notifications_outlined,
      };

  Color _colorForType(BuildContext context, String type) {
    final theme = Theme.of(context);
    return switch (type.toLowerCase()) {
      'announcement' => const Color(0xFF7D70A0),
      'payment' => const Color(0xFF56886B),
      'maintenance' => const Color(0xFFB47A52),
      'curfew' || 'safety' => const Color(0xFFAA6870),
      'visitor' => const Color(0xFF627FA8),
      'gate' => const Color(0xFF568F8E),
      'message' => const Color(0xFF627FA8),
      _ => theme.colorScheme.primary,
    };
  }

  String _sectionFor(DateTime value) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(value.year, value.month, value.day);
    if (day == today) return 'Today';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return 'Earlier';
  }

  String _relativeTime(DateTime value) {
    final now = DateTime.now();
    final diff = now.difference(value);
    if (diff.isNegative || diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} hr';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} d';
    return shortDate(value);
  }

  List<Widget> _notificationRows(BuildContext context) {
    final rows = <Widget>[];
    String? currentSection;
    for (final item in _notifications) {
      final section = _sectionFor(item.createdAt);
      if (section != currentSection) {
        currentSection = section;
        if (rows.isNotEmpty) rows.add(const SizedBox(height: 14));
        rows.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              section,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        );
      }
      rows.add(_notificationTile(context, item));
      rows.add(const SizedBox(height: 7));
    }
    return rows;
  }

  Widget _notificationTile(BuildContext context, AppNotificationItem item) {
    final theme = Theme.of(context);
    final iconColor = _colorForType(context, item.notificationType);
    final unread = !item.isRead;

    return Material(
      key: Key('notification-${item.id}'),
      color: unread
          ? theme.colorScheme.primaryContainer.withValues(alpha: .18)
          : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          if (!item.isRead) {
            unawaited(_markRead(item));
          }
          if (widget.onOpenNotification != null) {
            await widget.onOpenNotification?.call(item);
          } else {
            final role = SessionController.instance.currentUser?.role;
            if (role != null && context.mounted) {
              await Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => notificationDestination(item, role),
              ));
            }
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: iconColor.withValues(alpha: .12),
                foregroundColor: iconColor,
                child: Icon(_iconForType(item.notificationType), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight:
                                  unread ? FontWeight.w800 : FontWeight.w600,
                            ),
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (item.body.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        item.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          height: 1.35,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 5),
                    Text(
                      _relativeTime(item.createdAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: unread
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.onOpenNotification != null) ...[
                const SizedBox(width: 6),
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Icon(Icons.chevron_right_rounded, size: 20),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _serverUnreadCount ??
        _notifications.where((item) => !item.isRead).length;
    final hasUnread = unreadCount > 0;

    return PageFrame(
      title: 'Notifications',
      subtitle: hasUnread
          ? '$unreadCount unread ${unreadCount == 1 ? 'update' : 'updates'}'
          : 'You are all caught up',
      actions: hasUnread
          ? [
              TextButton.icon(
                onPressed: _markingAllRead ? null : _markAllRead,
                icon: _markingAllRead
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.done_all_rounded, size: 18),
                label: const Text('Mark all read'),
              ),
            ]
          : null,
      child: _loading && _notifications.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          : _notifications.isEmpty
              ? const EmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: 'No notifications yet',
                  message:
                      'Important account, payment, maintenance, curfew, and safety updates will appear here.',
                )
              : Column(
                  key: const Key('live-notifications-list'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errorText != null) ...[
                      CarmelitaCard(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.cloud_off_outlined, size: 20),
                            const SizedBox(width: 10),
                            Expanded(child: Text(_errorText!)),
                            TextButton(
                              onPressed: _loading ? null : _loadInitial,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    ..._notificationRows(context),
                    const SizedBox(height: 6),
                    if (_hasMore)
                      Center(
                        child: OutlinedButton.icon(
                          key: const Key('see-previous-notifications'),
                          onPressed: _loadingMore ? null : _loadPrevious,
                          icon: _loadingMore
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.history_rounded, size: 18),
                          label: Text(
                            _loadingMore
                                ? 'Loading previous…'
                                : 'See previous notifications',
                          ),
                        ),
                      )
                    else
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'You’re all caught up',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      'Older notifications are cleared automatically based on their type and read status. Official payment, maintenance, curfew, and conduct records are kept in their original modules.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
    );
  }
}

void _openMoveOutSettlement(BuildContext context) {
  if (CarmeLinkSurfaceScope.isWebPortal(context)) {
    final nav = CarmelitaNavScope.maybeOf(context);
    if (nav != null) {
      nav.selectLabel('Move-out & settlement');
      return;
    }
  }
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const MoveOutSettlementPage()),
  );
}

Future<bool> _confirmLogout(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Logout?'),
          content: const Text(
            'You will be signed out of CarmeLink. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.logout_outlined),
              label: const Text('Logout'),
            ),
          ],
        ),
      ) ??
      false;
}

Future<void> _logoutCurrentUser(BuildContext context) async {
  if (!await _confirmLogout(context)) return;

  try {
    await SessionController.instance.signOut();
    if (!context.mounted) return;

    if (CarmeLinkSurfaceScope.isWebPortal(context)) {
      Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
        '/',
        (route) => false,
      );
      return;
    }

    Navigator.of(
      context,
      rootNavigator: true,
    ).popUntil((route) => route.isFirst);
  } catch (_) {
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      'Logout failed. Please retry.',
    );
  }
}

class _ProfileAccountActions extends StatelessWidget {
  const _ProfileAccountActions();

  @override
  Widget build(BuildContext context) {
    final webPortal = CarmeLinkSurfaceScope.isWebPortal(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const SectionTitle('Account'),
        const SizedBox(height: 10),
        CarmelitaCard(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SettingsPage()),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: const ListTile(
            dense: true,
            visualDensity: VisualDensity(vertical: -2),
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.settings_outlined),
            title: Text(
              'Settings',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            subtitle: Text(
              'Appearance, privacy, notifications, and password',
              softWrap: true,
              style: TextStyle(fontSize: 11),
            ),
            trailing: Icon(Icons.chevron_right_rounded),
          ),
        ),
        if (!webPortal) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('profile-logout'),
              onPressed: () => _logoutCurrentUser(context),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Logout'),
            ),
          ),
        ],
      ],
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context) {
    final user = SessionController.instance.currentUser ??
        const AppUser(
          id: 'guest-profile',
          name: 'Carmelita Resident',
          email: 'resident@carmelitas.com',
          role: UserRole.tenant,
        );
    return PageFrame(
      title: 'Profile',
      subtitle: 'Personal and contact information',
      maxWidth: 720,
      child: user.role == UserRole.tenant
          ? _TenantProfileContent(user: user)
          : user.role == UserRole.guardian
              ? _GuardianProfileContent(user: user)
              : _OwnerProfileContent(user: user),
    );
  }
}

class _OwnerProfileContent extends StatelessWidget {
  const _OwnerProfileContent({required this.user});
  final AppUser user;

  String get roleLabel => user.role == UserRole.owner ? 'Owner' : 'Caretaker';

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${roleLabel.toUpperCase()} PROFILE',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: 1.3,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 8),
          CarmelitaCard(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              CircleAvatar(
                radius: 27,
                backgroundColor: const Color(0xFF627FA8).withValues(alpha: .10),
                foregroundColor: const Color(0xFF627FA8),
                child: Text(user.name.substring(0, 1),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 13),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(user.email,
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 6),
                  StatusPill(roleLabel),
                ],
              )),
            ]),
          ),
          const SizedBox(height: 20),
          const SectionTitle('Account information'),
          const SizedBox(height: 10),
          _TenantProfileRow(
              icon: Icons.person_outline,
              color: const Color(0xFF56886B),
              label: 'Full name',
              value: user.name),
          const SizedBox(height: 8),
          _TenantProfileRow(
              icon: Icons.mail_outline,
              color: const Color(0xFF627FA8),
              label: 'Email',
              value: user.email),
          const SizedBox(height: 8),
          _TenantProfileRow(
              icon: Icons.phone_outlined,
              color: const Color(0xFF7D70A0),
              label: 'Phone',
              value: user.phone),
          const SizedBox(height: 8),
          _TenantProfileRow(
              icon: Icons.admin_panel_settings_outlined,
              color: const Color(0xFFB47A52),
              label: 'Access level',
              value: user.role == UserRole.owner
                  ? 'Full dormitory administration'
                  : 'Dormitory operations'),
          const SizedBox(height: 20),
          const SectionTitle('Tenancy operations'),
          const SizedBox(height: 10),
          CarmelitaCard(
            onTap: () => _openMoveOutSettlement(context),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: const ListTile(
              dense: true,
              visualDensity: VisualDensity(vertical: -2),
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.exit_to_app_rounded),
              title: Text(
                'Move-out & settlement',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              subtitle: Text(
                'Notice, final inspection, clearance, and deposit settlement',
                style: TextStyle(fontSize: 11),
              ),
              trailing: Icon(Icons.chevron_right_rounded),
            ),
          ),
          const _ProfileAccountActions(),
        ],
      );
}

/* Legacy generic profile retained only for source-history readability.
class _LegacyGenericProfile extends StatelessWidget {
  const _LegacyGenericProfile({required this.user, required this.role});
  final AppUser user;
  final String role;
  @override
  Widget build(BuildContext context) => Column(children: [
                  CarmelitaCard(
                      child: Row(children: [
                    CircleAvatar(
                        radius: 34,
                        child: Text(user.name.substring(0, 1),
                            style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.w800))),
                    const SizedBox(width: 16),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(user.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(user.email),
                          const SizedBox(height: 8),
                          StatusPill(role),
                        ])),
                  ])),
                  const SizedBox(height: 16),
                  CarmelitaCard(
                      child: Column(children: [
                    InfoRow(
                        label: 'Full name',
                        value: user.name,
                        icon: Icons.person_outline),
                    InfoRow(
                        label: 'Email',
                        value: user.email,
                        icon: Icons.mail_outline),
                    InfoRow(
                        label: 'Phone',
                        value: user.phone,
                        icon: Icons.phone_outlined),
                  ])),
                  const SizedBox(height: 16),
                  ListTile(
                      leading: const Icon(Icons.settings_outlined),
                      title: const Text('Settings'),
                      subtitle: const Text(
                          'Appearance, privacy, notifications, and password'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const SettingsPage()))),
            ]);
}
*/

class _GuardianProfileContent extends StatelessWidget {
  const _GuardianProfileContent({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GUARDIAN PROFILE',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: 1.3,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 8),
          CarmelitaCard(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              CircleAvatar(
                radius: 27,
                backgroundColor: const Color(0xFF7D70A0).withValues(alpha: .10),
                foregroundColor: const Color(0xFF7D70A0),
                child: Text(user.name.substring(0, 1),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(user.email,
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 6),
                    const StatusPill('Guardian'),
                  ],
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          const SectionTitle('Contact information'),
          const SizedBox(height: 10),
          _TenantProfileRow(
              icon: Icons.person_outline,
              color: const Color(0xFF56886B),
              label: 'Full name',
              value: user.name),
          const SizedBox(height: 8),
          _TenantProfileRow(
              icon: Icons.mail_outline,
              color: const Color(0xFF627FA8),
              label: 'Email',
              value: user.email),
          const SizedBox(height: 8),
          _TenantProfileRow(
              icon: Icons.phone_outlined,
              color: const Color(0xFF7D70A0),
              label: 'Phone',
              value: user.phone),
          const SizedBox(height: 8),
          _LiveProfileRow(
            icon: Icons.family_restroom_outlined,
            color: const Color(0xFFB47A52),
            label: 'Linked tenant',
            value: const ProfileService().guardianLinkedTenant(user.id),
          ),
          const _ProfileAccountActions(),
        ],
      );
}

class _TenantProfileContent extends StatelessWidget {
  const _TenantProfileContent({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PROFILE SUMMARY',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: 1.3,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 8),
          CarmelitaCard(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              CircleAvatar(
                radius: 27,
                backgroundColor: const Color(0xFF56886B).withValues(alpha: .10),
                foregroundColor: const Color(0xFF56886B),
                child: Text(user.name.substring(0, 1),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(user.email,
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 6),
                    const StatusPill('Tenant'),
                  ],
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          const SectionTitle('Personal information'),
          const SizedBox(height: 10),
          _TenantProfileRow(
              icon: Icons.person_outline,
              color: const Color(0xFF56886B),
              label: 'Full name',
              value: user.name),
          const SizedBox(height: 8),
          _TenantProfileRow(
              icon: Icons.mail_outline,
              color: const Color(0xFF627FA8),
              label: 'Email',
              value: user.email),
          const SizedBox(height: 8),
          _TenantProfileRow(
              icon: Icons.phone_outlined,
              color: const Color(0xFF7D70A0),
              label: 'Phone',
              value: user.phone),
          const SizedBox(height: 8),
          _LiveProfileRow(
            icon: Icons.bed_outlined,
            color: const Color(0xFFB47A52),
            label: 'Room assignment',
            value: const ProfileService().tenantRoomAssignment(user.id),
          ),
          const SizedBox(height: 16),
          _TenantOnboardingDetailsSection(userId: user.id),
          const SizedBox(height: 16),
          const _TenantRequiredDocumentsSection(),
          const SizedBox(height: 20),
          const SectionTitle('Tenancy'),
          const SizedBox(height: 10),
          CarmelitaCard(
            onTap: () => _openMoveOutSettlement(context),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: const ListTile(
              dense: true,
              visualDensity: VisualDensity(vertical: -2),
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.exit_to_app_rounded),
              title: Text(
                'Move-out notice & settlement',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              subtitle: Text(
                'Submit a 30-day notice and track final clearance',
                style: TextStyle(fontSize: 11),
              ),
              trailing: Icon(Icons.chevron_right_rounded),
            ),
          ),
          const _ProfileAccountActions(),
        ],
      );
}

class _TenantOnboardingDetailsSection extends StatefulWidget {
  const _TenantOnboardingDetailsSection({required this.userId});
  final String userId;

  @override
  State<_TenantOnboardingDetailsSection> createState() =>
      _TenantOnboardingDetailsSectionState();
}

class _TenantOnboardingDetailsSectionState
    extends State<_TenantOnboardingDetailsSection> {
  final _service = const OnboardingInvitationService();
  late Future<Map<String, dynamic>?> _future = _load();

  Future<Map<String, dynamic>?> _load() =>
      _service.getMyTenantDetails(widget.userId);

  void _reload() {
    if (mounted) {
      setState(() {
        _future = _load();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _future,
      builder: (context, snapshot) {
        final details = snapshot.data;
        final ecName =
            details?['emergency_contact_name']?.toString().trim() ?? '';
        final ecPhone =
            details?['emergency_contact_phone']?.toString().trim() ?? '';
        final ecRel =
            details?['emergency_contact_relationship']?.toString().trim() ?? '';
        final school = details?['school_name']?.toString().trim() ?? '';
        final course = details?['course_or_program']?.toString().trim() ?? '';

        final isComplete =
            ecName.isNotEmpty && ecPhone.isNotEmpty && ecRel.isNotEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: SectionTitle('Emergency & academic details'),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const OnboardingFormPage(),
                      ),
                    );
                    _reload();
                  },
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text(isComplete ? 'Edit' : 'Add Details'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _TenantProfileRow(
              icon: Icons.contact_emergency_outlined,
              color: isComplete
                  ? const Color(0xFF2E7D32)
                  : Theme.of(context).colorScheme.error,
              label: 'Emergency contact',
              value: isComplete
                  ? '$ecName ($ecRel) • $ecPhone'
                  : 'Not provided (Action required)',
            ),
            if (school.isNotEmpty || course.isNotEmpty) ...[
              const SizedBox(height: 8),
              _TenantProfileRow(
                icon: Icons.school_outlined,
                color: const Color(0xFF1976D2),
                label: 'School & course',
                value: [school, course].where((s) => s.isNotEmpty).join(' • '),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _TenantRequiredDocumentsSection extends StatefulWidget {
  const _TenantRequiredDocumentsSection();

  @override
  State<_TenantRequiredDocumentsSection> createState() =>
      _TenantRequiredDocumentsSectionState();
}

class _TenantRequiredDocumentsSectionState
    extends State<_TenantRequiredDocumentsSection> {
  final _service = const ContractOnboardingService();
  late Future<
      ({
        TenantContract? contract,
        List<ContractRequirement> requirements,
        List<ContractSigner> signers,
      })> _future = _load();

  Future<
      ({
        TenantContract? contract,
        List<ContractRequirement> requirements,
        List<ContractSigner> signers,
      })> _load() async {
    try {
      final contract = await _service.getMyContractForSigning();
      if (contract == null) {
        return (
          contract: null,
          requirements: <ContractRequirement>[],
          signers: <ContractSigner>[],
        );
      }
      final reqs = await _service.listRequirements(contract.id);
      final signers = await _service.listSigners(contract.id);
      return (contract: contract, requirements: reqs, signers: signers);
    } catch (_) {
      return (
        contract: null,
        requirements: <ContractRequirement>[],
        signers: <ContractSigner>[],
      );
    }
  }

  void _reload() {
    if (mounted) {
      setState(() {
        _future = _load();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<
        ({
          TenantContract? contract,
          List<ContractRequirement> requirements,
          List<ContractSigner> signers,
        })>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final contract = data?.contract;
        final reqs = data?.requirements ?? const [];
        final signers = data?.signers ?? const [];

        if (contract == null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Contract & documents'),
              const SizedBox(height: 8),
              _TenantProfileRow(
                icon: Icons.description_outlined,
                color: Colors.grey,
                label: 'Rental contract',
                value: 'Drafting in progress by dorm management',
              ),
            ],
          );
        }

        final tenantIdReq =
            reqs.where((r) => r.type == 'tenant_identity').firstOrNull;
        final guardianIdReq =
            reqs.where((r) => r.type == 'guardian_identity').firstOrNull;
        final signedReq =
            reqs.where((r) => r.type == 'signed_photocopies').firstOrNull;
        final tenantSigner =
            signers.where((s) => s.role == 'tenant').firstOrNull;

        final requiredList = reqs.where((r) => r.isRequired).toList();
        final verifiedCount = requiredList.where((r) => r.isVerified).length;
        final totalRequired = requiredList.length;

        final errorColor = Theme.of(context).colorScheme.error;

        // 1. Tenant ID status
        final (tenantIdColor, tenantIdText) = () {
          if (tenantIdReq == null) {
            return (
              const Color(0xFFE65100),
              'Not uploaded yet (Action required)'
            );
          }
          if (tenantIdReq.isVerified) {
            return (const Color(0xFF2E7D32), 'Verified & Approved');
          }
          if (tenantIdReq.isPendingReview) {
            return (
              const Color(0xFF1565C0),
              'Uploaded (${tenantIdReq.originalFilename ?? "ID copy"}) • Pending Review'
            );
          }
          if (tenantIdReq.status == 'rejected') {
            return (
              errorColor,
              'Rejected: ${tenantIdReq.reviewNotes ?? "Action required"}'
            );
          }
          return (
            const Color(0xFFE65100),
            'Not uploaded yet (Action required)'
          );
        }();

        // 2. Guardian ID status
        final (guardianIdColor, guardianIdText) = () {
          if (guardianIdReq == null) return (Colors.grey, 'Optional');
          if (guardianIdReq.isVerified) {
            return (const Color(0xFF2E7D32), 'Verified & Approved');
          }
          if (guardianIdReq.isPendingReview) {
            return (
              const Color(0xFF1565C0),
              'Uploaded (${guardianIdReq.originalFilename ?? "Guardian ID"}) • Pending Review'
            );
          }
          if (guardianIdReq.status == 'rejected') {
            return (
              errorColor,
              'Rejected: ${guardianIdReq.reviewNotes ?? "Action required"}'
            );
          }
          if (!guardianIdReq.isRequired) {
            return (Colors.grey, 'Optional (Not submitted)');
          }
          return (
            const Color(0xFFE65100),
            'Not uploaded yet (Action required)'
          );
        }();

        // 3. Signed Lease copy status
        final (signedColor, signedText) = () {
          if (signedReq == null) {
            return (const Color(0xFFE65100), 'Missing (Action required)');
          }
          if (signedReq.physicalCopyReceived) {
            return (const Color(0xFF2E7D32), 'Hard copy received at dorm desk');
          }
          if (signedReq.isVerified) {
            return (const Color(0xFF2E7D32), 'Verified & Approved');
          }
          if (signedReq.isPendingReview) {
            return (
              const Color(0xFF1565C0),
              'Submitted (${signedReq.originalFilename ?? "Contract copy"}) • Pending Review'
            );
          }
          if (signedReq.status == 'rejected') {
            return (
              errorColor,
              'Rejected: ${signedReq.reviewNotes ?? "Action required"}'
            );
          }
          return (
            const Color(0xFFE65100),
            'Not submitted yet (Upload or hand in paper)'
          );
        }();

        // 4. Lease signature status
        final (signatureColor, signatureText) = () {
          if (tenantSigner == null) {
            return (const Color(0xFFE65100), 'Pending signature');
          }
          if (tenantSigner.isVerified) {
            return (const Color(0xFF2E7D32), 'Signature verified by staff');
          }
          if (tenantSigner.status == 'signed') {
            return (
              const Color(0xFF1565C0),
              tenantSigner.signatureMethod == 'electronic'
                  ? 'Signed on phone (E-Sign) • Pending Review'
                  : 'Signed via upload • Pending Review',
            );
          }
          if (tenantSigner.status == 'rejected') {
            return (errorColor, 'Signature rejected • Tap to resign on phone');
          }
          return (
            const Color(0xFFE65100),
            'Pending signature • Tap to sign on phone'
          );
        }();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: SectionTitle('Contract, documents & signature'),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const TenantRequirementsPage(),
                      ),
                    );
                    _reload();
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Open Checklist'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 1. Contract overview
            _TenantProfileRow(
              icon: Icons.assignment_outlined,
              color: contract.isActive
                  ? const Color(0xFF2E7D32)
                  : const Color(0xFFE65100),
              label: 'Contract #${contract.contractNumber}',
              value:
                  '${contract.status.toUpperCase()} • $verifiedCount of $totalRequired verified • ${shortDate(contract.startsOn)} - ${shortDate(contract.endsOn)}',
            ),
            const SizedBox(height: 8),

            // 2. Tenant ID
            InkWell(
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TenantRequirementsPage(),
                  ),
                );
                _reload();
              },
              borderRadius: BorderRadius.circular(12),
              child: _TenantProfileRow(
                icon: Icons.badge_outlined,
                color: tenantIdColor,
                label: 'Tenant valid ID (Required)',
                value: tenantIdText,
              ),
            ),
            const SizedBox(height: 8),

            // 3. Guardian ID
            InkWell(
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TenantRequirementsPage(),
                  ),
                );
                _reload();
              },
              borderRadius: BorderRadius.circular(12),
              child: _TenantProfileRow(
                icon: Icons.family_restroom_outlined,
                color: guardianIdColor,
                label: 'Parent / guardian valid ID',
                value: guardianIdText,
              ),
            ),
            const SizedBox(height: 8),

            // 4. Signed Photocopy / Paper copy
            InkWell(
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TenantRequirementsPage(),
                  ),
                );
                _reload();
              },
              borderRadius: BorderRadius.circular(12),
              child: _TenantProfileRow(
                icon: Icons.description_outlined,
                color: signedColor,
                label: 'Signed lease agreement copy',
                value: signedText,
              ),
            ),
            const SizedBox(height: 8),

            // 5. On-Screen Signature
            InkWell(
              onTap: () async {
                if (tenantSigner?.status == 'pending' ||
                    tenantSigner?.status == 'rejected') {
                  final bytes = await showSignaturePadDialog(
                    context,
                    signerName: contract.tenantName,
                    contractNumber: contract.contractNumber,
                  );
                  if (bytes != null) {
                    try {
                      await _service.submitElectronicSignature(
                        contractId: contract.id,
                        signatureBytes: bytes,
                      );
                      if (context.mounted) {
                        showAppSnackBar(
                          context,
                          'Electronic signature submitted! Staff will verify it.',
                        );
                        _reload();
                      }
                    } catch (e) {
                      if (context.mounted) {
                        showAppSnackBar(
                          context,
                          'Failed to submit signature: $e',
                        );
                      }
                    }
                  }
                } else {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const TenantRequirementsPage(),
                    ),
                  );
                  _reload();
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: _TenantProfileRow(
                icon: Icons.draw_rounded,
                color: signatureColor,
                label: 'Lease signature (On-Screen E-Sign)',
                value: signatureText,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TenantProfileRow extends StatelessWidget {
  const _TenantProfileRow(
      {required this.icon,
      required this.color,
      required this.label,
      required this.value});
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => CarmelitaCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: TimelineTile(
          compact: true,
          icon: icon,
          color: color,
          title: label,
          subtitle: value,
        ),
      );
}

class _LiveProfileRow extends StatelessWidget {
  const _LiveProfileRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final Future<String> value;

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
        future: value,
        builder: (context, snapshot) => _TenantProfileRow(
          icon: icon,
          color: color,
          label: label,
          value: snapshot.hasError
              ? 'Unable to load'
              : snapshot.data ?? 'Loading…',
        ),
      );
}

class _ThemeModeSelector extends StatelessWidget {
  const _ThemeModeSelector({
    required this.value,
    required this.onChanged,
  });

  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = <({ThemeMode mode, IconData icon, String label})>[
      (
        mode: ThemeMode.system,
        icon: Icons.settings_suggest_outlined,
        label: 'System',
      ),
      (
        mode: ThemeMode.light,
        icon: Icons.light_mode_outlined,
        label: 'Light',
      ),
      (
        mode: ThemeMode.dark,
        icon: Icons.dark_mode_outlined,
        label: 'Dark',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final vertical = constraints.maxWidth < 350;

        if (vertical) {
          return Column(
            children: options
                .map(
                  (option) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ThemeModeChoice(
                      mode: option.mode,
                      icon: option.icon,
                      label: option.label,
                      selected: value == option.mode,
                      onTap: () => onChanged(option.mode),
                    ),
                  ),
                )
                .toList(),
          );
        }

        return Row(
          children: options
              .map(
                (option) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: option.mode == ThemeMode.dark ? 0 : 8,
                    ),
                    child: _ThemeModeChoice(
                      mode: option.mode,
                      icon: option.icon,
                      label: option.label,
                      selected: value == option.mode,
                      onTap: () => onChanged(option.mode),
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _ThemeModeChoice extends StatelessWidget {
  const _ThemeModeChoice({
    required this.mode,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final ThemeMode mode;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(
        Radius.circular(16),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
        decoration: BoxDecoration(
          color:
              selected ? scheme.primary.withValues(alpha: .12) : scheme.surface,
          borderRadius: const BorderRadius.all(
            Radius.circular(16),
          ),
          border: Border.all(
            color: selected ? scheme.primary : Theme.of(context).dividerColor,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? scheme.primary : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: selected ? scheme.primary : scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ThemeController.instance;

    return PageFrame(
      title: 'Settings',
      subtitle: 'Appearance, privacy, notifications, and security',
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ElegantHeader(
              eyebrow: 'Preferences',
              title: 'Make the app feel right for you.',
              subtitle:
                  'Choose how Carmelita looks on this device. System mode follows your iPhone or Android setting automatically.',
            ),
            const SizedBox(height: 22),
            const SectionTitle(
              'Profile',
              subtitle: 'Your editable account information',
            ),
            const SizedBox(height: 10),
            CarmelitaCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.manage_accounts_outlined),
                title: const Text(
                  'Edit profile',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Update your name, phone, and role-appropriate profile details.',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ProfileEditPage(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            const SectionTitle(
              'Appearance',
              subtitle: 'System, Light, or Dark',
            ),
            const SizedBox(height: 10),
            CarmelitaCard(
              emphasis: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ThemeModeSelector(
                    value: controller.themeMode,
                    onChanged: controller.setThemeMode,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    controller.themeMode == ThemeMode.system
                        ? 'Following your device appearance.'
                        : controller.themeMode == ThemeMode.light
                            ? 'Light appearance is active.'
                            : 'Dark appearance is active.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const SectionTitle('Notifications & privacy'),
            const SizedBox(height: 10),
            CarmelitaCard(
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.notifications_outlined),
                    title: const Text(
                      'Notification preferences',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: const Text(
                      'Payment, geofence presence, maintenance, and announcement alerts.',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const NotificationPreferencesPage(),
                      ),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text(
                      'Privacy and permissions',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: const Text(
                      'Camera, location, storage, and notification permissions.',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PrivacyPermissionsPage(),
                      ),
                    ),
                  ),
                  if (SessionController.instance.currentUser?.role ==
                          UserRole.owner ||
                      SessionController.instance.currentUser?.role ==
                          UserRole.caretaker) ...[
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.security_outlined),
                      title: const Text(
                        'Security & retention',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text(
                        'Configure sensitive-record retention for client and privacy review.',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RetentionSettingsPage(),
                        ),
                      ),
                    ),
                  ],
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.password_outlined),
                    title: const Text(
                      'Change password',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: const Text(
                      'Update your password securely through Supabase Auth.',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ChangePasswordPage(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const SectionTitle(
              'Support',
              subtitle: 'Help improve CarmeLink',
            ),
            const SizedBox(height: 10),
            CarmelitaCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.rate_review_outlined),
                title: const Text(
                  'Send feedback',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Share an idea, report an app issue, or rate your experience.',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FeedbackPage()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final message = TextEditingController();
  String category = 'Suggestion';
  int rating = 0;
  bool includeAccountDetails = true;
  bool submitted = false;

  @override
  void dispose() {
    message.dispose();
    super.dispose();
  }

  void _submit() {
    final clean = message.text.trim();
    if (rating == 0) {
      showAppSnackBar(context, 'Choose a rating before submitting.');
      return;
    }
    if (clean.length < 10) {
      showAppSnackBar(context, 'Enter at least 10 characters of feedback.');
      return;
    }

    setState(() => submitted = true);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.check_circle_outline, color: Colors.green),
        title: const Text('Feedback preview validated'),
        content: const Text(
          'The form looks valid, but this preview was not sent or stored. ' +
              'Backend feedback persistence is not enabled yet.',
          // Original (main): 'Thank you! This preview was validated, but your feedback was not sent or stored.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Feedback',
      subtitle: 'Validate the feedback form experience',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ElegantHeader(
              eyebrow: 'Your voice matters',
              title: 'How is CarmeLink working for you?',
              subtitle:
                  'Tell us what works well, what feels difficult, or what you would like added.',
            ),
            const SizedBox(height: 20),
            CarmelitaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RATE YOUR EXPERIENCE',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    children: List.generate(5, (index) {
                      final value = index + 1;
                      return IconButton(
                        tooltip: '$value star${value == 1 ? '' : 's'}',
                        onPressed: () => setState(() {
                          rating = value;
                          submitted = false;
                        }),
                        icon: Icon(
                          value <= rating
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: const Color(0xFFD19A45),
                          size: 32,
                        ),
                      );
                    }),
                  ),
                  Text(
                    rating == 0
                        ? 'No rating selected'
                        : '$rating out of 5 stars',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(
                      labelText: 'Feedback type',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: const [
                      'Accessibility',
                      'App issue',
                      'Compliment',
                      'Suggestion',
                      'Other',
                    ]
                        .map((item) => DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() {
                      category = value ?? category;
                      submitted = false;
                    }),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: message,
                    minLines: 5,
                    maxLines: 8,
                    maxLength: 1500,
                    onChanged: (_) {
                      if (submitted) setState(() => submitted = false);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Feedback',
                      alignLabelWithHint: true,
                      hintText:
                          'Describe your experience, suggestion, or the issue you encountered.',
                    ),
                  ),
                  Material(
                    type: MaterialType.transparency,
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Include my account details'),
                      subtitle: const Text(
                        'Included only in this local UI preview; nothing is transmitted.',
                      ),
                      value: includeAccountDetails,
                      onChanged: (value) =>
                          setState(() => includeAccountDetails = value),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            CarmelitaCard(
              padding: const EdgeInsets.all(12),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This form is currently a UI preview. Feedback is not '
                      'transmitted or stored until backend support is added.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: Icon(submitted
                    ? Icons.check_circle_outline
                    : Icons.send_outlined),
                label: Text(
                    submitted ? 'Preview validated' : 'Validate feedback form'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NotificationPreferencesPage extends StatefulWidget {
  const NotificationPreferencesPage({super.key});

  @override
  State<NotificationPreferencesPage> createState() =>
      _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState
    extends State<NotificationPreferencesPage> {
  final enabled = <String, bool>{
    'Payments': true,
    'Geofence presence': true,
    'Maintenance': true,
    'Announcements': true,
  };
  bool _savingGuardianPreference = false;

  bool get _isGuardian =>
      SessionController.instance.currentUser?.role == UserRole.guardian;

  @override
  void initState() {
    super.initState();
    if (_isGuardian) {
      GuardianAlertService.load().then((_) {
        if (!mounted) return;
        setState(() {
          enabled['Geofence presence'] =
              GuardianAlertService.gateEntryEnabled ||
                  GuardianAlertService.gateExitEnabled;
        });
      }).catchError((_) {});
    }
  }

  Future<void> _saveGuardianPreference({
    TimeOfDay? alertTime,
    bool? gateEnabled,
    bool? cutoffEnabled,
    bool? insideEnabled,
  }) async {
    setState(() => _savingGuardianPreference = true);
    try {
      await GuardianAlertService.save(
        alertTime: alertTime,
        gateEntryEnabled: gateEnabled,
        gateExitEnabled: gateEnabled,
        outsideAfterCutoffEnabled: cutoffEnabled,
        insideAfterCutoffEnabled: insideEnabled,
      );
      if (!mounted) return;
      setState(() {
        enabled['Geofence presence'] = GuardianAlertService.gateEntryEnabled ||
            GuardianAlertService.gateExitEnabled;
      });
    } catch (error) {
      if (mounted) {
        showAppSnackBar(context, 'Could not save preference: $error');
      }
    } finally {
      if (mounted) setState(() => _savingGuardianPreference = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const icons = <String, IconData>{
      'Payments': Icons.payments_outlined,
      'Geofence presence': Icons.location_on_outlined,
      'Maintenance': Icons.build_outlined,
      'Announcements': Icons.campaign_outlined,
    };

    return PageFrame(
      title: 'Alerts',
      subtitle: 'Choose which updates you receive',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CarmelitaCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              children: enabled.entries.map((entry) {
                return SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(icons[entry.key]),
                  title: Text(entry.key),
                  value: entry.value,
                  onChanged: _savingGuardianPreference
                      ? null
                      : (value) {
                          if (_isGuardian && entry.key == 'Geofence presence') {
                            _saveGuardianPreference(gateEnabled: value);
                          } else {
                            setState(() => enabled[entry.key] = value);
                          }
                        },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          CarmelitaCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF627FA8).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.alarm_outlined,
                        color: Color(0xFF627FA8),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Guardian Curfew Alert Time',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Informational alert if your linked resident is outside past this time.',
                            style:
                                TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (_isGuardian) ...[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Outside-after-time alert'),
                    subtitle: const Text(
                        'Notify me once per day when my linked resident is still outside the dormitory property after the selected time.'),
                    value: GuardianAlertService.outsideAfterCutoffEnabled,
                    onChanged: _savingGuardianPreference
                        ? null
                        : (value) =>
                            _saveGuardianPreference(cutoffEnabled: value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Inside-after-time alert'),
                    subtitle: const Text(
                        'Notify me once per day when my linked resident is inside the dormitory property after the selected time.'),
                    value: GuardianAlertService.insideAfterCutoffEnabled,
                    onChanged: _savingGuardianPreference
                        ? null
                        : (value) =>
                            _saveGuardianPreference(insideEnabled: value),
                  ),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Preferred alert cutoff:',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    OutlinedButton.icon(
                      onPressed: !_isGuardian || _savingGuardianPreference
                          ? null
                          : () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime:
                                    GuardianAlertService.preferredAlertTime,
                              );
                              if (picked != null) {
                                await _saveGuardianPreference(
                                    alertTime: picked);
                              }
                            },
                      icon: const Icon(Icons.schedule, size: 16),
                      label: Text(
                        GuardianAlertService.preferredAlertTime.format(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Note: This alert is strictly guardian-facing for peace of mind. It does not record official dormitory curfew violations or disciplinary infractions.',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Colors.black45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PrivacyPermissionsPage extends StatefulWidget {
  const PrivacyPermissionsPage({super.key});

  @override
  State<PrivacyPermissionsPage> createState() => _PrivacyPermissionsPageState();
}

class _PrivacyPermissionsPageState extends State<PrivacyPermissionsPage> {
  final permissions = <String, bool>{
    'Camera': true,
    'Location': false,
    'Photos and storage': true,
    'Notifications': true,
  };

  @override
  void initState() {
    super.initState();
    _checkSystemPermissions();
  }

  Future<void> _checkSystemPermissions() async {
    try {
      final perm = await GeofenceService.checkPermission();
      if (mounted) {
        setState(() {
          permissions['Location'] = perm == LocationPermission.always;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    const icons = <String, IconData>{
      'Camera': Icons.camera_alt_outlined,
      'Location': Icons.location_on_outlined,
      'Photos and storage': Icons.folder_outlined,
      'Notifications': Icons.notifications_outlined,
    };

    return PageFrame(
      title: 'Privacy',
      subtitle: 'Control access used by CarmeLink',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CarmelitaCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              children: permissions.entries.map((entry) {
                return SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(icons[entry.key]),
                  title: Text(entry.key),
                  value: entry.value,
                  onChanged: (value) async {
                    setState(() => permissions[entry.key] = value);
                    if (entry.key == 'Location') {
                      if (value) {
                        final perm = await GeofenceService.requestPermission();
                        if (mounted) {
                          setState(() {
                            permissions['Location'] =
                                perm == LocationPermission.always;
                          });
                          if (perm == LocationPermission.whileInUse) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Choose Allow all the time or Always in system settings for automatic entry and exit logging when CarmeLink is closed.',
                                ),
                              ),
                            );
                            await GeofenceService.openAppSettings();
                          }
                        }
                      } else {
                        await GeofenceService.openAppSettings();
                      }
                    }
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          CarmelitaCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Permission usage',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  '• Location: Always/Allow all the time access is required for automatic IN/OUT logging while CarmeLink is closed.\n'
                  '• Camera & Storage: Required for capturing maintenance issue photos and payment proof receipts.\n'
                  '• Notifications: Real-time safety announcements and account updates.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () => GeofenceService.openAppSettings(),
              icon: const Icon(Icons.settings_outlined, size: 18),
              label: const Text('Open System App Settings'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'To adjust OS-level hardware permissions (Location, Camera, Storage), tap "Open System App Settings" above.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({
    this.recoveryMode = false,
    this.onComplete,
    super.key,
  });

  final bool recoveryMode;
  final VoidCallback? onComplete;

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final currentPassword = TextEditingController();
  final newPassword = TextEditingController();
  final confirmPassword = TextEditingController();
  final AuthService authService = SupabaseAuthService();
  bool loading = false;

  @override
  void dispose() {
    currentPassword.dispose();
    newPassword.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if ((!widget.recoveryMode && currentPassword.text.isEmpty) ||
        newPassword.text.length < 8) {
      showAppSnackBar(
        context,
        'Enter your current password and a new password of at least 8 characters.',
      );
      return;
    }
    if (newPassword.text != confirmPassword.text) {
      showAppSnackBar(context, 'New passwords do not match.');
      return;
    }
    setState(() => loading = true);
    try {
      if (widget.recoveryMode) {
        await authService.setRecoveredPassword(newPassword.text);
      } else {
        await authService.changePassword(
            currentPassword.text, newPassword.text);
      }
      currentPassword.clear();
      newPassword.clear();
      confirmPassword.clear();
      if (mounted) showAppSnackBar(context, 'Password updated successfully.');
      widget.onComplete?.call();
    } catch (error) {
      if (mounted) {
        showAppSnackBar(
          context,
          error
              .toString()
              .replaceFirst('AuthException(message: ', '')
              .replaceFirst(', statusCode: 400)', ''),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Change password',
      subtitle: 'Update your account credentials',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: CarmelitaCard(
          child: Column(
            children: [
              if (!widget.recoveryMode) ...[
                TextField(
                  controller: currentPassword,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Current password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: newPassword,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New password',
                  prefixIcon: Icon(Icons.password_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPassword,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm new password',
                  prefixIcon: Icon(Icons.password_outlined),
                ),
                onSubmitted: (_) => loading ? null : submit(),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: loading ? null : submit,
                  child: Text(loading ? 'Updating…' : 'Update password'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DormitoryInfoPage extends StatelessWidget {
  const DormitoryInfoPage({super.key});
  @override
  Widget build(BuildContext context) => const PageFrame(
        title: 'CarmeLink',
        subtitle: 'Dormitory information',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          PhotoHero(
              image: AppAssets.exterior,
              title: 'More than a place to stay',
              subtitle: 'A place to belong',
              height: 270),
          SizedBox(height: 20),
          CarmelitaCard(
              child: Column(children: [
            InfoRow(
                label: 'Type',
                value: 'Dormitory for girls',
                icon: Icons.home_outlined),
            InfoRow(
                label: 'Room setup',
                value: 'Up to 4 tenants per room',
                icon: Icons.bed_outlined),
            InfoRow(
                label: 'Location',
                value: 'Brgy. Concepcion, Baliwag, Bulacan',
                icon: Icons.location_on_outlined),
          ])),
        ]),
      );
}
