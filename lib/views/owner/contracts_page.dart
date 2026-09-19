import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';

import '../../controllers/owner_controller.dart';
import '../../core/widgets/common_widgets.dart';
import '../../models/models.dart';
import '../../services/contract_document_service.dart';
import '../../services/guardian_link_service.dart';
import '../../services/tenant_service.dart';
import 'tenant_onboarding_flow.dart';

Future<bool?> showContractEditor(
  BuildContext context, {
  TenantContract? contract,
  String? initialTenantId,
  String? initialTenantName,
  bool lockTenant = false,
}) async {
  final saved = await showDialog<TenantContract>(
    context: context,
    builder: (_) => _ContractEditor(
      contract: contract,
      initialTenantId: initialTenantId,
      initialTenantName: initialTenantName,
      lockTenant: lockTenant,
    ),
  );
  if (saved == null) return null;
  return true;
}

class ContractsPage extends StatefulWidget {
  const ContractsPage({super.key});

  @override
  State<ContractsPage> createState() => _ContractsPageState();
}

class _ContractsPageState extends State<ContractsPage> {
  final _search = TextEditingController();
  String _status = 'all';

  @override
  void initState() {
    super.initState();
    OwnerController.instance.loadContracts();
    OwnerController.instance.loadTenants();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: OwnerController.instance,
        builder: (context, _) {
          final controller = OwnerController.instance;
          final query = _search.text.trim().toLowerCase();
          final items = controller.contracts.where((contract) {
            final matchesStatus =
                _status == 'all' || contract.status == _status;
            final matchesQuery = query.isEmpty ||
                contract.tenantName.toLowerCase().contains(query) ||
                contract.contractNumber.toLowerCase().contains(query);
            return matchesStatus && matchesQuery;
          }).toList();

          return PageFrame(
            title: 'Contracts',
            subtitle: 'Create and maintain tenant contract records',
            onRefresh: () => controller.loadContracts(force: true),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add),
              label: const Text('New contract'),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Search tenant or contract number',
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children:
                        ['all', 'draft', 'active', 'expired', 'terminated']
                            .map((value) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    selected: _status == value,
                                    label: Text(_title(value)),
                                    onSelected: (_) =>
                                        setState(() => _status = value),
                                  ),
                                ))
                            .toList(),
                  ),
                ),
                const SizedBox(height: 14),
                if (controller.contractsLoading &&
                    !controller.contractsLoadedOnce)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  )
                else if (controller.contractsError != null &&
                    !controller.contractsLoadedOnce)
                  EmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: 'Contracts could not be loaded',
                    message: controller.contractsError!,
                    action: FilledButton(
                      onPressed: () => controller.loadContracts(force: true),
                      child: const Text('Retry'),
                    ),
                  )
                else if (items.isEmpty)
                  EmptyState(
                    icon: Icons.description_outlined,
                    title: 'No contracts found',
                    message: query.isEmpty && _status == 'all'
                        ? 'Create the first tenant contract.'
                        : 'Try a different search or status filter.',
                  )
                else
                  LayoutBuilder(builder: (context, constraints) {
                    final enlargedText =
                        MediaQuery.textScalerOf(context).scale(1) > 1.15;
                    final columns = constraints.maxWidth >= 1000
                        ? 3
                        : constraints.maxWidth >= 650
                            ? 2
                            : 1;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        mainAxisExtent: enlargedText ? 530 : 410,
                      ),
                      itemBuilder: (_, index) => _ContractCard(
                        contract: items[index],
                        onEdit: () => _openEditor(items[index]),
                        onDelete: () => _delete(items[index]),
                        onDocuments: () => _openDocuments(items[index]),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      );

  Future<void> _openEditor([TenantContract? contract]) async {
    await showContractEditor(context, contract: contract);
  }

  Future<void> _delete(TenantContract contract) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete contract?'),
        content: Text(
            'Delete ${contract.contractNumber} for ${contract.tenantName}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await OwnerController.instance.deleteContract(contract.id);
      if (mounted) showAppSnackBar(context, 'Contract deleted.');
    } catch (error) {
      if (mounted)
        showAppSnackBar(context, 'Failed to delete contract: $error');
    }
  }

  Future<void> _openDocuments(TenantContract contract) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ContractDocumentsDialog(contract: contract),
    );
    await OwnerController.instance.loadContracts(force: true);
  }

  String _title(String value) =>
      value == 'all' ? 'All' : '${value[0].toUpperCase()}${value.substring(1)}';
}

