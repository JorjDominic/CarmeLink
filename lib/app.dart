import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import 'controllers/session_controller.dart';
import 'controllers/theme_controller.dart';
import 'core/constants/app_assets.dart';
import 'core/runtime/app_surface.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/connectivity_banner.dart';
import 'models/models.dart';
import 'services/push_notification_service.dart';
import 'views/auth/auth_views.dart';
import 'views/auth/mobile_auth_entry.dart';
import 'views/caretaker/caretaker_shell.dart';
import 'views/guardian/guardian_shell.dart';
import 'views/guardian/guardian_pages.dart';
import 'views/owner/owner_shell.dart';
import 'views/owner/owner_pages.dart';
import 'views/tenant/tenant_shell.dart';
import 'views/tenant/tenant_pages.dart';
import 'views/tenant/onboarding_form_page.dart';
import 'views/shared/shared_views.dart';

class CarmelitaBootstrap extends StatefulWidget {
  const CarmelitaBootstrap({super.key});

  @override
  State<CarmelitaBootstrap> createState() => _CarmelitaBootstrapState();
}

class _CarmelitaBootstrapState extends State<CarmelitaBootstrap> {
  final ThemeController themeController = ThemeController.instance;
  final SessionController sessionController = SessionController.instance;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final AppLinks _appLinks = AppLinks();

  StreamSubscription<Uri>? _linkSubscription;
  StreamSubscription<Map<String, dynamic>>? _notificationSubscription;
  String? _pendingOnboardingToken;
  String? _openedOnboardingToken;

  bool assetsCached = false;

  @override
  void initState() {
    super.initState();

    sessionController.addListener(_tryOpenPendingOnboarding);

    _listenForLinks();
    _notificationSubscription = PushNotificationService
        .instance.openedNotifications
        .listen(_openNotificationDestination);
  }

  void _openNotificationDestination(Map<String, dynamic> data) {
    final navigator = _navigatorKey.currentState;
    final user = sessionController.currentUser;
    if (navigator == null || user == null) return;

    if (data['route_type'] == 'conversation') {
      final Widget destination = switch (user.role) {
        UserRole.tenant => const TenantMessagesPage(),
        UserRole.guardian => const GuardianMessagesPage(),
        UserRole.owner || UserRole.caretaker => OwnerMessagingPage(
            initialConversationId: data['route_id'] as String?,
          ),
      };
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => destination),
      );
      return;
    }
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => const NotificationsPage()),
    );
  }

  Future<void> _listenForLinks() async {
    try {
      final initialLink = await _appLinks.getInitialLink();

      if (initialLink != null) {
        _handleLink(initialLink);
      }
    } catch (error) {
      debugPrint('Could not read initial app link: $error');
    }

    _linkSubscription = _appLinks.uriLinkStream.listen(
      _handleLink,
      onError: (Object error) {
        debugPrint('App link error: $error');
      },
    );
  }

  void _handleLink(Uri uri) {
    if (uri.scheme.toLowerCase() != 'carmelink' ||
        uri.host.toLowerCase() != 'onboarding') {
      return;
    }

    final token = uri.queryParameters['token']?.trim();

    if (token == null || token.isEmpty) {
      return;
    }

    _pendingOnboardingToken = token;

    _tryOpenPendingOnboarding();
  }

  void _tryOpenPendingOnboarding() {
    final token = _pendingOnboardingToken;
    final user = sessionController.currentUser;
    final navigator = _navigatorKey.currentState;

    if (token == null ||
        token == _openedOnboardingToken ||
        user?.role != UserRole.tenant ||
        navigator == null) {
      return;
    }

    _openedOnboardingToken = token;
    _pendingOnboardingToken = null;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }

      await navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => OnboardingFormPage(
            token: token,
          ),
        ),
      );

      _openedOnboardingToken = null;
    });
  }

  @override
  void dispose() {
    sessionController.removeListener(_tryOpenPendingOnboarding);

    _linkSubscription?.cancel();
    _notificationSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (assetsCached) {
      return;
    }

    assetsCached = true;

    // Feature photos are decoded by the screens that use them instead of
    // occupying the image cache before the user's role is known.
    precacheImage(const AssetImage(AppAssets.logo), context);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        themeController,
        sessionController,
      ]),
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: _navigatorKey,
          title: 'CarmeLink',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeController.themeMode,
          themeAnimationDuration: const Duration(milliseconds: 220),
          themeAnimationCurve: Curves.easeOutCubic,
          scrollBehavior: const ScrollBehavior().copyWith(
            overscroll: false,
            physics: const ClampingScrollPhysics(),
          ),

          // Keep one MaterialApp builder only.
          //
          // Mobile app surface tells AdaptiveShell that this is still the
          // mobile application even when lib/main.dart is previewed in Chrome.
          //
          // ConnectivityBannerHost remains inside the same builder so the
          // offline/online status layer continues to work.
          builder: (context, child) => CarmeLinkSurfaceScope(
            surface: CarmeLinkAppSurface.mobileApp,
            child: ConnectivityBannerHost(
              child: child ?? const SizedBox.shrink(),
            ),
          ),

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

    final verificationEmail = sessionController.emailAwaitingVerification;

    if (verificationEmail != null) {
      return EmailVerificationCodePage(
        email: verificationEmail,
      );
    }

    final user = sessionController.currentUser;

    if (user == null) {
      return MobileAuthEntry(
        skipSplash: sessionController.justSignedOut,
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
