import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../core/widgets/common_widgets.dart';
import '../../models/models.dart';
import '../../services/contract_onboarding_service.dart';

Future<void> showContractOnboardingChecklist(
  BuildContext context, {
  required TenantContract contract,
}) =>
    showDialog<void>(
      context: context,
      builder: (_) => ContractOnboardingChecklistPage(contract: contract),
    );

class ContractOnboardingChecklistPage extends StatefulWidget {
  const ContractOnboardingChecklistPage({
    super.key,
    required this.contract,
  });

  final TenantContract contract;

  @override
  State<ContractOnboardingChecklistPage> createState() =>
      _ContractOnboardingChecklistPageState();
}

class _ContractOnboardingChecklistPageState
    extends State<ContractOnboardingChecklistPage> {
  final _service = const ContractOnboardingService();
  late Future<_ChecklistData> _future = _load();
  bool _working = false;

  Future<_ChecklistData> _load() async {
    final results = await Future.wait([
      _service.listRequirements(widget.contract.id),
      _service.listSigners(widget.contract.id),
    ]);
    return _ChecklistData(
      requirements: results[0] as List<ContractRequirement>,
      signers: results[1] as List<ContractSigner>,
    );
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _upload(ContractRequirement item) async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();

    var physicalReceived = false;
    var signatureCount = 0;
    if (item.type == 'signed_photocopies') {
      final metadata = await showDialog<_PhotocopyMetadata>(
        context: context,
        builder: (_) => const _PhotocopyMetadataDialog(),
      );
      if (metadata == null || !mounted) return;
      physicalReceived = metadata.physicalCopyReceived;
      signatureCount = metadata.signatureCount;
    }

    setState(() => _working = true);
    try {
      await _service.submitRequirement(
        requirement: item,
        filename: file.name,
        mimeType: _mimeType(file.extension),
        bytes: bytes,
        physicalCopyReceived: physicalReceived,
        signatureCount: signatureCount,
      );
      if (mounted) {
        showAppSnackBar(context, '${item.label} submitted for review.');
        _reload();
      }
    } catch (error) {
      if (mounted) showAppSnackBar(context, 'Upload failed: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _review(ContractRequirement item, bool approve) async {
    final notes = await _prompt(
      title: approve ? 'Verify document' : 'Reject document',
      label: 'Review notes',
    );
    if (notes == null || !mounted) return;
    setState(() => _working = true);
    try {
      await _service.reviewRequirement(
        requirementId: item.id,
        approve: approve,
        notes: notes,
      );
      if (mounted) {
        showAppSnackBar(
            context, approve ? 'Document verified.' : 'Document rejected.');
        _reload();
      }
    } catch (error) {
      if (mounted) showAppSnackBar(context, 'Review failed: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _open(ContractRequirement item) async {
    final path = item.storagePath;
    if (path == null) return;
    setState(() => _working = true);
    try {
      final bytes = await _service.downloadRequirement(path);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => _RequirementViewer(
          title: item.label,
          mimeType: _mimeType(item.originalFilename?.split('.').last),
          bytes: bytes,
        ),
      );
    } catch (error) {
      if (mounted) showAppSnackBar(context, 'Could not open document: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _toggleGuardianRequirement(
    ContractRequirement item,
    bool required,
  ) async {
    setState(() => _working = true);
    try {
      await _service.setGuardianRequired(
        requirementId: item.id,
        required: required,
      );
      if (mounted) _reload();
    } catch (error) {
      if (mounted)
        showAppSnackBar(context, 'Could not update requirement: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _configureSigner(ContractSigner signer) async {
    final result = await showDialog<_SignerUpdate>(
      context: context,
      builder: (_) => _SignerDialog(signer: signer),
    );
    if (result == null || !mounted) return;
    setState(() => _working = true);
    try {
      await _service.updateSigner(
        signer: signer,
        status: result.status,
        signerName: result.name,
        notes: result.notes,
        required: result.required,
      );
      if (mounted) {
        showAppSnackBar(context, '${signer.label} updated.');
        _reload();
      }
    } catch (error) {
      if (mounted) showAppSnackBar(context, 'Signer update failed: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<String?> _prompt(
      {required String title, required String label}) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.length >= 3) Navigator.pop(context, value);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  String _mimeType(String? extension) => switch (extension?.toLowerCase()) {
        'pdf' => 'application/pdf',
        'png' => 'image/png',
        _ => 'image/jpeg',
      };

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 650;
    final body = FutureBuilder<_ChecklistData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return EmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Checklist unavailable',
            message: snapshot.error.toString(),
            action:
                FilledButton(onPressed: _reload, child: const Text('Retry')),
          );
        }
        final data = snapshot.data!;
        final requiredDocuments = data.requirements.where((e) => e.isRequired);
        final requiredSigners = data.signers.where((e) => e.isRequired);
        final complete = requiredDocuments.every((e) => e.isVerified) &&
            requiredSigners.every((e) => e.isVerified);
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            CarmelitaCard(
              child: Row(
                children: [
                  Icon(
                    complete
                        ? Icons.verified_rounded
                        : Icons.fact_check_outlined,
                    color: complete
                        ? Colors.green
                        : Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          complete
                              ? 'Required checklist complete'
                              : 'Onboarding requirements',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(widget.contract.tenantName),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text('Required documents',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...data.requirements.map((item) => _RequirementCard(
                  item: item,
                  working: _working,
                  onUpload: () => _upload(item),
                  onOpen: () => _open(item),
                  onApprove: () => _review(item, true),
                  onReject: () => _review(item, false),
                  onRequiredChanged: item.type == 'guardian_identity'
                      ? (value) => _toggleGuardianRequirement(item, value)
                      : null,
                )),
            const SizedBox(height: 22),
            Text('Contract signers',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...data.signers.map((item) => _SignerCard(
                  signer: item,
                  working: _working,
                  onConfigure: () => _configureSigner(item),
                )),
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
            title: const Text('Contract checklist'),
          ),
          body: body,
        ),
      );
    }
    return Dialog(
      child: SizedBox(
        width: 760,
        height: 780,
        child: Column(
          children: [
            ListTile(
              title: const Text('Contract onboarding checklist'),
              subtitle: Text(widget.contract.contractNumber),
              trailing: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close)),
            ),
            const Divider(height: 1),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class _RequirementCard extends StatelessWidget {
  const _RequirementCard({
    required this.item,
    required this.working,
    required this.onUpload,
    required this.onOpen,
    required this.onApprove,
    required this.onReject,
    this.onRequiredChanged,
  });

  final ContractRequirement item;
  final bool working;
  final VoidCallback onUpload;
  final VoidCallback onOpen;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final ValueChanged<bool>? onRequiredChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: CarmelitaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                      child: Text(item.label,
                          style: const TextStyle(fontWeight: FontWeight.w700))),
                  StatusPill(_statusLabel(item.status)),
                ],
              ),
              if (onRequiredChanged != null)
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Require guardian ID before activation'),
                  value: item.isRequired,
                  onChanged: working ? null : onRequiredChanged,
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                      item.isRequired ? 'Required for activation' : 'Optional'),
                ),
              if (item.originalFilename != null)
                Text('File: ${item.originalFilename}'),
              if (item.type == 'signed_photocopies')
                Text(
                    'Physical copy: ${item.physicalCopyReceived ? "Received" : "Not received"} • Signatures: ${item.signatureCount}/3'),
              if (item.reviewNotes?.isNotEmpty == true)
                Text('Review: ${item.reviewNotes}'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: working ? null : onUpload,
                    icon: const Icon(Icons.upload_file_outlined),
                    label:
                        Text(item.storagePath == null ? 'Upload' : 'Replace'),
                  ),
                  if (item.storagePath != null)
                    OutlinedButton.icon(
                      onPressed: working ? null : onOpen,
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('Review file'),
                    ),
                  if (item.isPendingReview)
                    FilledButton.tonal(
                        onPressed: working ? null : onApprove,
                        child: const Text('Verify')),
                  if (item.isPendingReview)
                    TextButton(
                        onPressed: working ? null : onReject,
                        child: const Text('Reject')),
                ],
              ),
            ],
          ),
        ),
      );

  String _statusLabel(String status) => switch (status) {
        'pending_review' => 'Pending review',
        'verified' => 'Verified',
        'rejected' => 'Rejected',
        'waived' => 'Optional',
        _ => 'Missing',
      };
}

