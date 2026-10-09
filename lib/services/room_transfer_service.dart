import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import 'room_service.dart';
import 'tenant_service.dart';

class RoomTransfer {
  RoomTransfer(this.row);
  final Map<String, dynamic> row;
  String get id => row['id'] as String;
  String get tenantId => row['tenant_id'] as String;
  String get tenantName => row['tenant_name'] as String;
  String get contractNumber => row['contract_number'] as String;
  String get status => row['status'] as String;
  String get source => '${row['source_room']} / ${row['source_bed']}';
  String get destination =>
      '${row['destination_room']} / ${row['destination_bed']}';
  String get reason => row['reason'] as String;
  DateTime get effectiveOn => DateTime.parse(row['effective_on'] as String);
  double get monthlyRent => (row['monthly_rent'] as num).toDouble();
  double get securityDeposit => (row['security_deposit'] as num).toDouble();
  String? get documentPath => row['document_path'] as String?;
  String? get documentHash => row['document_sha256'] as String?;
  bool get pending => status == 'draft' || status == 'awaiting_signatures';
  List<RoomTransferSigner> get signers => (row['room_transfer_signers']
              as List? ??
          [])
      .map((item) => RoomTransferSigner(Map<String, dynamic>.from(item as Map)))
      .toList();
  bool get allVerified =>
      signers.length >= 2 && signers.every((s) => s.status == 'verified');
}

class RoomTransferSigner {
  RoomTransferSigner(this.row);
  final Map<String, dynamic> row;
  String get id => row['id'] as String;
  String get role => row['signer_role'] as String;
  String get status => row['status'] as String;
  String? get userId => row['signer_user_id'] as String?;
  String? get name => row['signer_name'] as String?;
  String? get path => row['signature_path'] as String?;
  String? get reviewNote => row['review_note'] as String?;
  bool get canSign => status == 'pending' || status == 'rejected';
}

class RoomTransferService {
  const RoomTransferService();
  static const bucket = 'room-amendments';
  SupabaseClient get _client => SupabaseConfig.client;
  static const _selection = '*,room_transfer_signers(*)';

  Future<List<RoomTransfer>> list({String? tenantId}) async {
    var query = _client.from('room_transfers').select(_selection);
    if (tenantId != null) query = query.eq('tenant_id', tenantId);
    final rows = await query.order('created_at', ascending: false);
    return rows.map(RoomTransfer.new).toList();
  }

  Future<RoomTransfer> get(String id) async => RoomTransfer(await _client
      .from('room_transfers')
      .select(_selection)
      .eq('id', id)
      .single());

  Future<RoomTransfer> propose(
      {required String tenantId,
      required String bedId,
      required DateTime effectiveOn,
      required String reason}) async {
    final id = await _client.rpc('propose_room_transfer', params: {
      'p_tenant_id': tenantId,
      'p_bed_id': bedId,
      'p_effective_on': effectiveOn.toIso8601String().split('T').first,
      'p_reason': reason.trim(),
    });
    RoomService.invalidateCache();
    return get(id as String);
  }

  Future<void> publish(RoomTransfer transfer) async {
    final bytes = await buildAmendmentPdf(transfer);
    final path =
        '${transfer.id}/documents/amendment-${DateTime.now().microsecondsSinceEpoch}.pdf';
    await _client.storage.from(bucket).uploadBinary(path, bytes,
        fileOptions:
            const FileOptions(contentType: 'application/pdf', upsert: false));
    try {
      await _client.rpc('publish_room_transfer', params: {
        'p_id': transfer.id,
        'p_path': path,
        'p_sha256': sha256.convert(bytes).toString(),
      });
    } catch (_) {
      // Do not remove a registered document after an ambiguous network failure.
      try {
        if ((await get(transfer.id)).documentPath != path) {
          await _client.storage.from(bucket).remove([path]);
        }
      } catch (_) {/* A later refresh can recover the published document. */}
      rethrow;
    }
  }

