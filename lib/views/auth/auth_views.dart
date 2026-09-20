import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/session_controller.dart';
import '../../core/constants/app_assets.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/widgets/common_widgets.dart';
import '../../services/auth_service.dart';
import '../shared/shared_views.dart';

class AuthFlow extends StatefulWidget {
  const AuthFlow({
    this.skipIntro = false,
    super.key,
  });

  final bool skipIntro;

  @override
  State<AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<AuthFlow> {
  late int stage;

  @override
  void initState() {
    super.initState();
    stage = widget.skipIntro ? 2 : 0;

    if (!widget.skipIntro) {
      Timer(const Duration(milliseconds: 1100), () {
        if (mounted && stage == 0) {
          setState(() => stage = 1);
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant AuthFlow oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.skipIntro && !oldWidget.skipIntro && stage != 2) {
      setState(() => stage = 2);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 420),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, .055),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
        child: stage == 0
            ? const SplashPage(key: ValueKey('splash'))
            : stage == 1
                ? WelcomePage(
                    key: const ValueKey('welcome'),
                    onContinue: () => setState(() => stage = 2))
                : const SignInPage(key: ValueKey('signin')),
      );
}

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 700),
            tween: Tween(begin: .85, end: 1),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => Transform.scale(
                scale: value, child: Opacity(opacity: value, child: child)),
            child: const Column(mainAxisSize: MainAxisSize.min, children: [
              CarmelitaLogo(height: 130),
              SizedBox(height: 20),
              Text(
                'CarmeLink',
                style: TextStyle(
                  fontFamily: 'GreatVibes',
                  fontWeight: FontWeight.w600,
                  fontSize: 36,
                ),
              ),
            ]),
          ),
        ),
      );
}

class WelcomePage extends StatelessWidget {
  const WelcomePage({
    required this.onContinue,
    super.key,
  });

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.sizeOf(context).width < 720;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveContent(
            maxWidth: 1120,
            child: isPhone
                ? Column(
                    children: [
                      _photo(context, height: 300),
                      const SizedBox(height: 28),
                      _copy(context),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 11,
                        child: _photo(context, height: 590),
                      ),
                      const SizedBox(width: 46),
                      Expanded(
                        flex: 9,
                        child: _copy(context),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _photo(
    BuildContext context, {
    required double height,
  }) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(30)),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              AppAssets.courtyard,
              fit: BoxFit.cover,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: .48),
                  ],
                ),
              ),
            ),
            const Positioned(
              left: 22,
              right: 22,
              bottom: 22,
              child: Text(
                'Comfort, safety, and daily dormitory life in one place.',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _copy(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CarmelitaLogo(height: 72),
        const SizedBox(height: 28),
        Text(
          'Everything you need, without the clutter.',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontFamily: 'GreatVibes',
                fontWeight: FontWeight.w600,
                fontSize: 44,
                height: 1.12,
                letterSpacing: 0,
              ),
        ),
        const SizedBox(height: 14),
        Text(
          'Payments, room information, maintenance, geofence presence monitoring, announcements, and safety updates are organized around what each user needs to do.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 26),
        const _OnboardingPoint(
          icon: Icons.visibility_outlined,
          title: 'Clear at first glance',
          body:
              'Important status and required actions appear before secondary information.',
        ),
        const SizedBox(height: 12),
        const _OnboardingPoint(
          icon: Icons.shield_outlined,
          title: 'Role-based access',
          body:
              'Tenants, guardians, and owner/caretaker accounts see only relevant tools.',
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onContinue,
            child: const Text('Continue to sign in'),
          ),
        ),
      ],
    );
  }
}