class _SignerCard extends StatelessWidget {
  const _SignerCard(
      {required this.signer, required this.working, required this.onConfigure});
  final ContractSigner signer;
  final bool working;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: CarmelitaCard(
          child: Row(
            children: [
              Icon(
                  signer.isVerified ? Icons.draw_rounded : Icons.edit_document),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(signer.label,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                        '${signer.isRequired ? "Required" : "Optional"} • ${signer.status}'),
                    if (signer.signerName?.isNotEmpty == true)
                      Text(signer.signerName!),
                  ],
                ),
              ),
              TextButton(
                  onPressed: working ? null : onConfigure,
                  child: const Text('Update')),
            ],
          ),
        ),
      );
}

class _PhotocopyMetadataDialog extends StatefulWidget {
  const _PhotocopyMetadataDialog();
  @override
  State<_PhotocopyMetadataDialog> createState() =>
      _PhotocopyMetadataDialogState();
}

class _PhotocopyMetadataDialogState extends State<_PhotocopyMetadataDialog> {
  bool _received = false;
  int _count = 0;
  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Physical-copy verification'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Physical photocopies received'),
              value: _received,
              onChanged: (value) => setState(() => _received = value ?? false),
            ),
            DropdownButtonFormField<int>(
              initialValue: _count,
              decoration:
                  const InputDecoration(labelText: 'Signatures present'),
              items: List.generate(
                  4, (i) => DropdownMenuItem(value: i, child: Text('$i of 3'))),
              onChanged: (value) => setState(() => _count = value ?? 0),
            ),
            const SizedBox(height: 8),
            const Text(
                'The client must still confirm whose signatures and placement are required.'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(
                context,
                _PhotocopyMetadata(
                    physicalCopyReceived: _received, signatureCount: _count)),
            child: const Text('Continue'),
          ),
        ],
      );
}

