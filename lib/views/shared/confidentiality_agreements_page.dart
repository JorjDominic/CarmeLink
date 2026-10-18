import 'package:flutter/material.dart';
import '../../controllers/session_controller.dart';
import '../../models/models.dart';
import '../../core/widgets/common_widgets.dart';
import '../../services/confidentiality_agreement_service.dart';

class ConfidentialityAgreementsPage extends StatefulWidget {
  const ConfidentialityAgreementsPage(
      {super.key, this.service = const ConfidentialityAgreementService()});
  final ConfidentialityAgreementService service;
  @override
  State<ConfidentialityAgreementsPage> createState() =>
      _ConfidentialityAgreementsPageState();
}

class _ConfidentialityAgreementsPageState
    extends State<ConfidentialityAgreementsPage> {
  List<Map<String, dynamic>> versions = [], acceptances = [], accounts = [];
  bool loading = true;
  String? error;
  int generation = 0;
  bool get owner =>
      SessionController.instance.currentUser?.role == UserRole.owner;
  bool get participant => {UserRole.tenant, UserRole.guardian}
      .contains(SessionController.instance.currentUser?.role);
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final request = ++generation;
    if (!owner && !participant) {
      setState(() {
        error = 'This page is not available to your account.';
        loading = false;
      });
      return;
    }
    try {
      final v = await widget.service.versions();
      final a = await widget.service.acceptances();
      final users =
          owner ? await widget.service.accounts() : <Map<String, dynamic>>[];
      if (mounted && request == generation)
        setState(() {
          versions = v;
          acceptances = a;
          accounts = users;
          loading = false;
          error = null;
        });
    } catch (_) {
      if (mounted && request == generation)
        setState(() {
          loading = false;
          error =
              'Unable to load agreements. Check your connection or contact the administrator, then retry.';
        });
    }
  }

  Future<void> publish() async {
    final version = TextEditingController(), content = TextEditingController();
    String audience = 'tenant';
    bool approved = false, saving = false;
    final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => StatefulBuilder(
            builder: (context, update) => AlertDialog(
                  scrollable: true,
                  title: Text(
                      'Publish approved ${widget.service.module.title.toLowerCase()} agreement'),
                  content: SizedBox(
                      width: 700,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text(
                            'Use wording approved by the Owner or authorized representative. Published versions cannot be edited or deleted. Users must accept the latest version before accessing this module. Publishing a replacement requires acceptance again.'),
                        DropdownButtonFormField<String>(
                            initialValue: audience,
                            decoration: const InputDecoration(
                                labelText: 'Agreement for'),
                            items: const [
                              DropdownMenuItem(
                                  value: 'tenant', child: Text('Tenant')),
                              DropdownMenuItem(
                                  value: 'guardian', child: Text('Guardian'))
                            ],
                            onChanged: saving
                                ? null
                                : (v) => update(() => audience = v!)),
                        TextField(
                            controller: version,
                            enabled: !saving,
                            maxLength: 80,
                            decoration:
                                const InputDecoration(labelText: 'Version')),
                        TextField(
                            controller: content,
                            enabled: !saving,
                            minLines: 8,
                            maxLines: 16,
                            maxLength: 100000,
                            decoration: const InputDecoration(
                                labelText: 'Exact approved agreement content')),
                        CheckboxListTile(
                            value: approved,
                            contentPadding: EdgeInsets.zero,
                            onChanged: saving
                                ? null
                                : (v) => update(() => approved = v == true),
                            title: const Text(
                                'I confirm this is approved agreement wording.')),
                      ])),
                  actions: [
                    TextButton(
                        onPressed:
                            saving ? null : () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: saving || !approved
                            ? null
                            : () async {
                                if (version.text.trim().isEmpty ||
                                    content.text.trim().length < 20) {
                                  showAppSnackBar(context,
                                      'Enter a version and the complete approved content.');
                                  return;
                                }
                                update(() => saving = true);
                                try {
                                  await widget.service.publish(
                                      audience: audience,
                                      version: version.text,
                                      content: content.text,
                                      approved: approved);
                                  if (context.mounted)
                                    Navigator.pop(context, true);
                                } catch (_) {
                                  if (context.mounted) {
                                    update(() => saving = false);
                                    showAppSnackBar(context,
                                        'Publication failed. Check the version, access and connection, then retry.');
                                  }
                                }
                              },
                        child: Text(saving
                            ? 'Publishing…'
                            : 'Publish approved version')),
                  ],
                )));
    await Future<void>.delayed(const Duration(milliseconds: 250));
    version.dispose();
    content.dispose();
    if (saved == true && mounted) await load();
  }

  Future<void> open(Map<String, dynamic> version, bool current) async {
    final accepted = acceptances
        .where((a) => a['agreement_id'] == version['id'])
        .firstOrNull;
    await Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => AgreementReviewPage(
                version: version,
                acceptedAt:
                    !owner ? (accepted?['accepted_at'] as String?) : null,
                canAccept: participant && current,
                service: widget.service)));
    if (mounted) await load();
  }

  @override
  Widget build(BuildContext context) {
    final currentIds = <String>{};
    final seen = <String>{};
    for (final v in versions) {
      if (seen.add(v['audience'] as String)) currentIds.add(v['id'] as String);
    }
    return PageFrame(
        title: '${widget.service.module.title} agreements',
        subtitle: 'Approved versions and recorded acceptance',
        maxWidth: 1000,
        onRefresh: load,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (owner)
            FilledButton.icon(
                onPressed: publish,
                icon: const Icon(Icons.publish_outlined),
                label: const Text('Publish approved version')),
          const SizedBox(height: 12),
          if (loading)
            const LinearProgressIndicator()
          else if (error != null) ...[
            Text(error!),
            TextButton(onPressed: load, child: const Text('Retry'))
          ] else ...[
            if (versions.isEmpty)
              const CarmelitaCard(
                  child: Text(
                      'No approved agreement has been published. This module stays locked until an owner publishes an agreement and you accept it. Other modules remain available.')),
            for (final v in versions)
              Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: CarmelitaCard(
                      child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${v['audience']} · Version ${v['version']}'),
                    subtitle: Text(
                        '${currentIds.contains(v['id']) ? 'Current' : 'Historical'} · Published ${DateTime.parse(v['published_at'] as String).toLocal()}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => open(v, currentIds.contains(v['id'])),
                  ))),
            if (owner) ...[
              const SectionTitle('Acceptance verification'),
              const Text(
                  'Current version status is shown separately from historical acceptances. Caretaker access requires a separate permission decision.'),
              for (final user in accounts)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: CarmelitaCard(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(
                              '${user['full_name'] ?? 'Account'} · ${user['role']}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          for (final v in versions
                              .where((v) => v['audience'] == user['role']))
                            Text(
                                'Version ${v['version']}${currentIds.contains(v['id']) ? ' (current)' : ''}: ${acceptances.where((a) => a['user_id'] == user['id'] && a['agreement_id'] == v['id']).map((a) => 'Accepted ${DateTime.parse(a['accepted_at'] as String).toLocal()}').firstOrNull ?? 'No acceptance recorded'}'),
                        ]))),
            ] else ...[
              const SectionTitle('Your acceptance history'),
              for (final a in acceptances)
                Text(
                    'Version ${versions.where((v) => v['id'] == a['agreement_id']).firstOrNull?['version'] ?? a['agreement_id']} · Accepted ${DateTime.parse(a['accepted_at'] as String).toLocal()}'),
            ],
          ],
        ]));
  }
}

