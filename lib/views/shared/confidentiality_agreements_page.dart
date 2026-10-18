import '../../core/widgets/numbered_pagination.dart';
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
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (owner)
            Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                    onPressed: publish,
                    icon: const Icon(Icons.publish_outlined),
                    label: const Text('Publish approved version'))),
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
            const SizedBox(height: 8),
            AgreementRecordPages<Map<String, dynamic>>(
              key: ValueKey('${widget.service.module.key}-versions'),
              items: versions,
              itemLabel: 'versions',
              itemBuilder: (v) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AgreementVersionCard(
                    version: v,
                    current: currentIds.contains(v['id']),
                    onTap: () => open(v, currentIds.contains(v['id']))),
              ),
            ),
            if (owner) ...[
              const SectionTitle('Acceptance verification'),
              const Text(
                  'Current version status is shown separately from historical acceptances. Caretaker access requires a separate permission decision.'),
              const SizedBox(height: 14),
              AgreementRecordPages<Map<String, dynamic>>(
                key: ValueKey('${widget.service.module.key}-accounts'),
                items: accounts,
                itemLabel: 'accounts',
                itemBuilder: (user) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AgreementAcceptanceCard(
                    user: user,
                    versions: versions
                        .where((v) => v['audience'] == user['role'])
                        .toList(),
                    acceptances: acceptances,
                    currentIds: currentIds,
                  ),
                ),
              ),
            ] else ...[
              const SectionTitle('Your acceptance history'),
              AgreementRecordPages<Map<String, dynamic>>(
                key: ValueKey('${widget.service.module.key}-history'),
                items: acceptances,
                itemLabel: 'acceptances',
                itemBuilder: (a) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                      'Version ${versions.where((v) => v['id'] == a['agreement_id']).firstOrNull?['version'] ?? a['agreement_id']} - Accepted ${_agreementDate(context, a['accepted_at'] as String)}'),
                ),
              ),
            ],
          ],
        ]));
  }
}

/// Client-side presentation only. The complete lists still determine current
/// versions and acceptance matching; each section keeps its own page selection.
class AgreementRecordPages<T> extends StatefulWidget {
  const AgreementRecordPages(
      {required this.items,
      required this.itemBuilder,
      required this.itemLabel,
      super.key});
  final List<T> items;
  final Widget Function(T) itemBuilder;
  final String itemLabel;
  @override
  State<AgreementRecordPages<T>> createState() =>
      _AgreementRecordPagesState<T>();
}

class _AgreementRecordPagesState<T> extends State<AgreementRecordPages<T>> {
  static const pageSize = 6;
  int page = 1;
  @override
  void didUpdateWidget(covariant AgreementRecordPages<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) page = 1;
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...widget.items
              .skip((page - 1) * pageSize)
              .take(pageSize)
              .map(widget.itemBuilder),
          NumberedPaginationBar(
              currentPage: page,
              totalItems: widget.items.length,
              pageSize: pageSize,
              itemLabel: widget.itemLabel,
              onPageChanged: (value) => setState(() => page = value)),
        ],
      );
}

// Read-only presentation shared by confidentiality and geofencing agreements.
String _agreementDate(BuildContext context, String value) {
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) return value;
  final local = MaterialLocalizations.of(context);
  return '${local.formatMediumDate(date)} at ${local.formatTimeOfDay(TimeOfDay.fromDateTime(date))}';
}

class AgreementVersionCard extends StatelessWidget {
  const AgreementVersionCard(
      {required this.version,
      required this.current,
      required this.onTap,
      super.key});
  final Map<String, dynamic> version;
  final bool current;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return CarmelitaCard(
      onTap: onTap,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
            backgroundColor: colors.primary.withValues(alpha: .08),
            foregroundColor: colors.primary,
            child: const Icon(Icons.description_outlined)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(
              spacing: 10,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Version ${version['version']}',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                StatusPill(current ? 'Current' : 'Historical'),
              ]),
          const SizedBox(height: 5),
          Text('${version['audience']}'.toUpperCase(),
              style: theme.textTheme.labelSmall
                  ?.copyWith(letterSpacing: .8, color: colors.primary)),
          const SizedBox(height: 8),
          Text(
              'Published ${_agreementDate(context, version['published_at'] as String)}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant)),
        ])),
        const SizedBox(width: 8),
        const Icon(Icons.chevron_right),
      ]),
    );
  }
}

class AgreementAcceptanceCard extends StatelessWidget {
  const AgreementAcceptanceCard(
      {required this.user,
      required this.versions,
      required this.acceptances,
      required this.currentIds,
      super.key});
  final Map<String, dynamic> user;
  final List<Map<String, dynamic>> versions, acceptances;
  final Set<String> currentIds;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return CarmelitaCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
            radius: 18,
            backgroundColor: colors.surfaceContainerLow,
            foregroundColor: colors.primary,
            child: const Icon(Icons.person_outline, size: 20)),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${user['full_name'] ?? 'Account'}',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text('${user['role']}'.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant, letterSpacing: .7)),
        ])),
      ]),
      for (final version in versions) ...[
        const Divider(height: 24),
        Builder(builder: (context) {
          final acceptance = acceptances
              .where((a) =>
                  a['user_id'] == user['id'] &&
                  a['agreement_id'] == version['id'])
              .firstOrNull;
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('Version ${version['version']}',
                          style: theme.textTheme.labelLarge),
                      if (currentIds.contains(version['id']))
                        const StatusPill('Current'),
                      StatusPill(acceptance != null
                          ? 'Accepted'
                          : 'No acceptance recorded'),
                    ]),
                if (acceptance != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Text(
                          'Accepted ${_agreementDate(context, acceptance['accepted_at'] as String)}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant))),
              ]);
        }),
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