class _SignerDialog extends StatefulWidget {
  const _SignerDialog({required this.signer});
  final ContractSigner signer;
  @override
  State<_SignerDialog> createState() => _SignerDialogState();
}

class _SignerDialogState extends State<_SignerDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.signer.signerName);
  late final TextEditingController _notes =
      TextEditingController(text: widget.signer.notes);
  late bool _required = widget.signer.isRequired;
  late String _status = widget.signer.status;

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.signer.label),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.signer.isConfigurable)
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Required for activation'),
                  value: _required,
                  onChanged: (value) => setState(() {
                    _required = value;
                    if (!value && _status == 'pending') _status = 'waived';
                    if (value && _status == 'waived') _status = 'pending';
                  }),
                ),
              TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Signer name')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration:
                    const InputDecoration(labelText: 'Signature status'),
                items: [
                  const DropdownMenuItem(
                      value: 'pending', child: Text('Pending')),
                  const DropdownMenuItem(
                      value: 'signed',
                      child: Text('Signed — awaiting verification')),
                  const DropdownMenuItem(
                      value: 'verified', child: Text('Verified')),
                  const DropdownMenuItem(
                      value: 'rejected', child: Text('Rejected')),
                  if (!_required)
                    const DropdownMenuItem(
                        value: 'waived', child: Text('Not required / waived')),
                ],
                onChanged: (value) =>
                    setState(() => _status = value ?? _status),
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: _notes,
                  minLines: 2,
                  maxLines: 4,
                  decoration:
                      const InputDecoration(labelText: 'Verification notes')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              _SignerUpdate(
                  status: _status,
                  name: _name.text.trim(),
                  notes: _notes.text.trim(),
                  required: _required),
            ),
            child: const Text('Save'),
          ),
        ],
      );
}

class _ChecklistData {
  const _ChecklistData({required this.requirements, required this.signers});
  final List<ContractRequirement> requirements;
  final List<ContractSigner> signers;
}

class _RequirementViewer extends StatelessWidget {
  const _RequirementViewer({
    required this.title,
    required this.mimeType,
    required this.bytes,
  });

  final String title;
  final String mimeType;
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
            title: Text(title),
          ),
          body: mimeType == 'application/pdf'
              ? PdfPreview(
                  build: (_) async => bytes,
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                )
              : InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5,
                  child: Center(child: Image.memory(bytes)),
                ),
        ),
      );
}

class _PhotocopyMetadata {
  const _PhotocopyMetadata(
      {required this.physicalCopyReceived, required this.signatureCount});
  final bool physicalCopyReceived;
  final int signatureCount;
}

class _SignerUpdate {
  const _SignerUpdate(
      {required this.status,
      required this.name,
      required this.notes,
      required this.required});
  final String status;
  final String name;
  final String notes;
  final bool required;
}
