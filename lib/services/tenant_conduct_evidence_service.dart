import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import '../core/config/supabase_config.dart';
import 'issued_receipt_service.dart';

class TenantEvidenceDraft {
  TenantEvidenceDraft(
      {required this.name, required this.bytes, required this.mime});
  final String name, mime;
  final Uint8List bytes;
  final String fileId = IssuedReceiptService.requestId();
  String caption = '';
  String? uploadedPath;
}

class TenantConductEvidenceService {
  const TenantConductEvidenceService();
  static const bucket = 'tenant-conduct-evidence';
  static String requestId() => IssuedReceiptService.requestId();
  SupabaseClient get client => SupabaseConfig.client;

  Future<TenantEvidenceDraft?> pickPhoto() async {
    final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp']);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
      throw ArgumentError('Choose a photo up to 5 MB.');
    }
    return TenantEvidenceDraft(
        name: file.name.length > 200 ? file.name.substring(0, 200) : file.name,
        bytes: bytes,
        mime: imageMime(bytes));
  }

  static String imageMime(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 137 &&
        bytes[1] == 80 &&
        bytes[2] == 78 &&
        bytes[3] == 71 &&
        bytes[4] == 13 &&
        bytes[5] == 10 &&
        bytes[6] == 26 &&
        bytes[7] == 10) return 'image/png';
    if (bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255) return 'image/jpeg';
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP')
      return 'image/webp';
    throw ArgumentError('Choose a JPG, PNG or WebP photo.');
  }

  Future<String> upload(
      String caseId, String request, TenantEvidenceDraft photo) async {
    if (photo.uploadedPath != null) return photo.uploadedPath!;
    final user = client.auth.currentUser;
    if (user == null) throw StateError('Sign in before attaching evidence.');
    final extension = photo.mime == 'image/png'
        ? 'png'
        : photo.mime == 'image/webp'
            ? 'webp'
            : 'jpg';
    final path = '${user.id}/$caseId/$request/${photo.fileId}.$extension';
    try {
      await client.storage.from(bucket).uploadBinary(path, photo.bytes,
          fileOptions: FileOptions(contentType: photo.mime, upsert: false));
    } on StorageException catch (error) {
      // Same request and immutable bytes reuse the original object after a lost reply.
      if (error.statusCode != '409' && error.error != 'Duplicate') rethrow;
    }
    photo.uploadedPath = path;
    return path;
  }

  Future<void> submit(
      {required String id,
      required String caseId,
      required String kind,
      required String statement,
      required String support,
      required List<Map<String, dynamic>> photos}) async {
    await client.rpc('submit_tenant_conduct_material', params: {
      'p_id': id,
      'p_case_id': caseId,
      'p_kind': kind,
      'p_statement': statement.trim(),
      'p_support': support.trim(),
      'p_attachments': photos
    });
  }

  Future<List<Map<String, dynamic>>> list(
      {required String caseId, String? responseId, String? appealId}) async {
    var query = client
        .from('tenant_conduct_submissions')
        .select('id')
        .eq('case_id', caseId);
    if (responseId != null) query = query.eq('response_id', responseId);
    if (appealId != null) query = query.eq('appeal_id', appealId);
    final submissions = await query;
    if (submissions.isEmpty) return [];
    return List<Map<String, dynamic>>.from(await client
        .from('tenant_conduct_evidence')
        .select()
        .inFilter('submission_id', submissions.map((r) => r['id']).toList())
        .order('created_at'));
  }

  Future<String> preview(String path) =>
      client.storage.from(bucket).createSignedUrl(path, 120);
  Future<void> cleanup(String path) async {
    await client.storage.from(bucket).remove([path]);
  }
}
