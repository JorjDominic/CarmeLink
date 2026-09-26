import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../core/widgets/common_widgets.dart';
import '../../models/models.dart';
import '../../services/contract_onboarding_service.dart';
import '../shared/signature_pad_dialog.dart';

/// Tenant-facing page for viewing and submitting required onboarding documents
/// and in-app electronic signatures.
class TenantRequirementsPage extends StatefulWidget {
  const TenantRequirementsPage({super.key});

  @override
  State<TenantRequirementsPage> createState() => _TenantRequirementsPageState();
}

class _TenantRequirementsPageState extends State<TenantRequirementsPage> {
  final _service = const ContractOnboardingService();
  late Future<
      ({
        TenantContract? contract,
        List<ContractRequirement> requirements,
        List<ContractSigner> signers,
      })> _future = _load();
  bool _working = false;

  Future<
      ({
        TenantContract? contract,
        List<ContractRequirement> requirements,
        List<ContractSigner> signers,
      })> _load() async {
    final contract = await _service.getMyContract();
    if (contract == null) {
      return (
        contract: null,
        requirements: <ContractRequirement>[],
        signers: <ContractSigner>[],
      );
    }
    final reqs = await _service.listRequirements(contract.id);
    final signers = await _service.listSigners(contract.id);
    return (contract: contract, requirements: reqs, signers: signers);
  }

  void _reload() {
    if (mounted) {
      setState(() {
        _future = _load();
      });
    }
  }

  String _mimeType(String? extension) => switch (extension?.toLowerCase()) {
        'pdf' => 'application/pdf',
        'png' => 'image/png',
        _ => 'image/jpeg',
      };

  Future<void> _upload(ContractRequirement item) async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (file == null || !mounted) return;

