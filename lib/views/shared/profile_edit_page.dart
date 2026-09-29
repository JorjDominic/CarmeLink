import 'package:flutter/material.dart';

import '../../controllers/session_controller.dart';
import '../../core/widgets/common_widgets.dart';
import '../../models/models.dart';
import '../../services/profile_service.dart';

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _service = const ProfileService();
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _school = TextEditingController();
  final _course = TextEditingController();
  final _yearLevel = TextEditingController();

  EditableProfileData? _data;
  DateTime? _birthDate;
  bool _loading = true;
  bool _saving = false;
  String? _errorText;

  AppUser? get _sessionUser => SessionController.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _service.loadMyEditableProfile();
      if (!mounted) return;
      _apply(data);
      setState(() {
        _data = data;
        _birthDate = data.birthDate;
        _loading = false;
        _errorText = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorText =
            'Could not load your profile. Check your connection and retry.';
      });
    }
  }

  void _apply(EditableProfileData data) {
    _fullName.text = data.fullName;
    _phone.text = data.phone;
    _address.text = data.address;
    _school.text = data.schoolName;
    _course.text = data.courseOrProgram;
    _yearLevel.text = data.yearLevel?.toString() ?? '';
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1940),
      lastDate: now,
    );
    if (picked != null && mounted) setState(() => _birthDate = picked);
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    final data = _data;
    if (data == null) return;

    setState(() => _saving = true);
    try {
      final saved = await _service.updateMyEditableProfile(
        fullName: _fullName.text,
        phone: _phone.text,
        birthDate: _birthDate,
        address: _address.text,
        schoolName: _school.text,
        courseOrProgram: _course.text,
        yearLevel: _yearLevel.text.trim().isEmpty
            ? null
            : int.tryParse(_yearLevel.text.trim()),
        isTenant: data.isTenant,
      );
      await SessionController.instance.refreshCurrentUser();
      if (!mounted) return;
      _apply(saved);
      setState(() {
        _data = saved;
        _birthDate = saved.birthDate;
      });
      showAppSnackBar(context, 'Profile updated.');
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        error.toString().replaceFirst('PostgrestException(message: ', ''),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _roleLabel(UserRole? role) => switch (role) {
        UserRole.owner => 'Owner',
        UserRole.caretaker => 'Caretaker',
        UserRole.guardian => 'Guardian',
        UserRole.tenant => 'Tenant',
        _ => 'Account',
      };

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    _address.dispose();
    _school.dispose();
    _course.dispose();
    _yearLevel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _sessionUser;
    return PageFrame(
      title: 'Edit profile',
      subtitle: 'Update the account information you are allowed to manage',
      maxWidth: 760,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorText != null
              ? CarmelitaCard(
                  child: Column(
                    children: [
                      Text(_errorText!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () {
                          setState(() {
                            _loading = true;
                            _errorText = null;
                          });
                          _load();
                        },
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle(
                        'Account identity',
                        subtitle:
                            'Email and role are protected and cannot be edited here.',
                      ),
                      const SizedBox(height: 10),
                      CarmelitaCard(
                        child: Column(
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.mail_outline),
                              title: const Text('Email'),
                              subtitle: Text(user?.email ?? '—'),
                              trailing:
                                  const Icon(Icons.lock_outline, size: 18),
                            ),
                            const Divider(),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.badge_outlined),
                              title: const Text('Role'),
                              subtitle: Text(_roleLabel(user?.role)),
                              trailing:
                                  const Icon(Icons.lock_outline, size: 18),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const SectionTitle('Editable information'),
                      const SizedBox(height: 10),
                      CarmelitaCard(
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _fullName,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Full name',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: (value) {
                                final clean = value?.trim() ?? '';
                                if (clean.length < 2)
                                  return 'Enter your full name.';
                                if (clean.length > 120)
                                  return 'Name is too long.';
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _phone,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Phone',
                                prefixIcon: Icon(Icons.phone_outlined),
                              ),
                              validator: (value) {
                                final clean = value?.trim() ?? '';
                                if (clean.isEmpty) return null;
                                if (clean.length < 7 || clean.length > 24) {
                                  return 'Enter a valid phone number.';
                                }
                                if (!RegExp(r'^[0-9+() .-]+$')
                                    .hasMatch(clean)) {
                                  return 'Enter a valid phone number.';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      if (_data?.isTenant == true) ...[
                        const SizedBox(height: 20),
                        const SectionTitle(
                          'Resident details',
                          subtitle:
                              'Emergency contact remains in the onboarding details workflow.',
                        ),
                        const SizedBox(height: 10),
                        CarmelitaCard(
                          child: Column(
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.cake_outlined),
                                title: const Text('Birth date'),
                                subtitle: Text(
                                  _birthDate == null
                                      ? 'Not specified'
                                      : '${_birthDate!.year.toString().padLeft(4, '0')}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}',
                                ),
                                trailing: TextButton(
                                  onPressed: _pickBirthDate,
                                  child: const Text('Choose'),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _address,
                                maxLines: 2,
                                decoration: const InputDecoration(
                                  labelText: 'Home address',
                                  prefixIcon: Icon(Icons.home_outlined),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _school,
                                decoration: const InputDecoration(
                                  labelText: 'School / institution',
                                  prefixIcon: Icon(Icons.school_outlined),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _course,
                                decoration: const InputDecoration(
                                  labelText: 'Course / program',
                                  prefixIcon: Icon(Icons.menu_book_outlined),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _yearLevel,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Year level',
                                  prefixIcon: Icon(Icons.format_list_numbered),
                                ),
                                validator: (value) {
                                  final clean = value?.trim() ?? '';
                                  if (clean.isEmpty) return null;
                                  final parsed = int.tryParse(clean);
                                  if (parsed == null ||
                                      parsed < 1 ||
                                      parsed > 20) {
                                    return 'Use a year level from 1 to 20.';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(_saving ? 'Saving…' : 'Save profile'),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
