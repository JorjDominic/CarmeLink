import 'package:flutter/material.dart';

import '../../controllers/session_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../core/constants/app_assets.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/mock_data.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});
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
                  .map((n) => TimelineTile(
                        icon: n.type == 'Payment'
                            ? Icons.payments_outlined
                            : n.type == 'Gate'
                                ? Icons.sensor_door_outlined
                                : Icons.build_outlined,
                        title: n.title,
                        subtitle:
                            '${n.body}\n${shortDate(n.time)} • ${timeText(n.time)}',
                      ))
                  .toList())),
    );
  }

  int _urgency(String type) => type == 'Gate'
      ? 3
      : type == 'Payment'
          ? 2
          : 1;
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
          color: selected
              ? scheme.primary.withValues(alpha: .12)
              : scheme.surface,
          borderRadius: const BorderRadius.all(
            Radius.circular(16),
          ),
          border: Border.all(
            color: selected
                ? scheme.primary
                : Theme.of(context).dividerColor,
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
      child: CarmelitaCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          children: enabled.entries.map((entry) {
            return SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(icons[entry.key]),
              title: Text(entry.key),
              value: entry.value,
              onChanged: (value) => setState(() => enabled[entry.key] = value),
            );
          }).toList(),
        ),
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
    'Location': true,
    'Photos and storage': true,
    'Notifications': true,
  };

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
                  onChanged: (value) =>
                      setState(() => permissions[entry.key] = value),
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
                  '• Location: Required for automated perimeter geofencing to verify inside/outside dormitory presence.\n'
                  '• Camera & Storage: Required for capturing maintenance issue photos and payment proof receipts.\n'
                  '• Notifications: Real-time safety announcements and account updates.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'System permission prompts will be connected when native services are enabled.',
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
  Widget build(BuildContext context) => PageFrame(
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
      );
}

class OtpPage extends StatelessWidget {
  const OtpPage({required this.email, super.key});
  final String email;
  @override
  Widget build(BuildContext context) => PageFrame(
        title: 'Verification code',
        subtitle: email,
        child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text(
                  'Enter the verification code sent to your email. This is a frontend placeholder until authentication is connected.'),
              const SizedBox(height: 20),
              const TextField(
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                      labelText: '6-digit code',
                      prefixIcon: Icon(Icons.pin_outlined))),
              SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                      onPressed: () {
                        showAppSnackBar(context,
                            'Verification UI completed. Backend connection comes next.');
                        Navigator.of(context)
                            .popUntil((route) => route.isFirst);
                      },
                      child: const Text('Verify'))),
            ])),
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