    final bytes = await file.readAsBytes();
    setState(() => _working = true);
    try {
      await _service.submitRequirement(
        requirement: item,
        filename: file.name,
        mimeType: _mimeType(file.extension),
        bytes: bytes,
      );
      if (mounted) {
        showAppSnackBar(
          context,
          '${item.label} submitted for dormitory manager review.',
        );
        _reload();
      }
    } catch (error) {
      if (mounted) {
        showAppSnackBar(context, 'Upload failed: $error');
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _viewDocument(ContractRequirement item) async {
    final path = item.storagePath;
    if (path == null) return;
    setState(() => _working = true);
    try {
      final bytes = await _service.downloadRequirement(path);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => _DocumentPreviewDialog(
          title: item.label,
          mimeType: _mimeType(item.originalFilename?.split('.').last),
          bytes: bytes,
        ),
      );
    } catch (error) {
      if (mounted) {
        showAppSnackBar(context, 'Could not open document: $error');
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _signOnPhone(TenantContract contract) async {
    final bytes = await showSignaturePadDialog(
      context,
      signerName: contract.tenantName,
      contractNumber: contract.contractNumber,
    );
    if (bytes == null || !mounted) return;

    setState(() => _working = true);
    try {
      await _service.submitElectronicSignature(
        contractId: contract.id,
        signatureBytes: bytes,
      );
      if (mounted) {
        showAppSnackBar(
          context,
          'Electronic signature submitted! Dormitory management will review and verify it.',
        );
        _reload();
      }
    } catch (error) {
      if (mounted) {
        showAppSnackBar(context, 'Failed to submit signature: $error');
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Required Documents'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _working ? null : _reload,
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<
            ({
              TenantContract? contract,
              List<ContractRequirement> requirements,
              List<ContractSigner> signers,
            })>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: scheme.error),
                      const SizedBox(height: 12),
                      Text(
                        'Failed to load requirements',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _reload,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final data = snapshot.data;
            final contract = data?.contract;
            final requirements = data?.requirements ?? const [];

            if (contract == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer.withAlpha(120),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.description_outlined,
                          size: 48,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'No Contract Drafted Yet',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Your dormitory manager will create your room contract soon. Once drafted, your document requirements checklist will appear here.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            final requiredList =
                requirements.where((r) => r.isRequired).toList();
            final verifiedCount =
                requiredList.where((r) => r.isVerified).length;
            final totalRequired = requiredList.length;

            return Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    // Contract summary header
                    CarmelitaCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: scheme.primary.withAlpha(25),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.assignment_outlined,
                                  color: scheme.primary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Contract #${contract.contractNumber}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Term: ${shortDate(contract.startsOn)} - ${shortDate(contract.endsOn)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              StatusPill(
                                contract.status.toUpperCase(),
                                icon: contract.isActive
                                    ? Icons.check_circle_outline
                                    : Icons.edit_note_outlined,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Verification progress
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Onboarding Document Progress',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '$verifiedCount of $totalRequired verified',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: verifiedCount == totalRequired
                                          ? const Color(0xFF2E7D32)
                                          : scheme.primary,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: totalRequired == 0
                                  ? 1.0
                                  : (verifiedCount / totalRequired),
                              minHeight: 8,
                              backgroundColor: scheme.surfaceContainerHighest,
                              color: verifiedCount == totalRequired
                                  ? const Color(0xFF2E7D32)
                                  : scheme.primary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Please upload clear photos or PDF copies of each document. The manager will review them before activating your contract.',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const SectionTitle('Document Checklist'),
                    const SizedBox(height: 10),

                    if (requirements.isEmpty)
                      const CarmelitaCard(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'No specific document requirements attached to this contract.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ...requirements.map((item) => _RequirementCard(
                            item: item,
                            working: _working,
                            onUpload: () => _upload(item),
                            onView: () => _viewDocument(item),
                            onSignOnPhone: item.type == 'signed_photocopies'
                                ? () => _signOnPhone(contract)
                                : null,
                          )),
                  ],
                ),
                if (_working)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black26,
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ),
              ],
            );
          },
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
    required this.onView,
    this.onSignOnPhone,
  });

  final ContractRequirement item;
  final bool working;
  final VoidCallback onUpload;
  final VoidCallback onView;
  final VoidCallback? onSignOnPhone;

  String _description(String type) => switch (type) {
        'tenant_identity' =>
          'Upload a photo or PDF of your valid school ID, employee ID, or government-issued ID.',
        'guardian_identity' =>
          'Upload a copy of parent or legal guardian\'s government-issued ID (recommended for minor residents).',
        'signed_photocopies' =>
          'Sign lease directly on your phone with your finger (recommended), or upload a photo of your printed signed lease.',
        _ => 'Upload the requested verification document.',
      };

  ({String text, Color bg, Color fg, IconData icon}) _statusStyle(
      BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (item.isVerified) {
      return (
        text: 'Verified & Approved',
        bg: const Color(0xFFE8F5E9),
        fg: const Color(0xFF2E7D32),
        icon: Icons.check_circle_rounded,
      );
    }
    if (item.isPendingReview) {
      return (
        text: 'Pending Manager Review',
        bg: const Color(0xFFE3F2FD),
        fg: const Color(0xFF1565C0),
        icon: Icons.schedule_rounded,
      );
    }
    if (item.status == 'rejected') {
      return (
        text: 'Rejected — Action Needed',
        bg: const Color(0xFFFFEBEE),
        fg: scheme.error,
        icon: Icons.cancel_rounded,
      );
    }
    if (item.status == 'waived') {
      return (
        text: 'Waived',
        bg: const Color(0xFFF5F5F5),
        fg: Colors.black54,
        icon: Icons.do_not_disturb_on_outlined,
      );
    }
    return (
      text: 'Missing Document',
      bg: const Color(0xFFFFF3E0),
      fg: const Color(0xFFE65100),
      icon: Icons.pending_actions_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = _statusStyle(context);
    final hasFile = item.storagePath != null && item.storagePath!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CarmelitaCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.label,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: item.isRequired
                                  ? scheme.primary.withAlpha(20)
                                  : scheme.outlineVariant.withAlpha(60),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.isRequired ? 'REQUIRED' : 'OPTIONAL',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: item.isRequired
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _description(item.type),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Status chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: style.bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: style.fg.withAlpha(40)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(style.icon, size: 16, color: style.fg),
                  const SizedBox(width: 8),
                  Text(
                    style.text,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: style.fg,
                    ),
                  ),
                ],
              ),
            ),

            if (item.status == 'rejected' &&
                item.reviewNotes != null &&
                item.reviewNotes!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.errorContainer.withAlpha(120),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: scheme.error.withAlpha(80)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Manager review feedback:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: scheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.reviewNotes!,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (hasFile) ...[
              const SizedBox(height: 8),
              Text(
                'File: ${item.originalFilename ?? "Uploaded document"}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ],

            if (item.physicalCopyReceived) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.inventory_2_outlined,
                      size: 14, color: Color(0xFF2E7D32)),
                  const SizedBox(width: 6),
                  Text(
                    'Physical hard copy received at dorm desk',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF2E7D32),
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 14),
            // Actions
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!item.isVerified && onSignOnPhone != null)
                  FilledButton.icon(
                    onPressed: working ? null : onSignOnPhone,
                    icon: const Icon(Icons.draw_rounded, size: 16),
                    label: Text(
                      hasFile
                          ? 'Redraw Signature on Phone'
                          : '✍️ Sign on Phone (E-Sign)',
                    ),
                  ),
                if (!item.isVerified)
                  (onSignOnPhone != null
                      ? OutlinedButton.icon(
                          onPressed: working ? null : onUpload,
                          icon: Icon(
                            hasFile
                                ? Icons.file_upload_outlined
                                : Icons.upload_file_outlined,
                            size: 16,
                          ),
                          label: Text(
                            hasFile
                                ? 'Replace Paper Copy'
                                : 'Upload Paper Copy',
                          ),
                        )
                      : FilledButton.icon(
                          onPressed: working ? null : onUpload,
                          icon: Icon(
                            hasFile
                                ? Icons.file_upload_outlined
                                : Icons.add_photo_alternate_outlined,
                            size: 16,
                          ),
                          label: Text(
                            hasFile ? 'Replace File' : 'Upload Document',
                          ),
                        )),
                if (hasFile)
                  OutlinedButton.icon(
                    onPressed: working ? null : onView,
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: Text(
                      item.type == 'signed_photocopies'
                          ? 'View Signature / Copy'
                          : 'View Document',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentPreviewDialog extends StatelessWidget {
  const _DocumentPreviewDialog({
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
                  child: Center(
                    child: Image.memory(
                      bytes,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Text('Unable to preview this image'),
                      ),
                    ),
                  ),
                ),
        ),
      );
}
