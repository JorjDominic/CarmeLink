import 'package:flutter/material.dart';

import '../../controllers/session_controller.dart';
import '../../views/auth/auth_views.dart';
import '../widgets/web_brand.dart';

class StaffAccessPage extends StatefulWidget {
  const StaffAccessPage({super.key, required this.onBack});
  final VoidCallback onBack;

  @override
  State<StaffAccessPage> createState() => _StaffAccessPageState();
}

class _StaffAccessPageState extends State<StaffAccessPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final session = SessionController.instance;
    final ok = await session.signIn(_email.text.trim(), _password.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!ok) _error = session.error ?? 'Unable to sign in. Please try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        title: const WebBrand(compact: true),
        leading: IconButton(
          onPressed: widget.onBack,
          tooltip: 'Return to public website',
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Card(
              elevation: 0,
              color: scheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: theme.dividerColor),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.admin_panel_settings_outlined,
                        size: 44,
                        color: scheme.primary,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Staff sign in',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Authorized owner and caretaker accounts only.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 26),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.username],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.mail_outline),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            (value == null || !value.contains('@'))
                                ? 'Enter a valid email.'
                                : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscurePassword,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _signIn(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'Show password'
                                : 'Hide password',
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'Enter your password.'
                            : null,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _busy
                              ? null
                              : () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const ForgotPasswordPage(),
                                    ),
                                  ),
                          child: const Text('Forgot password?'),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: TextStyle(color: scheme.error),
                        ),
                      ],
                      const SizedBox(height: 22),
                      FilledButton(
                        onPressed: _busy ? null : _signIn,
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.primary,
                          foregroundColor: scheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _busy
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: scheme.onPrimary,
                                ),
                              )
                            : const Text('Sign in'),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Use an existing staff account. Public registration is disabled.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
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
