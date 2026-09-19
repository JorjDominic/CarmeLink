import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../models/models.dart';

class GeneratedContractFile {
  const GeneratedContractFile({required this.document, required this.bytes});
  final ContractDocument document;
  final Uint8List bytes;
}

class ContractDocumentService {
  const ContractDocumentService();

  static const _bucket = 'contract-documents';
  static const _selection =
      'id, contract_id, version, document_type, storage_path, '
      'original_filename, mime_type, size_bytes, sha256, review_status, '
      'uploaded_at, reviewed_at, review_notes';

  SupabaseClient get _client => SupabaseConfig.client;

  Future<List<ContractDocument>> listDocuments(String contractId) async {
    final rows = await _client
        .from('contract_documents')
        .select(_selection)
        .eq('contract_id', contractId)
        .order('version', ascending: false)
        .order('document_type');
    return rows.map(ContractDocument.fromRow).toList();
  }

  Future<GeneratedContractFile> generateContract(
      TenantContract contract) async {
    final version = await _nextVersion(contract.id);
    final bytes = await _buildPdf(contract, version);
    final filename = '${contract.contractNumber}-v$version.pdf';
    final path = '${contract.id}/v$version/generated-'
        '${DateTime.now().toUtc().microsecondsSinceEpoch}.pdf';
    await _upload(path, bytes, 'application/pdf');
    final document = await _register(
      contractId: contract.id,
      version: version,
      documentType: 'generated',
      path: path,
      filename: filename,
      mimeType: 'application/pdf',
      bytes: bytes,
    );
    return GeneratedContractFile(document: document, bytes: bytes);
  }

  Future<ContractDocument> uploadSigned({
    required TenantContract contract,
    required int version,
    required String filename,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
      throw Exception('Signed document must be 10 MB or smaller.');
    }
    const allowed = {'application/pdf', 'image/jpeg', 'image/png'};
    if (!allowed.contains(mimeType)) {
      throw Exception('Upload a PDF, JPG, or PNG document.');
    }
    final extension = switch (mimeType) {
      'application/pdf' => 'pdf',
      'image/png' => 'png',
      _ => 'jpg',
    };
    final path = '${contract.id}/v$version/signed-'
        '${DateTime.now().toUtc().microsecondsSinceEpoch}.$extension';
    await _upload(path, bytes, mimeType);
    return _register(
      contractId: contract.id,
      version: version,
      documentType: 'signed',
      path: path,
      filename: filename,
      mimeType: mimeType,
      bytes: bytes,
    );
  }

  Future<ContractDocument> reviewSignedDocument({
    required String documentId,
    required bool approve,
    required String notes,
  }) async {
    final row = await _client.rpc('review_signed_contract_document', params: {
      'p_document_id': documentId,
      'p_approve': approve,
      'p_notes': notes.trim(),
    });
    return ContractDocument.fromRow(Map<String, dynamic>.from(row as Map));
  }

  Future<Uint8List> downloadDocument(String storagePath) async =>
      _client.storage.from(_bucket).download(storagePath);

  Future<int> _nextVersion(String contractId) async {
    final rows = await _client
        .from('contract_documents')
        .select('version')
        .eq('contract_id', contractId)
        .eq('document_type', 'generated')
        .order('version', ascending: false)
        .limit(1);
    return rows.isEmpty ? 1 : (rows.first['version'] as int) + 1;
  }

  Future<void> _upload(String path, Uint8List bytes, String mimeType) async {
    await _client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: false),
        );
  }

  Future<ContractDocument> _register({
    required String contractId,
    required int version,
    required String documentType,
    required String path,
    required String filename,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    final row = await _client
        .from('contract_documents')
        .insert({
          'contract_id': contractId,
          'version': version,
          'document_type': documentType,
          'storage_path': path,
          'original_filename': filename,
          'mime_type': mimeType,
          'size_bytes': bytes.length,
          'sha256': sha256.convert(bytes).toString(),
          'review_status':
              documentType == 'generated' ? 'not_required' : 'pending',
        })
        .select(_selection)
        .single();
    return ContractDocument.fromRow(row);
  }

  Future<Uint8List> _buildPdf(TenantContract contract, int version) async {
    final document = pw.Document(
      version: PdfVersion.pdf_1_5,
      title: '${contract.contractNumber} version $version',
      author: 'CarmeLink',
      creator: 'CarmeLink Contract Register',
    );
    final generatedAt = DateTime.now().toUtc();
    String date(DateTime value) =>
        '${value.year}-${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
    String amount(double value) => 'PHP ${value.toStringAsFixed(2)}';

    document.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(48),
      header: (_) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 12),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('CARMELITA\'S DORMITORY',
                style:
                    pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Text('Contract v$version',
                style: const pw.TextStyle(color: PdfColors.grey700)),
          ],
        ),
      ),
      footer: (context) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Generated by CarmeLink • ${generatedAt.toIso8601String()}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ],
      ),
      build: (_) => [
        pw.SizedBox(height: 24),
        pw.Text('DORMITORY RENTAL AGREEMENT',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Text('Contract No. ${contract.contractNumber}',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(color: PdfColors.grey700)),
        pw.SizedBox(height: 30),
        _pdfSection('Resident', [
          _pdfRow('Tenant name', contract.tenantName),
          _pdfRow('Tenant profile ID', contract.tenantId),
        ]),
        _pdfSection('Agreement term', [
          _pdfRow('Start date', date(contract.startsOn)),
          _pdfRow('End date', date(contract.endsOn)),
        ]),
        _pdfSection('Financial terms', [
          _pdfRow('Monthly rent', amount(contract.monthlyRent)),
          _pdfRow('Security deposit', amount(contract.securityDeposit)),
        ]),
        if (contract.notes?.trim().isNotEmpty == true)
          _pdfSection('Additional notes', [pw.Text(contract.notes!.trim())]),
        pw.SizedBox(height: 22),
        pw.Text(
          'By signing below, the parties acknowledge that they have reviewed '
          'and accepted the agreement details recorded above.',
          style: const pw.TextStyle(height: 1.5),
        ),
        pw.SizedBox(height: 56),
        pw.Row(children: [
          pw.Expanded(child: _signatureLine('Tenant signature and date')),
          pw.SizedBox(width: 36),
          pw.Expanded(child: _signatureLine('Owner signature and date')),
        ]),
        pw.SizedBox(height: 44),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(12),
          color: PdfColors.grey200,
          child: pw.Text(
            'Document version $version is immutable in CarmeLink. Signed scans '
            'must be uploaded against this exact version and verified by the owner.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ),
      ],
    ));
    return document.save();
  }

  pw.Widget _pdfSection(String title, List<pw.Widget> children) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 18),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title,
                style:
                    pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(children: children),
            ),
          ],
        ),
      );

  pw.Widget _pdfRow(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(children: [
          pw.SizedBox(
              width: 130,
              child: pw.Text(label,
                  style: const pw.TextStyle(color: PdfColors.grey700))),
          pw.Expanded(child: pw.Text(value)),
        ]),
      );

  pw.Widget _signatureLine(String label) => pw.Column(children: [
        pw.Container(
          height: 1,
          margin: const pw.EdgeInsets.only(bottom: 8),
          color: PdfColors.black,
        ),
        pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
      ]);
}
