import 'package:flutter/material.dart';

import '../../core/widgets/common_widgets.dart';
import '../../services/onboarding_invitation_service.dart';

/// Multi-step onboarding form the tenant fills in after scanning the QR code.
///
/// The [token] parameter is extracted from the deep link:
///   `carmelink://onboarding?token=<token>`
///
/// Step 1 — Personal review (read-only prefill + editable details)
/// Step 2 — Academic / employment details (optional)
/// Step 3 — Emergency contact (required)
class OnboardingFormPage extends StatefulWidget {
  const OnboardingFormPage({super.key, required this.token});

  final String token;

  @override
  State<OnboardingFormPage> createState() => _OnboardingFormPageState();
}

class _OnboardingFormPageState extends State<OnboardingFormPage> {
  final _service = const OnboardingInvitationService();

  // Claim state
  _ClaimState _claimState = _ClaimState.loading;
  String? _claimError;

  // Step tracking
  int _step = 0;

  // Step 2 — Academic details
  final _schoolCtrl = TextEditingController();
  final _courseCtrl = TextEditingController();
  final _yearLevelCtrl = TextEditingController();

  // Step 3 — Emergency contact
  final _ecNameCtrl = TextEditingController();
  final _ecPhoneCtrl = TextEditingController();
  final _ecRelationshipCtrl = TextEditingController();
  final _step3Key = GlobalKey<FormState>();

  bool _submitting = false;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _claim();
  }

  @override
  void dispose() {
    _schoolCtrl.dispose();
    _courseCtrl.dispose();
    _yearLevelCtrl.dispose();
    _ecNameCtrl.dispose();
    _ecPhoneCtrl.dispose();
    _ecRelationshipCtrl.dispose();
    super.dispose();
  }

  Future<void> _claim() async {
    try {
      await _service.claimInvitation(widget.token);
      if (mounted) {
        setState(() {
          _claimState = _ClaimState.ready;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _claimState = _ClaimState.error;
          _claimError = _friendlyError(error);
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_step3Key.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final yearLevel = int.tryParse(_yearLevelCtrl.text.trim());
      await _service.completeInvitation(
        token: widget.token,
        schoolName: _schoolCtrl.text.trim(),
        courseOrProgram: _courseCtrl.text.trim(),
        yearLevel: yearLevel,
        emergencyContactName: _ecNameCtrl.text.trim(),
        emergencyContactPhone: _ecPhoneCtrl.text.trim(),
        emergencyContactRelationship: _ecRelationshipCtrl.text.trim(),
      );
      if (mounted) setState(() => _completed = true);
    } catch (error) {
      if (mounted) {
        showAppSnackBar(context, _friendlyError(error));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Onboarding Form'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: switch (_claimState) {
          _ClaimState.loading => const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Verifying invitation…'),
                ],
              ),
            ),
          _ClaimState.error => _ErrorView(
              message: _claimError!,
              onRetry: () {
                setState(() {
                  _claimState = _ClaimState.loading;
                  _claimError = null;
                });
                _claim();
              },
            ),
          _ClaimState.ready when _completed => const _SuccessView(),
          _ClaimState.ready => _FormView(
              step: _step,
              schoolCtrl: _schoolCtrl,
              courseCtrl: _courseCtrl,
              yearLevelCtrl: _yearLevelCtrl,
              ecNameCtrl: _ecNameCtrl,
              ecPhoneCtrl: _ecPhoneCtrl,
              ecRelationshipCtrl: _ecRelationshipCtrl,
              step3Key: _step3Key,
              submitting: _submitting,
              onNext: () => setState(() => _step++),
              onBack: () => setState(() => _step--),
              onSubmit: _submit,
            ),
        },
      ),
    );
  }

  static String _friendlyError(Object error) {
    final msg = error.toString();
    if (msg.contains('does not belong to your account')) {
      return 'This invitation link is not for your account. Please scan the QR code sent to you.';
    }
    if (msg.contains('has already been completed')) {
      return 'You have already submitted your onboarding information.';
    }
    if (msg.contains('expired')) {
      return 'This invitation link has expired. Please ask staff to send you a new one.';
    }
    if (msg.contains('revoked')) {
      return 'This invitation link has been cancelled by staff. Please ask for a new one.';
    }
    if (msg.contains('Invalid invitation')) {
      return 'This invitation link is invalid or has been removed.';
    }
    return 'Something went wrong. Please try again or contact your dormitory manager.';
  }
}

// ---------------------------------------------------------------------------
// Internal state enum
// ---------------------------------------------------------------------------

enum _ClaimState { loading, error, ready }

// ---------------------------------------------------------------------------
// Multi-step form
// ---------------------------------------------------------------------------

class _FormView extends StatelessWidget {
  const _FormView({
    required this.step,
    required this.schoolCtrl,
    required this.courseCtrl,
    required this.yearLevelCtrl,
    required this.ecNameCtrl,
    required this.ecPhoneCtrl,
    required this.ecRelationshipCtrl,
    required this.step3Key,
    required this.submitting,
    required this.onNext,
    required this.onBack,
    required this.onSubmit,
  });

