import 'package:flutter/material.dart';

import '../../theme/web_theme.dart';
import '../staff_portal_theme.dart';

/// Presentation layer for the REAL owner/caretaker web workspace.
/// Never substitutes demo data or changes the existing role's destinations.
class StaffWorkspaceChrome extends StatelessWidget {
  const StaffWorkspaceChrome({
    super.key,
    required this.roleLabel,
    required this.onPublicWebsite,
    required this.onSignOut,
    required this.child,
  });

  final String roleLabel;
  final VoidCallback onPublicWebsite;
  final Future<void> Function() onSignOut;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final spacious = width >= 900;

    return Scaffold(
      backgroundColor: WebPalette.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              key: const Key('staff-workspace-header'),
              padding: EdgeInsets.symmetric(
                horizontal: spacious ? 26 : 12,
                vertical: spacious ? 15 : 9,
              ),
              decoration: const BoxDecoration(
                color: WebPalette.surface,
                border: Border(bottom: BorderSide(color: WebPalette.border)),
              ),
              child: Row(
                children: [
                  Container(
                    width: spacious ? 46 : 38,
                    height: spacious ? 46 : 38,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: WebPalette.cream,
                      border: Border.all(color: WebPalette.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Image.asset(
                      'assets/web/brand/carmelita_logo.jpg',
                      fit: BoxFit.contain,
                      semanticLabel: 'Carmelita Dormitory logo',
                      errorBuilder: (context, error, stack) => const Icon(
                        Icons.apartment_rounded,
                        color: WebPalette.plum,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (spacious)
                          const Text(
                            'CARMELITA / MANAGEMENT',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: WebPalette.muted,
                              fontSize: 10,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        Text(
                          spacious ? 'Staff workspace' : '$roleLabel workspace',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: WebPalette.ink,
                            fontSize: spacious ? 20 : 14,
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
                        color: WebPalette.sand,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: WebPalette.border),
                      ),
                      child: Text(
                        roleLabel,
                        style: const TextStyle(
                          color: WebPalette.plum,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    OutlinedButton.icon(
                      key: const Key('staff-workspace-public'),
                      onPressed: onPublicWebsite,
                      icon: const Icon(Icons.open_in_new, size: 17),
                      label: const Text('Public website'),
                    ),
                    const SizedBox(width: 10),
                    TextButton.icon(
                      key: const Key('staff-workspace-signout'),
                      onPressed: onSignOut,
                      icon: const Icon(Icons.logout_outlined, size: 18),
                      label: const Text('Sign out'),
                    ),
                  ] else ...[
                    IconButton(
                      key: const Key('staff-workspace-public'),
                      tooltip: 'Public website',
                      onPressed: onPublicWebsite,
                      icon: const Icon(Icons.open_in_new_outlined, size: 21),
                    ),
                    IconButton(
                      key: const Key('staff-workspace-signout'),
                      tooltip: 'Sign out',
                      onPressed: onSignOut,
                      icon: const Icon(Icons.logout_outlined, size: 21),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: Theme(
                data: StaffPortalTheme.from(Theme.of(context)),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
