import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../models/models.dart';

class MaintenanceService {
  const MaintenanceService();

  static const String _photoBucket = 'maintenance-photos';
  static const int _maximumPhotoBytes = 5 * 1024 * 1024;

  SupabaseClient get _client => SupabaseConfig.client;

  static const String _reportColumns =
      'id, tenant_id, category, description, location, urgency, '
      'status, photo_path, created_at, updated_at';

  String _requireTenantId() {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw const AuthException(
        'Your session has expired. Please sign in again.',
      );
    }

    return user.id;
  }

  Future<List<MaintenanceReport>> listOwnReports() async {
    final tenantId = _requireTenantId();

    final rows = await _client
        .from('maintenance_reports')
        .select(_reportColumns)
        .eq('tenant_id', tenantId)
        .order('created_at', ascending: false);

    return rows
        .map<MaintenanceReport>((row) => _fromRow(row))
        .toList(growable: false);
  }

  Future<MaintenanceReport> createReport({
    required String category,
    required String description,
    required String location,
    required String urgency,
    Uint8List? photoBytes,
    String? photoFileName,
    String? photoMimeType,
  }) async {
    final tenantId = _requireTenantId();

    final row = await _client
        .from('maintenance_reports')
        .insert({
          'tenant_id': tenantId,
          'category': category.trim(),
          'description': description.trim(),
          'location': location.trim(),
          'urgency': urgency.trim().toLowerCase(),
          'status': 'pending',
        })
        .select(_reportColumns)
        .single();

    var report = _fromRow(row);

    if (photoBytes == null) {
      return report;
    }

    String? uploadedPath;

    try {
      uploadedPath = await _uploadPhoto(
        tenantId: tenantId,
        reportId: report.id,
        bytes: photoBytes,
        fileName: photoFileName,
        mimeType: photoMimeType,
      );

      final updatedRow = await _client
          .from('maintenance_reports')
          .update({
            'photo_path': uploadedPath,
          })
          .eq('id', report.id)
          .eq('tenant_id', tenantId)
          .select(_reportColumns)
          .single();

      report = _fromRow(updatedRow);

      return report;
    } catch (_) {
      if (uploadedPath != null) {
        await _safeRemovePhoto(uploadedPath);
      }

      try {
        await _client
            .from('maintenance_reports')
            .delete()
            .eq('id', report.id)
            .eq('tenant_id', tenantId);
      } catch (_) {
        // Preserve the original upload/update error.
      }

      rethrow;
    }
  }

  Future<MaintenanceReport> updateReport({
    required String id,
    required String category,
    required String description,
    required String location,
    required String urgency,
    Uint8List? photoBytes,
    String? photoFileName,
    String? photoMimeType,
    bool removePhoto = false,
  }) async {
    final tenantId = _requireTenantId();

    final currentRow = await _client
        .from('maintenance_reports')
        .select(_reportColumns)
        .eq('id', id)
        .eq('tenant_id', tenantId)
        .single();

    final current = _fromRow(currentRow);

    String? nextPhotoPath = current.photoPath;
    String? uploadedPath;

    if (photoBytes != null) {
      uploadedPath = await _uploadPhoto(
        tenantId: tenantId,
        reportId: id,
        bytes: photoBytes,
        fileName: photoFileName,
        mimeType: photoMimeType,
      );

      nextPhotoPath = uploadedPath;
    } else if (removePhoto) {
      nextPhotoPath = null;
    }

    try {
      final row = await _client
          .from('maintenance_reports')
          .update({
            'category': category.trim(),
            'description': description.trim(),
            'location': location.trim(),
            'urgency': urgency.trim().toLowerCase(),
            'photo_path': nextPhotoPath,
          })
          .eq('id', id)
          .eq('tenant_id', tenantId)
          .select(_reportColumns)
          .single();

      if (current.photoPath != null && current.photoPath != nextPhotoPath) {
        await _safeRemovePhoto(current.photoPath!);
      }

      return _fromRow(row);
    } catch (_) {
      if (uploadedPath != null) {
        await _safeRemovePhoto(uploadedPath);
      }

      rethrow;
    }
  }

  Future<void> deleteReport(String id) async {
    final tenantId = _requireTenantId();

    final row = await _client
        .from('maintenance_reports')
        .select('id, photo_path')
        .eq('id', id)
        .eq('tenant_id', tenantId)
        .maybeSingle();

    if (row == null) {
      throw Exception('Maintenance report not found.');
    }

    final photoPath = row['photo_path'] as String?;

    final deletedRows = await _client
        .from('maintenance_reports')
        .delete()
        .eq('id', id)
        .eq('tenant_id', tenantId)
        .select('id');

    if (deletedRows.isEmpty) {
      throw Exception(
        'This maintenance report could not be deleted. '
        'Only pending reports can be deleted.',
      );
    }

    if (photoPath != null && photoPath.isNotEmpty) {
      await _safeRemovePhoto(photoPath);
    }
  }

  Future<String?> createPhotoUrl(String? photoPath) async {
    if (photoPath == null || photoPath.isEmpty) {
      return null;
    }

    return _client.storage.from(_photoBucket).createSignedUrl(
          photoPath,
          3600,
        );
  }

  Future<String> _uploadPhoto({
    required String tenantId,
    required String reportId,
    required Uint8List bytes,
    String? fileName,
    String? mimeType,
  }) async {
    if (bytes.isEmpty) {
      throw Exception(
        'The selected photo is empty.',
      );
    }

    if (bytes.length > _maximumPhotoBytes) {
      throw Exception(
        'Photo must be 5 MB or smaller.',
      );
    }

    final normalizedMimeType = _normalizedMimeType(
      mimeType,
      fileName,
    );

    final extension = _extensionFor(normalizedMimeType);

    final path = '$tenantId/$reportId/'
        '${DateTime.now().microsecondsSinceEpoch}.$extension';

    await _client.storage.from(_photoBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: normalizedMimeType,
            upsert: false,
          ),
        );

    return path;
  }

  String _normalizedMimeType(
    String? mimeType,
    String? fileName,
  ) {
    final mime = mimeType?.toLowerCase().trim();

    if (mime == 'image/jpeg' || mime == 'image/png' || mime == 'image/webp') {
      return mime!;
    }

    final lowerName = fileName?.toLowerCase() ?? '';

    if (lowerName.endsWith('.png')) {
      return 'image/png';
    }

    if (lowerName.endsWith('.webp')) {
      return 'image/webp';
    }

    if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) {
      return 'image/jpeg';
    }

    throw Exception(
      'Use a JPG, PNG, or WEBP photo.',
    );
  }

  String _extensionFor(
    String mimeType,
  ) =>
      switch (mimeType) {
        'image/png' => 'png',
        'image/webp' => 'webp',
        _ => 'jpg',
      };

  Future<void> _safeRemovePhoto(
    String path,
  ) async {
    try {
      await _client.storage.from(_photoBucket).remove([path]);
    } catch (_) {
      // Missing cleanup objects must not break
      // the primary CRUD action.
    }
  }

  MaintenanceReport _fromRow(
    Map<String, dynamic> row,
  ) {
    return MaintenanceReport(
      id: row['id'] as String,
      category: row['category'] as String,
      description: row['description'] as String,
      location: row['location'] as String,
      urgency: _label(row['urgency'] as String),
      status: _statusLabel(
        row['status'] as String,
      ),
      createdAt: DateTime.parse(
        row['created_at'] as String,
      ).toLocal(),
      photoPath: row['photo_path'] as String?,
    );
  }

  String _label(String value) {
    if (value.isEmpty) {
      return value;
    }

    return '${value[0].toUpperCase()}'
        '${value.substring(1)}';
  }

  String _statusLabel(String value) => switch (value) {
        'in_progress' => 'In Progress',
        'pending' => 'Pending',
        'assigned' => 'Assigned',
        'resolved' => 'Resolved',
        'cancelled' => 'Cancelled',
        _ => _label(value),
      };
}
