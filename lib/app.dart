import 'package:flutter/material.dart';

import 'controllers/session_controller.dart';
import 'controllers/theme_controller.dart';
import 'core/constants/app_assets.dart';
import 'core/theme/app_theme.dart';
import 'models/models.dart';
import 'views/auth/auth_views.dart';
import 'views/caretaker/caretaker_shell.dart';
import 'views/guardian/guardian_shell.dart';
import 'views/owner/owner_shell.dart';
import 'views/tenant/tenant_shell.dart';
import 'views/shared/shared_views.dart';

class CarmelitaBootstrap extends StatefulWidget {
  const CarmelitaBootstrap({super.key});

  @override
  State<CarmelitaBootstrap> createState() => _CarmelitaBootstrapState();
}

class _CarmelitaBootstrapState extends State<CarmelitaBootstrap> {
  final ThemeController themeController = ThemeController.instance;
  final SessionController sessionController = SessionController.instance;
  bool assetsCached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (assetsCached) return;
    assetsCached = true;
    for (final asset in const [
      AppAssets.logo,
      AppAssets.courtyard,
      AppAssets.room,
      AppAssets.exterior,
      AppAssets.dormOverview,
    ]) {
      precacheImage(AssetImage(asset), context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([themeController, sessionController]),
      builder: (context, _) {
        return MaterialApp(
          title: 'CarmeLink',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeController.themeMode,
          home: _rootForSession(),
        );
      },
    );
  }

  Widget _rootForSession() {
    if (sessionController.passwordRecovery) {
      return ChangePasswordPage(
        recoveryMode: true,
        onComplete: sessionController.completePasswordRecovery,
      );
    }
    final user = sessionController.currentUser;
    if (user == null) {
      return AuthFlow(
        skipIntro: sessionController.justSignedOut,
      );
    }

    switch (user.role) {
      case UserRole.tenant:
        return const TenantShell();
      case UserRole.guardian:
        return const GuardianShell();
      case UserRole.caretaker:
        return const CaretakerShell();
      case UserRole.owner:
        return const OwnerShell();
    }
  }
}