class _ContractCard extends StatelessWidget {
  const _ContractCard(
      {required this.contract,
      required this.onEdit,
      required this.onDelete,
      required this.onDocuments});
  final TenantContract contract;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDocuments;

  @override
  Widget build(BuildContext context) {
    String date(DateTime value) =>
        '${_months[value.month - 1]} ${value.day}, ${value.year}';
    String money(double value) => '₱${value.toStringAsFixed(2)}';
    return CarmelitaCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(contract.tenantName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800))),
          StatusPill(contract.status),
        ]),
        Text(contract.contractNumber,
            style: Theme.of(context).textTheme.bodySmall),
        const Divider(height: 22),
        InfoRow(
            label: 'Term',
            value: '${date(contract.startsOn)} – ${date(contract.endsOn)}'),
        InfoRow(label: 'Monthly rent', value: money(contract.monthlyRent)),
        InfoRow(label: 'Deposit', value: money(contract.securityDeposit)),
        const SizedBox(height: 6),
        Row(children: [
          const Icon(Icons.verified_user_outlined, size: 17),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              _signatureLabel(contract.signatureStatus),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ]),
        const Spacer(),
        Wrap(alignment: WrapAlignment.end, spacing: 2, children: [
          TextButton.icon(
              onPressed: onDocuments,
              icon: const Icon(Icons.description_outlined),
              label: const Text('Documents')),
          IconButton(
              tooltip: 'Edit contract',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined)),
          IconButton(
              tooltip: 'Delete contract',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline)),
        ]),
      ]),
    );
  }

  String _signatureLabel(String status) => switch (status) {
        'awaiting_signature' => 'Awaiting signed copy',
        'pending_verification' => 'Signature review pending',
        'verified' => 'Signed document verified',
        'rejected' => 'Signed document rejected',
        _ => 'PDF not generated',
      };
}

class _ContractDocumentsDialog extends StatefulWidget {
  const _ContractDocumentsDialog({required this.contract});
  final TenantContract contract;

  @override
  State<_ContractDocumentsDialog> createState() =>
      _ContractDocumentsDialogState();
}

class _ContractDocumentsDialogState extends State<_ContractDocumentsDialog> {
  final _service = const ContractDocumentService();
  late Future<List<ContractDocument>> _documents =
      _service.listDocuments(widget.contract.id);
  late Future<_OnboardingNeeds> _onboardingNeeds = _loadOnboardingNeeds();
  bool _working = false;

  Future<_OnboardingNeeds> _loadOnboardingNeeds() async {
    final results = await Future.wait<dynamic>([
      const TenantService().loadTenants(forceRefresh: true),
      const GuardianLinkService().listLinks(),
    ]);
    final tenants = results[0] as List<TenantDirectoryEntry>;
    final links = results[1] as List<Map<String, dynamic>>;
    final tenant = tenants
        .where((item) => item.id == widget.contract.tenantId)
        .firstOrNull;
    return _OnboardingNeeds(
      needsBed: tenant?.assignmentId == null,
      needsGuardian:
          !links.any((link) => link['tenant_id'] == widget.contract.tenantId),
    );
  }