class AgreementReviewPage extends StatefulWidget {
  const AgreementReviewPage(
      {super.key,
      required this.version,
      required this.canAccept,
      this.acceptedAt,
      this.onAccepted,
      this.onDecline,
      this.service = const ConfidentialityAgreementService()});
  final Map<String, dynamic> version;
  final bool canAccept;
  final String? acceptedAt;
  final Future<void> Function()? onAccepted;
  final VoidCallback? onDecline;
  final ConfidentialityAgreementService service;
  @override
  State<AgreementReviewPage> createState() => _AgreementReviewPageState();
}

class _AgreementReviewPageState extends State<AgreementReviewPage> {
  final scroll = ScrollController();
  bool reviewed = false, checked = false, saving = false, saved = false;
  String? error;
  @override
  void initState() {
    super.initState();
    scroll.addListener(checkReview);
    WidgetsBinding.instance.addPostFrameCallback((_) => checkReview());
  }

  void checkReview() {
    if (mounted &&
        !reviewed &&
        scroll.hasClients &&
        scroll.position.extentAfter <= 4) setState(() => reviewed = true);
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  Future<void> accept() async {
    if (!reviewed || !checked || saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.service.accept(widget.version['id'] as String,
          reviewed: reviewed, accepted: checked);
      if (mounted) setState(() => saved = true);
      if (mounted) await widget.onAccepted?.call();
    } catch (_) {
      if (mounted)
        setState(() => error =
            'Acceptance was not confirmed. Retry, or return and refresh if a newer version was published.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text('Agreement · ${widget.version['version']}')),
      body: SafeArea(
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: ListView(
                      controller: scroll,
                      padding: const EdgeInsets.all(20),
                      children: [
                        Text(
                            '${widget.version['audience']} ${widget.service.module.title.toLowerCase()} agreement',
                            style: Theme.of(context).textTheme.titleLarge),
                        Text(
                            'Published ${DateTime.parse(widget.version['published_at'] as String).toLocal()}'),
                        const SizedBox(height: 20),
                        SelectableText(widget.version['content'] as String),
                        const SizedBox(height: 24),
                        if (widget.acceptedAt != null || saved)
                          Text(
                              saved
                                  ? 'Acceptance saved successfully.'
                                  : 'Accepted ${DateTime.parse(widget.acceptedAt!).toLocal()}.',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700))
                        else if (widget.canAccept) ...[
                          const Text(
                              'Review the complete agreement, then explicitly select the checkbox and accept.'),
                          CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: checked,
                              onChanged: saving || !reviewed
                                  ? null
                                  : (v) => setState(() => checked = v == true),
                              title: const Text(
                                  'I have reviewed and accept this agreement version.')),
                          if (error != null) Text(error!),
                          FilledButton(
                              onPressed: reviewed && checked && !saving
                                  ? accept
                                  : null,
                              child: Text(saving
                                  ? 'Saving acceptance…'
                                  : widget.onAccepted != null
                                      ? 'Accept and continue'
                                      : 'Accept agreement')),
                          if (widget.onDecline != null)
                            TextButton(
                                onPressed: saving ? null : widget.onDecline,
                                child: const Text('Decline and go back')),
                        ] else
                          const Text(
                              'Historical agreement. Review the current version to record a new acceptance.'),
                      ])))));
}
