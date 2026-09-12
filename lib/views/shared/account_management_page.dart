import 'package:flutter/material.dart';

import '../../controllers/session_controller.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/role_guard.dart';
import '../../models/models.dart';
import '../../services/account_service.dart';
import '../../services/table_refresh_subscription.dart';

class AccountManagementPage extends StatefulWidget {
  const AccountManagementPage({super.key});

  @override
  State<AccountManagementPage> createState() => _AccountManagementPageState();
}

class _AccountManagementPageState extends State<AccountManagementPage> {
  final service = const AccountService();
  late Future<List<Map<String, dynamic>>> accounts = service.listAccounts();
  late final TableRefreshSubscription subscription;

  @override
  void initState() {
    super.initState();
    subscription = TableRefreshSubscription('accounts', ['profiles'], reload);
  }

  @override
  void dispose() {
    subscription.dispose();
    super.dispose();
  }

  void reload() {
    if (mounted) setState(() => accounts = service.listAccounts());
  }

  Future<void> manage(Map<String, dynamic> account) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _EditAccountSheet(account: account),
    );
    if (changed == true && mounted) {
      reload();
      showAppSnackBar(context, 'Account changes saved.');
    }
  }

  @override
  Widget build(BuildContext context) => RoleGuard(
        allowedRoles: const {UserRole.owner, UserRole.caretaker},
        child: PageFrame(
          title: 'Account management',
          subtitle: 'Create and review dormitory accounts',
          actions: [
            IconButton(
              tooltip: 'Refresh accounts',
              onPressed: reload,
              icon: const Icon(Icons.refresh),
            ),
          ],
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              final created = await showModalBottomSheet<bool>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                showDragHandle: true,
                builder: (_) => const _CreateAccountSheet(),
              );
              if (created == true && context.mounted) {
                reload();
                showAppSnackBar(context, 'Account created successfully.');
              }
            },
            icon: const Icon(Icons.person_add_outlined),
            label: const Text('Create account'),
          ),
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: accounts,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                    child: Text('Unable to load accounts: ${snapshot.error}'));
              }
              final rows = snapshot.data ?? const [];
              if (rows.isEmpty)
                return const Center(child: Text('No accounts found.'));
              return Column(
                children: rows
                    .map((row) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: CarmelitaCard(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            child: ListTile(
                              onTap: () => manage(row),
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                child: Text((row['full_name'] as String)
                                    .substring(0, 1)),
                              ),
                              title: Text(row['full_name'] as String),
                              subtitle: Text([
                                row['email'] as String? ?? '',
                                (row['phone'] as String?)?.isNotEmpty == true
                                    ? row['phone'] as String
                                    : 'No phone number',
                              ].join('\n')),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  StatusPill(_roleLabel(row['role'] as String)),
                                  const Icon(Icons.chevron_right, size: 18),
                                ],
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              );
            },
          ),
        ),
      );

  String _roleLabel(String role) => switch (role) {
        'owner' => 'Owner',
        'caretaker' => 'Caretaker',
        'guardian' => 'Guardian',
        _ => 'Tenant',
      };
}

class _EditAccountSheet extends StatefulWidget {
  const _EditAccountSheet({required this.account});
  final Map<String, dynamic> account;

  @override
  State<_EditAccountSheet> createState() => _EditAccountSheetState();
}