  Future<Uint8List> download(String path) =>
      _client.storage.from(bucket).download(path);
  Future<Uint8List> downloadAmendment(RoomTransfer transfer) async {
    final bytes = await download(transfer.documentPath!);
    if (sha256.convert(bytes).toString() != transfer.documentHash) {
      throw StateError(
          'The amendment file does not match its registered version. Contact the owner.');
    }
    return bytes;
  }

  Future<String> signedUrl(String path) =>
      _client.storage.from(bucket).createSignedUrl(path, 300);

  Future<void> sign(RoomTransfer transfer, String role, Uint8List bytes,
      {String? signerName, String mimeType = 'image/png'}) async {
    if (bytes.isEmpty || bytes.length > 2 * 1024 * 1024) {
      throw ArgumentError('Use a signature image of at most 2 MB.');
    }
    if (mimeType != 'image/png' && mimeType != 'image/jpeg') {
      throw ArgumentError('Use a PNG or JPEG signature image.');
    }
    final extension = mimeType == 'image/png' ? 'png' : 'jpg';
    final path =
        '${transfer.id}/signatures/$role-${DateTime.now().microsecondsSinceEpoch}.$extension';
    await _client.storage.from(bucket).uploadBinary(path, bytes,
        fileOptions: FileOptions(contentType: mimeType, upsert: false));
    try {
      await _client.rpc('sign_room_transfer', params: {
        'p_id': transfer.id,
        'p_role': role,
        'p_path': path,
        'p_sha256': sha256.convert(bytes).toString(),
        'p_document_sha256': transfer.documentHash,
        'p_signer_name': signerName,
      });
    } catch (_) {
      try {
        if (!(await get(transfer.id)).signers.any((s) => s.path == path)) {
          await _client.storage.from(bucket).remove([path]);
        }
      } catch (_) {/* Keep possible registered evidence until refreshed. */}
      rethrow;
    }
  }

  Future<void> review(String signerId, bool approve, String note) async {
    await _client.rpc('review_room_transfer_signature', params: {
      'p_signer_id': signerId,
      'p_approve': approve,
      'p_note': note.trim(),
    });
  }

  Future<void> cancel(String id, String reason) async {
    await _client.rpc('cancel_room_transfer',
        params: {'p_id': id, 'p_reason': reason.trim()});
    RoomService.invalidateCache();
  }

  Future<void> complete(String id) async {
    await _client.rpc('complete_room_transfer', params: {'p_id': id});
    RoomService.invalidateCache();
    TenantService.invalidateCache();
  }

  /// This PDF is a separate amendment; the original signed lease is preserved.
  static Future<Uint8List> buildAmendmentPdf(RoomTransfer transfer) async {
    final pdf = pw.Document();
    final t = transfer.row;
    final lines = <String>[
      'Amendment ID: ${transfer.id}',
      'Original contract: ${transfer.contractNumber}',
      'Tenant: ${transfer.tenantName}',
      'Current room and bed: ${transfer.source}',
      'Proposed room and bed: ${transfer.destination}',
      'Agreed effective date: ${t['effective_on']}',
      'Reason: ${transfer.reason}',
      'Original term: ${t['starts_on']} to ${t['ends_on']}',
      'Monthly rent remains PHP ${transfer.monthlyRent.toStringAsFixed(2)}.',
      'Security deposit remains PHP ${transfer.securityDeposit.toStringAsFixed(2)}; no new deposit is collected.',
      'All other terms of the original signed lease remain in effect. This amendment does not renew or restart the lease.',
      'The destination bed is reserved. The current assignment stays active until required signatures are verified and the owner confirms the move on or after the agreed date.',
      'By signing, each required signer agrees to this room and bed change and the unchanged financial terms above.',
      'Signatures are recorded separately against the SHA-256 hash of this exact PDF and remain available with this amendment.',
      'Required signers: ${transfer.signers.map((s) => s.role).join(', ')}.',
    ];
    pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
              pw.Text('ROOM TRANSFER AMENDMENT',
                  style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 18),
              ...lines.map((line) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 12),
                  child: pw.Text(line)))
            ]));
    return pdf.save();
  }
}
