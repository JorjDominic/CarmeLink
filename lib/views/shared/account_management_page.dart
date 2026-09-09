import 'package:flutter/material.dart';

import '../../controllers/session_controller.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/role_guard.dart';
import '../../models/models.dart';
import '../../services/account_service.dart';

class AccountManagementPage extends StatefulWidget {
  const AccountManagementPage({super.key});

  @override
  State<AccountManagementPage> createState() => _AccountManagementPageState();
}

class _AccountManagementPageState extends State<AccountManagementPage> {
  final service = const AccountService();
  late Future<List<Map<String, dynamic>>> accounts = service.listAccounts();

  void reload() => setState(() => accounts = service.listAccounts());

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
                builder: (_) => const _CreateAccountSheet(),
              );
              if (created == true) reload();
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
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                child: Text((row['full_name'] as String)
                                    .substring(0, 1)),
                              ),
                              title: Text(row['full_name'] as String),
                              subtitle: Text(
                                  (row['phone'] as String?)?.isNotEmpty == true
                                      ? row['phone'] as String
                                      : 'No phone number'),
                              trailing:
                                  StatusPill(_roleLabel(row['role'] as String)),
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
    if (fullName.text.trim().isEmpty || !email.text.contains('@')) {
      showAppSnackBar(context, 'Enter a name and valid email address.');
      return;
    }
    if (password.text.length < 12) {
      showAppSnackBar(
          context, 'Temporary password must be at least 12 characters.');
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
      showAppSnackBar(context, 'Account created successfully.');
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) showAppSnackBar(context, 'Unable to create account: $error');
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
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: loading ? null : submit,
                    icon: const Icon(Icons.person_add_outlined),
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