class _EditAccountSheetState extends State<_EditAccountSheet> {
  final service = const AccountService();
  late final TextEditingController fullName;
  late final TextEditingController email;
  late final TextEditingController phone;
  bool loading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fullName = TextEditingController(
        text: widget.account['full_name'] as String? ?? '');
    email =
        TextEditingController(text: widget.account['email'] as String? ?? '');
    phone =
        TextEditingController(text: widget.account['phone'] as String? ?? '');
  }

  @override
  void dispose() {
    fullName.dispose();
    email.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (fullName.text.trim().isEmpty || !email.text.contains('@')) {
      setState(
          () => errorMessage = 'Enter a full name and valid email address.');
      return;
    }
    await run(() => service.updateAccount(
          id: widget.account['id'] as String,
          fullName: fullName.text,
          email: email.text,
          phone: phone.text,
        ));
  }

  Future<void> resetPassword() async {
    await run(() => service.sendPasswordReset(widget.account['id'] as String),
        close: false, success: 'Password recovery email sent.');
  }

  Future<void> delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete account?'),
        content: Text(
            'Delete ${widget.account['full_name']} and all linked application records? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await run(() => service.deleteAccount(widget.account['id'] as String));
    }
  }

  Future<void> run(Future<void> Function() action,
      {bool close = true, String? success}) async {
    setState(() {
      loading = true;
      errorMessage = null;
    });
    try {
      await action();
      if (!mounted) return;
      if (success != null) showAppSnackBar(context, success);
      if (close) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Manage account',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              StatusPill(_roleLabel(widget.account['role'] as String)),
              const SizedBox(height: 18),
              TextField(
                  controller: fullName,
                  enabled: !loading,
                  decoration: const InputDecoration(labelText: 'Full name')),
              const SizedBox(height: 12),
              TextField(
                  controller: email,
                  enabled: !loading,
                  keyboardType: TextInputType.emailAddress,
                  decoration:
                      const InputDecoration(labelText: 'Email address')),
              const SizedBox(height: 12),
              TextField(
                  controller: phone,
                  enabled: !loading,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone number')),
              if (errorMessage != null) ...[
                const SizedBox(height: 14),
                _InlineError(message: errorMessage!),
              ],
              const SizedBox(height: 18),
              SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                      onPressed: loading ? null : save,
                      child: Text(loading ? 'Working…' : 'Save changes'))),
              const SizedBox(height: 8),
              SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                      onPressed: loading ? null : resetPassword,
                      icon: const Icon(Icons.lock_reset),
                      label: const Text('Send password reset'))),
              const SizedBox(height: 8),
              SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                      onPressed: loading ? null : delete,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete account'))),
            ],
          ),
        ),
      );

  String _roleLabel(String role) =>
      '${role.substring(0, 1).toUpperCase()}${role.substring(1)}';
}

class _CreateAccountSheet extends StatefulWidget {
  const _CreateAccountSheet();

  @override
  State<_CreateAccountSheet> createState() => _CreateAccountSheetState();
}

class _CreateAccountSheetState extends State<_CreateAccountSheet> {
  final fullName = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final password = TextEditingController();
  final service = const AccountService();
  bool loading = false;
  bool passwordVisible = false;
  String role = 'tenant';
  String? errorMessage;

  List<String> get allowedRoles =>
      SessionController.instance.currentUser?.role == UserRole.owner
          ? const ['tenant', 'guardian', 'caretaker', 'owner']
          : const ['tenant', 'guardian'];

  @override
  void dispose() {
    fullName.dispose();
    email.dispose();
    phone.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    FocusScope.of(context).unfocus();
    setState(() => errorMessage = null);
    if (fullName.text.trim().isEmpty || !email.text.contains('@')) {
      setState(
          () => errorMessage = 'Enter a full name and a valid email address.');
      return;
    }
    if (password.text.length < 12) {
      setState(() => errorMessage =
          'Temporary password must contain at least 12 characters.');
      return;
    }
    setState(() => loading = true);
    try {
      await service.createAccount(
        fullName: fullName.text,
        email: email.text,
        phone: phone.text,
        role: role,
        temporaryPassword: password.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Create account',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 18),
                TextField(
                    controller: fullName,
                    decoration: const InputDecoration(labelText: 'Full name')),
                const SizedBox(height: 12),
                TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration:
                        const InputDecoration(labelText: 'Email address')),
                const SizedBox(height: 12),
                TextField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration:
                        const InputDecoration(labelText: 'Phone number')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: allowedRoles
                      .map((value) => DropdownMenuItem(
                          value: value, child: Text(_label(value))))
                      .toList(),
                  onChanged:
                      loading ? null : (value) => setState(() => role = value!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: password,
                  obscureText: !passwordVisible,
                  decoration: InputDecoration(
                    labelText: 'Temporary password',
                    helperText: 'At least 12 characters',
                    suffixIcon: IconButton(
                      tooltip:
                          passwordVisible ? 'Hide password' : 'Show password',
                      onPressed: () =>
                          setState(() => passwordVisible = !passwordVisible),
                      icon: Icon(passwordVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                    ),
                  ),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .errorContainer
                          .withValues(alpha: .55),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .error
                            .withValues(alpha: .35),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error_outline,
                            color: Theme.of(context).colorScheme.error),
                        const SizedBox(width: 10),
                        Expanded(child: Text(errorMessage!)),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: loading ? null : submit,
                    icon: loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.person_add_outlined),
                    label: Text(loading ? 'Creating…' : 'Create account'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  String _label(String value) =>
      '${value.substring(0, 1).toUpperCase()}${value.substring(1)}';
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .errorContainer
              .withValues(alpha: .55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.error.withValues(alpha: .35),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline,
                color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      );
}
