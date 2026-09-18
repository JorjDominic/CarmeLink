import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';

/// Routes sensitive application images through server-authorized Cloudinary
/// Edge Functions. Cloudinary credentials never enter the mobile application.
class SecureMediaService {
  const SecureMediaService();

  static const String cloudinaryReferencePrefix = 'cloudinary://';

  SupabaseClient get _client => SupabaseConfig.client;

  static bool isCloudinaryReference(String? value) =>
      value?.startsWith(cloudinaryReferencePrefix) ?? false;

  Future<String> uploadImage({
    required String kind,
    required String recordId,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final response = await _client.functions.invoke(
      'cloudinary-media-upload',
      body: {
        'kind': kind,
        'record_id': recordId,
        'mime_type': mimeType,
        'file_base64': base64Encode(bytes),
      },
    );

    final data = _responseMap(response.data);
    final reference = data['reference'] as String?;
    if (response.status < 200 || response.status >= 300 || reference == null) {
      throw Exception(data['error'] ?? 'Unable to securely upload image.');
    }
    return reference;
  }

  /// Returns a short-lived URL only after the Edge Function confirms that the
  /// signed-in account can read the database record containing this asset.
  Future<String?> createAuthorizedUrl(String reference) async {
    final response = await _client.functions.invoke(
      'cloudinary-media-url',
      body: {'reference': reference},
    );
    final data = _responseMap(response.data);
    final url = data['url'] as String?;
    if (response.status < 200 || response.status >= 300 || url == null) {
      return null;
    }
    return url;
  }

  Future<void> deleteImage(String reference) async {
    if (!isCloudinaryReference(reference)) return;
    final response = await _client.functions.invoke(
      'cloudinary-media-delete',
      body: {'reference': reference},
    );
    if (response.status < 200 || response.status >= 300) {
      final data = _responseMap(response.data);
      throw Exception(data['error'] ?? 'Unable to delete image.');
    }
  }

  Map<String, dynamic> _responseMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }
}