  void _reloadOnboardingNeeds() {
    if (!mounted) return;
    setState(() {
      _onboardingNeeds = _loadOnboardingNeeds();
    });
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _documents = _service.listDocuments(widget.contract.id);
    });
  }

  Future<void> _generate() async {
    setState(() => _working = true);
    try {
      final generated = await _service.generateContract(widget.contract);
      await Printing.sharePdf(
        bytes: generated.bytes,
        filename: generated.document.originalFilename,
      );
      if (mounted) {
        showAppSnackBar(context,
            'Contract version ${generated.document.version} generated.');
        _reload();
      }
    } catch (error) {
      if (mounted) showAppSnackBar(context, 'Could not generate PDF: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _uploadSigned(int version) async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    final extension = file.extension?.toLowerCase();
    final mimeType = switch (extension) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      _ => 'image/jpeg',
    };
    setState(() => _working = true);
    try {
      await _service.uploadSigned(
        contract: widget.contract,
        version: version,
        filename: file.name,
        mimeType: mimeType,
        bytes: bytes,
      );
      if (mounted) {
        showAppSnackBar(context, 'Signed contract uploaded for review.');
        _reload();
      }
    } catch (error) {
      if (mounted) showAppSnackBar(context, 'Upload failed: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _deleteVersion(
    int version,
    List<ContractDocument> documents,
  ) async {
    if (widget.contract.status == 'active') {
      showAppSnackBar(
        context,
        'Active contract documents cannot be deleted. Terminate the contract first.',
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete contract documents?'),
        content: Text(
          'Delete the generated and signed files for version $version? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _working = true);
    try {
      await _service.deleteVersion(
        contractId: widget.contract.id,
        version: version,
        storagePaths: documents.map((item) => item.storagePath).toList(),
      );
      if (mounted) {
        showAppSnackBar(context, 'Contract document version deleted.');
        _reload();
      }
    } catch (error) {
      if (mounted) showAppSnackBar(context, 'Delete failed: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _continueOnboarding() async {
    await continueTenantOnboarding(
      context,
      tenantId: widget.contract.tenantId,
      tenantName: widget.contract.tenantName,
    );
    _reloadOnboardingNeeds();
  }

  Future<void> _open(ContractDocument document) async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => _ContractDocumentViewer(
          document: document,
          service: _service,
        ),
      ),
    );
  }

  Future<void> _review(ContractDocument document, bool approve) async {
    final notes = await showDialog<String>(
      context: context,
      builder: (_) => _ContractReviewDialog(approve: approve),
    );
    if (notes == null || !mounted) return;
    setState(() => _working = true);
    try {
      await _service.reviewSignedDocument(
        documentId: document.id,
        approve: approve,
        notes: notes,
      );
      if (mounted) {
        showAppSnackBar(context,
            approve ? 'Signed contract verified.' : 'Document rejected.');
        _reload();
        if (approve) {
          await continueTenantOnboarding(
            context,
            tenantId: widget.contract.tenantId,
            tenantName: widget.contract.tenantName,
          );
          _reloadOnboardingNeeds();
        }
      }
    } catch (error) {
      if (mounted) showAppSnackBar(context, 'Review failed: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final content = FutureBuilder<List<ContractDocument>>(
      future: _documents,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return EmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Documents could not be loaded',
            message: snapshot.error.toString(),
            action:
                FilledButton(onPressed: _reload, child: const Text('Retry')),
          );
        }
        final documents = snapshot.data ?? const [];
        final generated = documents.where((item) => item.isGenerated).toList();
        final signed = documents.where((item) => item.isSigned).toList();
        final latestVersion = generated.isEmpty
            ? null
            : generated.map((e) => e.version).reduce((a, b) => a > b ? a : b);
        final latestSigned = latestVersion == null
            ? null
            : documents
                .where((item) => item.isSigned && item.version == latestVersion)
                .firstOrNull;
        final currentSignatureStatus = latestVersion == null
            ? 'not_generated'
            : latestSigned == null
                ? 'awaiting_signature'
                : latestSigned.reviewStatus == 'verified'
                    ? 'verified'
                    : latestSigned.reviewStatus == 'rejected'
                        ? 'rejected'
                        : 'pending_verification';
        final versions = documents.map((item) => item.version).toSet().toList()
          ..sort((a, b) => b.compareTo(a));
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(children: [
                Icon(Icons.description_outlined,
                    color: Theme.of(context).colorScheme.onPrimaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.contract.contractNumber,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      Text(widget.contract.tenantName),
                    ],
                  ),
                ),
                StatusPill(_signatureLabel(currentSignatureStatus)),
              ]),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _working || generated.isNotEmpty ? null : _generate,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: Text(generated.isEmpty
                  ? 'Generate printable PDF'
                  : 'Printable contract already generated'),
            ),
            if (latestVersion != null && signed.isEmpty) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _working ? null : () => _uploadSigned(latestVersion),
                icon: const Icon(Icons.upload_file_outlined),
                label: Text('Upload signed copy for version $latestVersion'),
              ),
            ],
            if (latestSigned?.reviewStatus == 'verified') ...[
              const SizedBox(height: 10),
              FutureBuilder<_OnboardingNeeds>(
                future: _onboardingNeeds,
                builder: (context, onboardingSnapshot) {
                  final needs = onboardingSnapshot.data;
                  if (needs != null && !needs.hasRemainingSteps) {
                    return const SizedBox.shrink();
                  }
                  final label = needs == null
                      ? 'Checking onboarding status...'
                      : needs.needsBed && needs.needsGuardian
                          ? 'Continue tenant onboarding'
                          : needs.needsBed
                              ? 'Continue room assignment'
                              : 'Continue guardian linking';
                  return FilledButton.tonalIcon(
                    onPressed:
                        _working || needs == null ? null : _continueOnboarding,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text(label),
                  );
                },
              ),
            ],
            const SizedBox(height: 24),
            Text('Document history',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            if (documents.isEmpty)
              const EmptyState(
                icon: Icons.folder_open_outlined,
                title: 'No contract documents',
                message: 'Generate the first printable version to begin.',
              )
            else
              ...versions.map((version) {
                final versionDocuments =
                    documents.where((item) => item.version == version).toList();
                return _DocumentVersionCard(
                  version: version,
                  documents: versionDocuments,
                  working: _working,
                  onOpen: _open,
                  onReview: _review,
                  onDelete: () => _deleteVersion(version, versionDocuments),
                );
              }),
          ],
        );
      },
    );

    if (compact) {
      return Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close)),
            title: const Text('Contract documents'),
          ),
          body: content,
        ),
      );
    }
    return Dialog(
      child: SizedBox(
        width: 720,
        height: 760,
        child: Column(children: [
          ListTile(
            title: const Text('Contract documents'),
            subtitle: const Text('Generate, upload, and verify signed copies'),
            trailing: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close)),
          ),
          const Divider(height: 1),
          Expanded(child: content),
        ]),
      ),
    );
  }

  String _signatureLabel(String value) => switch (value) {
        'awaiting_signature' => 'Awaiting signature',
        'pending_verification' => 'Pending review',
        'verified' => 'Verified',
        'rejected' => 'Rejected',
        _ => 'Not generated',
      };
}