class _OnboardingPoint extends StatelessWidget {
  const _OnboardingPoint({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: .08),
            borderRadius: const BorderRadius.all(Radius.circular(14)),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 3),
              Text(
                body,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});
  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final email = TextEditingController(text: 'tenant@carmelita.test');
  final password = TextEditingController(text: 'CarmeLinkTest123!');
  final session = SessionController.instance;
  bool _passwordVisible = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final ok = await session.signIn(email.text.trim(), password.text);
    if (!mounted) return;
    if (ok) return;
    if (session.emailAwaitingVerification != null) return;
    showAppSnackBar(context, session.error ?? 'Unable to sign in.');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            child: ResponsiveContent(
              maxWidth: 980,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: CarmelitaCard(
                    padding: const EdgeInsets.all(26),
                    child: AnimatedBuilder(
                      animation: session,
                      builder: (context, _) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Center(child: CarmelitaLogo(height: 132)),
                            const SizedBox(height: 24),
                            Text(
                              'Sign in',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    fontFamily: 'GreatVibes',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 36,
                                    height: 1.1,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                                'Use the account provided by the dormitory.'),
                            const SizedBox(height: 24),
                            TextField(
                                controller: email,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                    labelText: 'Email address',
                                    prefixIcon: Icon(Icons.mail_outline))),
                            const SizedBox(height: 14),
                            TextField(
                                controller: password,
                                obscureText: !_passwordVisible,
                                decoration: InputDecoration(
                                    labelText: 'Password',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      tooltip: _passwordVisible
                                          ? 'Hide password'
                                          : 'Show password',
                                      onPressed: () => setState(() =>
                                          _passwordVisible = !_passwordVisible),
                                      icon: Icon(_passwordVisible
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined),
                                    )),
                                onSubmitted: (_) => _submit()),
                            Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const ForgotPasswordPage())),
                                  child: const Text('Forgot password?'),
                                )),
                            SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: session.loading ? null : _submit,
                                  icon: session.loading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2))
                                      : const Icon(Icons.login),
                                  label: Text(session.loading
                                      ? 'Signing in…'
                                      : 'Sign in'),
                                )),
                            const SizedBox(height: 22),
                            Text('Test accounts',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 10),
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              _demoChip('Tenant', 'tenant@carmelita.test'),
                              _demoChip('Guardian', 'guardian@carmelita.test'),
                              _demoChip(
                                  'Caretaker', 'caretaker@carmelita.test'),
                              _demoChip('Owner', 'owner@carmelita.test'),
                            ]),
                            const SizedBox(height: 12),
                            Text(
                                'These accounts are for development only. Remove them before production.',
                                style: Theme.of(context).textTheme.bodySmall),
                          ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _demoChip(String label, String value) => ActionChip(
      label: Text(label),
      onPressed: () => setState(() {
            email.text = value;
            password.text = 'CarmeLinkTest123!';
          }));
}

class EmailVerificationCodePage extends StatefulWidget {
  const EmailVerificationCodePage({
    required this.email,
    super.key,
  });

  final String email;

  @override
  State<EmailVerificationCodePage> createState() =>
      _EmailVerificationCodePageState();
}

class _EmailVerificationCodePageState extends State<EmailVerificationCodePage> {
  late final TextEditingController email;
  final code = TextEditingController();
  final AuthService service = SupabaseAuthService();
  final session = SessionController.instance;
  Timer? _timer;
  int _resendSeconds = 0;
  bool codeSent = false;
  bool verifying = false;
  bool resending = false;

  @override
  void initState() {
    super.initState();
    email = TextEditingController(text: widget.email);
  }

  void _startCountdown() {
    _timer?.cancel();
    _resendSeconds = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  Future<void> _verify() async {
    if (verifying) return;
    final address = email.text.trim();
    final value = code.text.trim();
    if (!address.contains('@')) {
      showAppSnackBar(context, 'Enter a valid email address.');
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(value)) {
      showAppSnackBar(context, 'Enter the complete six-digit code.');
      return;
    }
    setState(() => verifying = true);
    try {
      final ok = await session.verifyEmailCode(address, value);
      if (mounted && !ok) {
        showAppSnackBar(context, _authMessage(session.error));
      }
    } finally {
      if (mounted) setState(() => verifying = false);
    }
  }

  Future<void> _resend() async {
    if (_resendSeconds > 0 || resending) return;
    final address = email.text.trim();
    if (!address.contains('@')) {
      showAppSnackBar(context, 'Enter a valid email address.');
      return;
    }
    setState(() => resending = true);
    try {
      await service.resendEmailVerificationCode(address);
      if (!mounted) return;
      code.clear();
      codeSent = true;
      _startCountdown();
      showAppSnackBar(context, 'Verification code sent.');
    } catch (error) {
      if (mounted) showAppSnackBar(context, _authMessage(error));
    } finally {
      if (mounted) setState(() => resending = false);
    }
  }

  String _authMessage(Object? error) =>
      (error?.toString() ?? 'Unable to verify.')
          .replaceFirst('AuthApiException(message: ', '')
          .replaceFirst('AuthException(message: ', '')
          .replaceFirst(RegExp(r', statusCode:.*$'), '')
          .replaceFirst('Exception: ', '');

  @override
  void dispose() {
    _timer?.cancel();
    email.dispose();
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && !verifying && !resending) {
            session.cancelEmailVerification();
          }
        },
        child: PageFrame(
          title: 'Verify your email',
          subtitle: codeSent
              ? 'Enter the code sent to your inbox'
              : 'Send a code when you are ready',
          onBack: session.cancelEmailVerification,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  codeSent
                      ? 'Enter the six-digit verification code. Codes expire and can only be used once.'
                      : 'Select Send code to receive a six-digit verification code.',
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: email,
                  readOnly: true,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: code,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  autofillHints: const [AutofillHints.oneTimeCode],
                  maxLength: 6,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Six-digit verification code',
                    prefixIcon: Icon(Icons.verified_outlined),
                    counterText: '',
                  ),
                  onSubmitted: (_) => _verify(),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: verifying ? null : _verify,
                  child: Text(verifying ? 'Verifying…' : 'Verify email'),
                ),
                TextButton(
                  onPressed: _resendSeconds == 0 && !resending ? _resend : null,
                  child: Text(
                    resending
                        ? 'Sending…'
                        : _resendSeconds > 0
                            ? 'Resend code in ${_resendSeconds}s'
                            : codeSent
                                ? 'Resend code'
                                : 'Send code',
                  ),
                ),
                TextButton(
                  onPressed: verifying || resending
                      ? null
                      : session.cancelEmailVerification,
                  child: const Text('Use a different account'),
                ),
              ],
            ),
          ),
        ),
      );
}

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});
  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final email = TextEditingController();

  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final address = email.text.trim();
    if (address.isEmpty || !address.contains('@')) {
      showAppSnackBar(context, 'Enter a valid email address.');
      return;
    }

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PasswordRecoveryCodePage(email: address),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PageFrame(
        title: 'Reset password',
        subtitle: 'Account recovery',
        child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text(
                  'Enter your account email to continue to password recovery.'),
              const SizedBox(height: 20),
              TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'Email address'),
                  onSubmitted: (_) => _submit()),
              const SizedBox(height: 14),
              SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submit,
                    child: const Text('Continue'),
                  )),
            ])),
      );
}

