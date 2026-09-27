import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../controllers/guardian_controller.dart';
import '../../core/widgets/common_widgets.dart';
import '../../models/models.dart';
import '../../services/contract_document_service.dart';
import '../../services/contract_onboarding_service.dart';

class GuardianDocumentsPage extends StatefulWidget {
  const GuardianDocumentsPage({super.key});

  @override
  State<GuardianDocumentsPage> createState() => _GuardianDocumentsPageState();
}

class _GuardianDocumentsPageState extends State<GuardianDocumentsPage> {
  final _onboarding = const ContractOnboardingService();
  final _documents = const ContractDocumentService();
  Future<_GuardianDocumentData>? _future;
  String? _tenantId;
  bool _opening = false;

  Future<_GuardianDocumentData> _load(String tenantId) async {
    final contract = await _onboarding.getContractForTenant(tenantId);
    if (contract == null) return const _GuardianDocumentData();
    final results = await Future.wait<dynamic>([
      _onboarding.listRequirements(contract.id),
      _documents.listDocuments(contract.id),
    ]);
    return _GuardianDocumentData(
      contract: contract,
      requirements: results[0] as List<ContractRequirement>,
      documents: results[1] as List<ContractDocument>,
    );
  }

  void _syncTenant() {
    final id = GuardianController.instance.selectedTenant?.tenantId;
    if (id == null || id == _tenantId) return;
    _tenantId = id;
    _future = _load(id);
  }

  Future<void> _open(String path) async {
    setState(() => _opening = true);
    try {
      final bytes = await _documents.downloadDocument(path);
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: GuardianController.instance,
      builder: (context, _) {
        _syncTenant();
        final tenant = GuardianController.instance.selectedTenant;
        if (tenant == null || _future == null) {
          return const PageFrame(
            title: 'Documents',
            subtitle: 'Linked resident records',
            child: EmptyState(
              icon: Icons.folder_off_outlined,
              title: 'No linked resident',
              message: 'Link a resident before viewing documents.',
            ),
          );
        }
        return PageFrame(
          title: 'Documents',
          subtitle: '${tenant.name} · view-only records',
          onRefresh: () async {
            setState(() => _future = _load(tenant.tenantId));
            await _future;
          },
          child: FutureBuilder<_GuardianDocumentData>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return EmptyState(
                  icon: Icons.error_outline,
                  title: 'Documents unavailable',
                  message: snapshot.error.toString(),
                );
              }
              final data = snapshot.data ?? const _GuardianDocumentData();
              if (data.contract == null) {
                return const EmptyState(
                  icon: Icons.description_outlined,
                  title: 'No contract available',
                  message:
                      'The linked resident does not have a current contract.',
                );
              }
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CarmelitaCard(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.assignment_outlined),
                        title: Text(data.contract!.contractNumber),
                        subtitle: Text('Status: ${data.contract!.status}'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const SectionTitle('Contract files'),
                    const SizedBox(height: 8),
                    if (data.documents.isEmpty)
                      const Text('No generated contract files yet.')
                    else
                      ...data.documents.map((item) => CarmelitaCard(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading:
                                  const Icon(Icons.picture_as_pdf_outlined),
                              title: Text(item.isSigned
                                  ? 'Executed digital contract'
                                  : 'Official contract PDF'),
                              subtitle: Text(item.originalFilename),
                              trailing: const Icon(Icons.visibility_outlined),
                              onTap: _opening
                                  ? null
                                  : () => _open(item.storagePath),
                            ),
                          )),
                    const SizedBox(height: 16),
                    const SectionTitle('Submitted requirements'),
                    const SizedBox(height: 8),
                    ...data.requirements
                        .where((item) =>
                            item.storagePath != null &&
                            item.type != 'signed_photocopies')
                        .map((item) => CarmelitaCard(
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.badge_outlined),
                                title: Text(item.label),
                                subtitle: Text(item.status),
                                trailing: const Icon(Icons.visibility_outlined),
                                onTap: _opening
                                    ? null
                                    : () => _open(item.storagePath!),
                              ),
                            )),
                  ]);
            },
          ),
        );
      },
    );
  }
}

class _GuardianDocumentData {
  const _GuardianDocumentData({
    this.contract,
    this.requirements = const [],
    this.documents = const [],
  });
  final TenantContract? contract;
  final List<ContractRequirement> requirements;
  final List<ContractDocument> documents;
}