class _OnboardingNeeds {
  const _OnboardingNeeds({
    required this.needsBed,
    required this.needsGuardian,
  });

  final bool needsBed;
  final bool needsGuardian;
  bool get hasRemainingSteps => needsBed || needsGuardian;
}

class _DocumentVersionCard extends StatelessWidget {
  const _DocumentVersionCard({
    required this.version,
    required this.documents,
    required this.working,
    required this.onOpen,
    required this.onReview,
    required this.onDelete,
  });

  final int version;
  final List<ContractDocument> documents;
  final bool working;
  final ValueChanged<ContractDocument> onOpen;
  final void Function(ContractDocument document, bool approve) onReview;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final generated = documents.where((item) => item.isGenerated).firstOrNull;
    final signed = documents.where((item) => item.isSigned).firstOrNull;
    final status = signed?.reviewStatus ?? 'not_required';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CarmelitaCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.description_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Contract document • Version $version',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              StatusPill(_reviewLabel(status)),
            ]),
            if (generated != null) ...[
              const SizedBox(height: 10),
              _DocumentFileRow(
                label: 'Original PDF',
                document: generated,
                dateLabel: 'Created',
                onOpen: () => onOpen(generated),
              ),
            ],
            if (signed != null) ...[
              const SizedBox(height: 10),
              _DocumentFileRow(
                label: 'Signed copy',
                document: signed,
                dateLabel: 'Signed/uploaded',
                onOpen: () => onOpen(signed),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, children: [
              if (signed?.isPending == true)
                TextButton.icon(
                  onPressed: working ? null : () => onReview(signed!, true),
                  icon: const Icon(Icons.verified_outlined, size: 18),
                  label: const Text('Verify'),
                ),
              if (signed?.isPending == true)
                TextButton.icon(
                  onPressed: working ? null : () => onReview(signed!, false),
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Reject'),
                ),
              TextButton.icon(
                onPressed: working ? null : onDelete,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Delete version'),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  static String _reviewLabel(String value) => switch (value) {
        'pending' => 'Pending',
        'verified' => 'Verified',
        'rejected' => 'Rejected',
        _ => 'Original',
      };
}

class _DocumentFileRow extends StatelessWidget {
  const _DocumentFileRow({
    required this.label,
    required this.document,
    required this.dateLabel,
    required this.onOpen,
  });

  final String label;
  final ContractDocument document;
  final String dateLabel;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(document.isGenerated
                  ? Icons.picture_as_pdf_outlined
                  : Icons.draw_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              TextButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('View'),
              ),
            ]),
            Text(
              document.originalFilename,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 3),
            Text(
              '$dateLabel ${shortDate(document.uploadedAt)} • ${timeText(document.uploadedAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
}

class _ContractReviewDialog extends StatefulWidget {
  const _ContractReviewDialog({required this.approve});

  final bool approve;

  @override
  State<_ContractReviewDialog> createState() => _ContractReviewDialogState();
}

class _ContractReviewDialogState extends State<_ContractReviewDialog> {
  final _notes = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _notes.text.trim();
    if (value.length < 3) {
      setState(() => _error = 'Enter review notes of at least 3 characters.');
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.approve
            ? 'Verify signed contract?'
            : 'Reject signed contract?'),
        content: TextField(
          controller: _notes,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: 'Review notes',
            hintText: widget.approve
                ? 'Confirm signatures and document completeness'
                : 'Explain what must be corrected',
            errorText: _error,
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _submit,
            child: Text(widget.approve ? 'Verify document' : 'Reject document'),
          ),
        ],
      );
}