class PasswordRecoveryCodePage extends StatefulWidget {
  const PasswordRecoveryCodePage({required this.email, super.key});

  final String email;

  @override
  State<PasswordRecoveryCodePage> createState() =>
      _PasswordRecoveryCodePageState();
}

class _PasswordRecoveryCodePageState extends State<PasswordRecoveryCodePage> {
  final code = TextEditingController();
  final AuthService service = SupabaseAuthService();
  Timer? _timer;
  int _resendSeconds = 0;
  bool codeSent = false;
  bool verifying = false;
  bool resending = false;

  void _startCountdown() {
    _timer?.cancel();
    _resendSeconds = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  String get _maskedEmail {
    final parts = widget.email.split('@');
    if (parts.length != 2 || parts.first.isEmpty) return widget.email;
    final visible = parts.first.substring(0, 1);
    final hidden = List.filled(
      (parts.first.length - 1).clamp(2, 8),
      '•',
    ).join();
    return '$visible$hidden@${parts.last}';
  }

  Future<void> _verify() async {
    if (verifying) return;
    final value = code.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(value)) {
      showAppSnackBar(context, 'Enter the complete six-digit code.');
      return;
    }
    setState(() => verifying = true);
    try {
      await service.verifyPasswordRecoveryCode(widget.email, value);
      if (!mounted) return;
      final navigator = Navigator.of(context);
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChangePasswordPage(
            recoveryMode: true,
            onComplete: () {
              SessionController.instance.completePasswordRecovery();
              navigator.popUntil((route) => route.isFirst);
            },
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        showAppSnackBar(context, _authMessage(error));
      }
    } finally {
      if (mounted) setState(() => verifying = false);
    }
  }

  Future<void> _resend() async {
    if (_resendSeconds > 0 || resending) return;
    setState(() => resending = true);
    try {
      await service.requestPasswordReset(widget.email);
      if (!mounted) return;
      code.clear();
      codeSent = true;
      _startCountdown();
      showAppSnackBar(context, 'Recovery code sent.');
    } catch (error) {
      if (mounted) showAppSnackBar(context, _authMessage(error));
    } finally {
      if (mounted) setState(() => resending = false);
    }
  }

  String _authMessage(Object error) => error
      .toString()
      .replaceFirst('AuthException(message: ', '')
      .replaceFirst(RegExp(r', statusCode: \d+\)$'), '')
      .replaceFirst('Exception: ', '');

  @override
  void dispose() {
    _timer?.cancel();
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageFrame(
        title: 'Enter recovery code',
        subtitle: _maskedEmail,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                codeSent
                    ? 'Enter the six-digit code from your email. Codes expire and can only be used once.'
                    : 'Select Send code to receive a six-digit recovery code.',
              ),
              const SizedBox(height: 20),
              TextField(
                controller: code,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                autofillHints: const [AutofillHints.oneTimeCode],
                maxLength: 6,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Six-digit code',
                  prefixIcon: Icon(Icons.pin_outlined),
                  counterText: '',
                ),
                onSubmitted: (_) => _verify(),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: verifying ? null : _verify,
                child: Text(verifying ? 'Verifying…' : 'Verify code'),
              ),
              TextButton(
                onPressed: _resendSeconds == 0 && !resending ? _resend : null,
                child: Text(
                  resending
                      ? 'Sending…'
                      : _resendSeconds > 0
                          ? 'Resend code in ${_resendSeconds}s'
                          : codeSent
                              ? 'Resend code'
                              : 'Send code',
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const ForgotPasswordPage(),
                  ),
                ),
                child: const Text('Use a different email'),
              ),
            ],
          ),
        ),
      );
}