  final int step;
  final TextEditingController schoolCtrl;
  final TextEditingController courseCtrl;
  final TextEditingController yearLevelCtrl;
  final TextEditingController ecNameCtrl;
  final TextEditingController ecPhoneCtrl;
  final TextEditingController ecRelationshipCtrl;
  final GlobalKey<FormState> step3Key;
  final bool submitting;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Progress indicator
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(
            children: List.generate(3, (index) {
              final active = index <= step;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: index < 2 ? 6 : 0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: 4,
                    decoration: BoxDecoration(
                      color: active
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: switch (step) {
                0 => _Step1Welcome(key: const ValueKey(0)),
                1 => _Step2Academic(
                    key: const ValueKey(1),
                    schoolCtrl: schoolCtrl,
                    courseCtrl: courseCtrl,
                    yearLevelCtrl: yearLevelCtrl,
                  ),
                _ => _Step3Emergency(
                    key: const ValueKey(2),
                    formKey: step3Key,
                    nameCtrl: ecNameCtrl,
                    phoneCtrl: ecPhoneCtrl,
                    relationshipCtrl: ecRelationshipCtrl,
                  ),
              },
            ),
          ),
        ),
        _NavigationBar(
          step: step,
          totalSteps: 3,
          submitting: submitting,
          onBack: onBack,
          onNext: onNext,
          onSubmit: onSubmit,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Step 1 — Welcome / info
// ---------------------------------------------------------------------------

class _Step1Welcome extends StatelessWidget {
  const _Step1Welcome({super.key});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome to Carmelita\'s Dormitory',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            'This form collects the information your dormitory manager needs to '
            'prepare your rental contract. It only takes a few minutes.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          _InfoTile(
            icon: Icons.school_outlined,
            title: 'Academic details',
            subtitle: 'School, course, and year level (optional)',
          ),
          const SizedBox(height: 12),
          _InfoTile(
            icon: Icons.contact_phone_outlined,
            title: 'Emergency contact',
            subtitle: 'A person staff can reach in an emergency',
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outlined,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your information is stored privately and is only visible '
                    'to your dormitory staff and linked guardian.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}

// ---------------------------------------------------------------------------
// Step 2 — Academic details
// ---------------------------------------------------------------------------

class _Step2Academic extends StatelessWidget {
  const _Step2Academic({
    super.key,
    required this.schoolCtrl,
    required this.courseCtrl,
    required this.yearLevelCtrl,
  });

  final TextEditingController schoolCtrl;
  final TextEditingController courseCtrl;
  final TextEditingController yearLevelCtrl;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Academic / Employment Details',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'All fields on this step are optional.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: schoolCtrl,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'School or employer',
              hintText: 'e.g. University of the Philippines',
              prefixIcon: Icon(Icons.school_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: courseCtrl,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Course or program',
              hintText: 'e.g. BS Computer Science',
              prefixIcon: Icon(Icons.book_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: yearLevelCtrl,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Year level',
              hintText: 'e.g. 2',
              prefixIcon: Icon(Icons.format_list_numbered_rounded),
            ),
          ),
        ],
      );
}

// ---------------------------------------------------------------------------
// Step 3 — Emergency contact
// ---------------------------------------------------------------------------

class _Step3Emergency extends StatelessWidget {
  const _Step3Emergency({
    super.key,
    required this.formKey,
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.relationshipCtrl,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController relationshipCtrl;

  @override
  Widget build(BuildContext context) => Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Emergency Contact',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'This person will be contacted by staff in case of an emergency.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) =>
                  (value?.trim().length ?? 0) < 2 ? 'Enter a full name' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                hintText: 'e.g. 09XX XXX XXXX',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                return trimmed.length < 7 ? 'Enter a valid phone number' : null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: relationshipCtrl,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Relationship',
                hintText: 'e.g. Parent, Sibling, Guardian',
                prefixIcon: Icon(Icons.people_outline),
              ),
              validator: (value) => (value?.trim().length ?? 0) < 2
                  ? 'Enter a relationship'
                  : null,
            ),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
// Navigation bar
// ---------------------------------------------------------------------------

class _NavigationBar extends StatelessWidget {
  const _NavigationBar({
    required this.step,
    required this.totalSteps,
    required this.submitting,
    required this.onBack,
    required this.onNext,
    required this.onSubmit,
  });

  final int step;
  final int totalSteps;
  final bool submitting;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final isLast = step == totalSteps - 1;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(children: [
          if (step > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: submitting ? null : onBack,
                child: const Text('Back'),
              ),
            ),
          if (step > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: submitting ? null : (isLast ? onSubmit : onNext),
              icon: submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(isLast
                      ? Icons.check_rounded
                      : Icons.arrow_forward_rounded),
              label: Text(
                submitting
                    ? 'Submitting…'
                    : isLast
                        ? 'Submit'
                        : 'Next',
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Success screen
// ---------------------------------------------------------------------------

class _SuccessView extends StatelessWidget {
  const _SuccessView();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_outline_rounded,
                    size: 72, color: Colors.green),
              ),
              const SizedBox(height: 24),
              Text(
                'Information Submitted',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Your information has been submitted successfully. Your dormitory '
                'manager will prepare your contract and notify you when it is '
                'ready to review and sign.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: () => Navigator.of(context).popUntil(
                  (route) => route.isFirst,
                ),
                child: const Text('Return to home'),
              ),
            ],
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Error view
// ---------------------------------------------------------------------------

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link_off_rounded,
                  size: 56, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text(
                'Invalid Invitation',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.error,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Info tile helper
// ---------------------------------------------------------------------------

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon,
                size: 20,
                color: Theme.of(context).colorScheme.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        )),
              ],
            ),
          ),
        ],
      );
}