class _ContractDocumentViewer extends StatefulWidget {
  const _ContractDocumentViewer({
    required this.document,
    required this.service,
  });

  final ContractDocument document;
  final ContractDocumentService service;

  @override
  State<_ContractDocumentViewer> createState() =>
      _ContractDocumentViewerState();
}

class _ContractDocumentViewerState extends State<_ContractDocumentViewer> {
  late Future<Uint8List> _bytes =
      widget.service.downloadDocument(widget.document.storagePath);

  void _retry() => setState(() {
        _bytes = widget.service.downloadDocument(widget.document.storagePath);
      });

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(
            widget.document.originalFilename,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: FutureBuilder<Uint8List>(
          future: _bytes,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return EmptyState(
                icon: Icons.cloud_off_outlined,
                title: 'Document could not be opened',
                message: snapshot.error?.toString() ?? 'No file data received.',
                action: FilledButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              );
            }
            final bytes = snapshot.data!;
            if (widget.document.mimeType == 'application/pdf') {
              return PdfPreview(
                build: (_) async => bytes,
                pdfFileName: widget.document.originalFilename,
                canChangeOrientation: false,
                canChangePageFormat: false,
                canDebug: false,
                allowPrinting: true,
                allowSharing: true,
                loadingWidget: const Center(child: CircularProgressIndicator()),
              );
            }
            return ColoredBox(
              color: Colors.black,
              child: Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5,
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.contain,
                    errorBuilder: (_, error, __) => EmptyState(
                      icon: Icons.broken_image_outlined,
                      title: 'Image could not be displayed',
                      message: error.toString(),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
}

class _ContractEditor extends StatefulWidget {
  const _ContractEditor({
    this.contract,
    this.initialTenantId,
    this.initialTenantName,
    this.lockTenant = false,
  });
  final TenantContract? contract;
  final String? initialTenantId;
  final String? initialTenantName;
  final bool lockTenant;
  @override
  State<_ContractEditor> createState() => _ContractEditorState();
}

class _ContractEditorState extends State<_ContractEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _number;
  late final TextEditingController _rent;
  late final TextEditingController _deposit;
  late final TextEditingController _notes;
  late String? _tenantId;
  late String _status;
  late DateTime _start;
  late DateTime _end;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final value = widget.contract;
    _number = TextEditingController(text: value?.contractNumber ?? '');
    _rent = TextEditingController(
        text: value?.monthlyRent.toStringAsFixed(2) ?? '');
    _deposit = TextEditingController(
        text: value?.securityDeposit.toStringAsFixed(2) ?? '0');
    _notes = TextEditingController(text: value?.notes ?? '');
    _tenantId = value?.tenantId ?? widget.initialTenantId;
    _status = value?.status ?? 'draft';
    _start = value?.startsOn ?? DateTime.now();
    _end = value?.endsOn ?? DateTime.now().add(const Duration(days: 365));
  }

  @override
  void dispose() {
    _number.dispose();
    _rent.dispose();
    _deposit.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tenants = [...OwnerController.instance.tenants];
    if (_tenantId != null && !tenants.any((tenant) => tenant.id == _tenantId)) {
      tenants.add(TenantDirectoryEntry(
        id: _tenantId!,
        name: widget.initialTenantName ?? 'New tenant',
        room: 'Unassigned',
        bedSpace: 'Unassigned',
        phone: '',
        guardianName: '',
        guardianPhone: '',
      ));
    }
    final compact = MediaQuery.sizeOf(context).width < 600;
    final title = widget.contract == null ? 'Create contract' : 'Edit contract';
    final form = _buildForm(tenants, compact);

    if (compact) {
      return Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Close',
              onPressed: _saving ? null : () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
            title: Text(title),
            centerTitle: false,
          ),
          body: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              child: form,
            ),
          ),
          bottomNavigationBar: _EditorActions(
            saving: _saving,
            onCancel: () => Navigator.pop(context),
            onSave: _save,
          ),
        ),
      );
    }

    return Dialog(
      insetPadding: const EdgeInsets.all(32),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 820),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 20, 16),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    Text('Complete the agreement details below.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: _saving ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ]),
          ),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: form,
            ),
          ),
          _EditorActions(
            saving: _saving,
            onCancel: () => Navigator.pop(context),
            onSave: _save,
          ),
        ]),
      ),
    );
  }

  Widget _buildForm(List<TenantDirectoryEntry> tenants, bool compact) => Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _FormSectionHeading(
            icon: Icons.person_outline,
            title: 'Tenant and agreement',
            subtitle: 'Choose the resident and identify this contract.',
          ),
          const SizedBox(height: 14),
          if (widget.lockTenant)
            _LockedTenantField(
              name: tenants.firstWhere((tenant) => tenant.id == _tenantId).name,
            )
          else
            DropdownButtonFormField<String>(
              initialValue: _tenantId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Tenant',
                prefixIcon: Icon(Icons.person_outline),
              ),
              items: tenants
                  .map((tenant) => DropdownMenuItem(
                      value: tenant.id, child: Text(tenant.name)))
                  .toList(),
              onChanged: (value) => setState(() => _tenantId = value),
              validator: (value) => value == null ? 'Select a tenant' : null,
            ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _number,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Contract number',
              hintText: 'e.g. CTR-2026-001',
              prefixIcon: Icon(Icons.tag_outlined),
            ),
            validator: (value) => (value?.trim().length ?? 0) < 3
                ? 'Enter at least 3 characters'
                : null,
          ),
          const SizedBox(height: 28),
          const _FormSectionHeading(
            icon: Icons.payments_outlined,
            title: 'Financial terms',
            subtitle: 'Enter amounts in Philippine pesos.',
          ),
          const SizedBox(height: 14),
          _ResponsivePair(
            stacked: compact,
            first: TextFormField(
              controller: _rent,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Monthly rent',
                prefixText: '₱ ',
              ),
              validator: _moneyValidator,
            ),
            second: TextFormField(
              controller: _deposit,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Security deposit',
                prefixText: '₱ ',
              ),
              validator: _moneyValidator,
            ),
          ),
          const SizedBox(height: 28),
          const _FormSectionHeading(
            icon: Icons.calendar_month_outlined,
            title: 'Contract period',
            subtitle: 'Set the inclusive start and end dates.',
          ),
          const SizedBox(height: 14),
          _ResponsivePair(
            stacked: compact,
            first: _DateField(
              label: 'Start date',
              value: _start,
              onChanged: (value) => setState(() => _start = value),
            ),
            second: _DateField(
              label: 'End date',
              value: _end,
              onChanged: (value) => setState(() => _end = value),
            ),
          ),
          const SizedBox(height: 28),
          const _FormSectionHeading(
            icon: Icons.fact_check_outlined,
            title: 'Status and notes',
            subtitle: 'New agreements should normally remain Draft.',
          ),
          const SizedBox(height: 14),
          Text('Contract status',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['draft', 'active', 'expired', 'terminated']
                .map((status) => ChoiceChip(
                      selected: _status == status,
                      label: Text(_titleCase(status)),
                      onSelected: (_) => setState(() => _status = status),
                    ))
                .toList(),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _notes,
            minLines: 3,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Notes',
              hintText: 'Optional internal notes about this agreement',
              alignLabelWithHint: true,
            ),
          ),
        ]),
      );

  String _titleCase(String value) =>
      '${value[0].toUpperCase()}${value.substring(1)}';

  String? _moneyValidator(String? value) {
    final amount = double.tryParse(value?.trim() ?? '');
    return amount == null || amount < 0 ? 'Enter a valid amount' : null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_end.isBefore(_start)) {
      showAppSnackBar(context, 'End date must be on or after the start date.');
      return;
    }
    setState(() => _saving = true);
    try {
      final controller = OwnerController.instance;
      final existing = widget.contract;
      late final TenantContract saved;
      if (existing == null) {
        saved = await controller.createContract(
          tenantId: _tenantId!,
          contractNumber: _number.text,
          startsOn: _start,
          endsOn: _end,
          monthlyRent: double.parse(_rent.text),
          securityDeposit: double.parse(_deposit.text),
          status: _status,
          notes: _notes.text,
        );
      } else {
        TenantDirectoryEntry? tenant;
        for (final value in controller.tenants) {
          if (value.id == _tenantId) {
            tenant = value;
            break;
          }
        }
        saved = await controller.updateContract(existing.copyWith(
          tenantId: _tenantId!,
          tenantName: tenant?.name ?? existing.tenantName,
          contractNumber: _number.text,
          startsOn: _start,
          endsOn: _end,
          monthlyRent: double.parse(_rent.text),
          securityDeposit: double.parse(_deposit.text),
          status: _status,
          notes: _notes.text,
        ));
      }
      if (mounted) Navigator.pop(context, saved);
    } catch (error) {
      if (mounted) showAppSnackBar(context, 'Failed to save contract: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _FormSectionHeading extends StatelessWidget {
  const _FormSectionHeading({
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
                size: 21,
                color: Theme.of(context).colorScheme.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      );
}

class _LockedTenantField extends StatelessWidget {
  const _LockedTenantField({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Row(children: [
          const Icon(Icons.person_outline),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tenant', style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 2),
                Text(name,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Icon(Icons.lock_outline,
              size: 19, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ]),
      );
}

class _ResponsivePair extends StatelessWidget {
  const _ResponsivePair({
    required this.stacked,
    required this.first,
    required this.second,
  });
  final bool stacked;
  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    if (stacked) {
      return Column(children: [first, const SizedBox(height: 14), second]);
    }
    return Row(children: [
      Expanded(child: first),
      const SizedBox(width: 14),
      Expanded(child: second),
    ]);
  }
}

class _EditorActions extends StatelessWidget {
  const _EditorActions({
    required this.saving,
    required this.onCancel,
    required this.onSave,
  });
  final bool saving;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.surface,
        elevation: 8,
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: saving ? null : onCancel,
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: saving ? null : onSave,
                icon: saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_outlined),
                label: Text(saving ? 'Saving…' : 'Save contract'),
              ),
            ),
          ]),
        ),
      );
}

class _DateField extends StatelessWidget {
  const _DateField(
      {required this.label, required this.value, required this.onChanged});
  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label:
            '$label, ${_months[value.month - 1]} ${value.day}, ${value.year}',
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final picked = await showDatePicker(
                context: context,
                initialDate: value,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100));
            if (picked != null) onChanged(picked);
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: const Icon(Icons.calendar_today_outlined),
              suffixIcon: const Icon(Icons.arrow_drop_down),
            ),
            child: Text(
              '${_months[value.month - 1]} ${value.day}, ${value.year}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
      );
}

const _months = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
