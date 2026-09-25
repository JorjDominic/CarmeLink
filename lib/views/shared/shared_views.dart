import 'package:flutter/material.dart';

import '../../controllers/session_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../core/constants/app_assets.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/role_guard.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/geofence_service.dart';
import '../../services/guardian_alert_service.dart';
import '../../services/profile_service.dart';
import '../../services/app_notification_service.dart';
import 'package:carmelitas_dormitory_system/views/shared/retention_settings_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _service = AppNotificationService.instance;

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
      'announcement' => Colors.purple,
      'payment' => Colors.teal,
      'maintenance' => Colors.orange,
      'curfew' || 'safety' => Colors.redAccent,
      'visitor' => Colors.blue,
      'gate' => Colors.indigo,
      _ => theme.colorScheme.primary,
    };
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppNotificationItem>>(
      stream: _service.streamMyNotifications(),
      builder: (context, snapshot) {
        final notifications = snapshot.data ?? [];
        final hasUnread = notifications.any((n) => !n.isRead);

        return PageFrame(
          title: 'Notifications',
          subtitle: hasUnread
              ? 'You have unread updates'
              : 'All updates and security alerts',
          actions: hasUnread
              ? [
                  TextButton.icon(
                    onPressed: () => _service.markAllAsRead(),
                    icon: const Icon(Icons.done_all_rounded, size: 18),
                    label: const Text('Mark all read'),
                  ),
                ]
              : null,
          child: notifications.isEmpty
              ? const EmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: 'No notifications yet',
                  message:
                      'You are all caught up! Push announcements, payment receipts, and curfew alerts will appear here.',
                )
              : CarmelitaCard(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = notifications[index];
                      final iconColor =
                          _colorForType(context, item.notificationType);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: iconColor.withValues(alpha: 0.12),
                          foregroundColor: iconColor,
                          child: Icon(
                            _iconForType(item.notificationType),
                            size: 20,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                style: TextStyle(
                                  fontWeight: item.isRead
                                      ? FontWeight.w500
                                      : FontWeight.bold,
                                ),
                              ),
                            ),
                            if (!item.isRead)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          '${item.body}\n${shortDate(item.createdAt)} • ${timeText(item.createdAt)}',
                          style: TextStyle(
                            color: item.isRead ? Colors.grey.shade600 : null,
                          ),
                        ),
                        isThreeLine: true,
                        onTap: () {
                          if (!item.isRead) {
                            _service.markAsRead(item.id);
                          }
                        },
                      );
                    },
                  ),
                ),
        );
      },
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
          const SectionTitle('Account'),
          const SizedBox(height: 10),
          CarmelitaCard(
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const SettingsPage())),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: const ListTile(
              dense: true,
              visualDensity: VisualDensity(vertical: -2),
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.settings_outlined),
              title: Text('Settings',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              subtitle: Text('Appearance, privacy, password, and sign out',
                  style: TextStyle(fontSize: 11)),
              trailing: Icon(Icons.chevron_right_rounded),
            ),
          ),
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
                          'Appearance, privacy, password, and sign out'),
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
          const SizedBox(height: 20),
          const SectionTitle('Account'),
          const SizedBox(height: 10),
          CarmelitaCard(
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const SettingsPage())),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: const ListTile(
              dense: true,
              visualDensity: VisualDensity(vertical: -2),
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.settings_outlined),
              title: Text('Settings',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              subtitle: Text('Appearance, privacy, password, and sign out',
                  style: TextStyle(fontSize: 11)),
              trailing: Icon(Icons.chevron_right_rounded),
            ),
          ),
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
          const SizedBox(height: 20),
          const SectionTitle('Account'),
          const SizedBox(height: 10),
          CarmelitaCard(
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const SettingsPage())),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: const ListTile(
              dense: true,
              visualDensity: VisualDensity(vertical: -2),
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.settings_outlined),
              title: Text('Settings',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              subtitle: Text('Appearance, privacy, password, and sign out',
                  style: TextStyle(fontSize: 11)),
              trailing: Icon(Icons.chevron_right_rounded),
            ),
          ),
        ],
      );
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
    final isTenant =
        SessionController.instance.currentUser?.role == UserRole.tenant;

    return PageFrame(
      title: 'Settings',
      subtitle: 'Appearance, privacy, and account',
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
                  if (isTenant) ...[
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.phonelink_lock_outlined),
                      title: const Text('Device binding',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text(
                          'Register this device for background geofence presence detection.'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const DeviceBindingPage())),
                    ),
                  ],
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
                      'Will connect to Supabase Auth in the backend phase.',
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
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  SessionController.instance.signOut();

                  Navigator.of(
                    context,
                    rootNavigator: true,
                  ).popUntil((route) => route.isFirst);
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign out'),
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
        icon: const Icon(Icons.check_circle_outline),
        title: const Text('Feedback UI complete'),
        content: const Text(
          'Thank you. This preview validates the feedback form, but it is not '
          'sent or stored until the backend feedback service is connected.',
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
      title: 'Send feedback',
      subtitle: 'Help us improve your experience',
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
                      'Suggestion',
                      'App issue',
                      'Compliment',
                      'Accessibility',
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
                        'Helps support identify your role and follow up later.',
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
                label:
                    Text(submitted ? 'Preview validated' : 'Submit feedback'),
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

  @override
  Widget build(BuildContext context) {
    const icons = <String, IconData>{
      'Payments': Icons.payments_outlined,
      'Geofence presence': Icons.location_on_outlined,
      'Maintenance': Icons.build_outlined,
      'Announcements': Icons.campaign_outlined,
    };

    return PageFrame(
      title: 'Notification preferences',
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
                  onChanged: (value) =>
                      setState(() => enabled[entry.key] = value),
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
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: GuardianAlertService.preferredAlertTime,
                        );
                        if (picked != null) {
                          setState(() {
                            GuardianAlertService.setPreferredAlertTime(picked);
                          });
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
      title: 'Privacy and permissions',
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

class DeviceBindingPage extends StatelessWidget {
  const DeviceBindingPage({super.key});
  @override
  Widget build(BuildContext context) => RoleGuard(
        allowedRoles: const {UserRole.tenant},
        child: PageFrame(
          title: 'Device binding',
          subtitle: 'One tenant account, one trusted device',
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(children: [
                const CarmelitaCard(
                    child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.phonelink_lock_outlined),
                        title: Text('Register this device'),
                        subtitle: Text(
                            'Binding registers this phone as your trusted device for background geofencing presence detection. Native background location and device-token services are not connected yet.'))),
                const SizedBox(height: 14),
                SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                        onPressed: () => showAppSnackBar(context,
                            'Device binding requires native background location and hardware token registration.'),
                        icon: const Icon(Icons.phonelink_lock_outlined),
                        label: const Text('Bind trusted device'))),
              ])),
        ),
      );
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
