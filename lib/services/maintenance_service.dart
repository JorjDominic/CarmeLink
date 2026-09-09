import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../models/models.dart';

class MaintenanceService {
  const MaintenanceService();

  SupabaseClient get _client => SupabaseConfig.client;

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
        .select(
          'id, tenant_id, category, description, location, urgency, status, created_at, updated_at',
        )
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
        .select(
          'id, tenant_id, category, description, location, urgency, status, created_at, updated_at',
        )
        .single();

    return _fromRow(row);
  }

  Future<MaintenanceReport> updateReport({
    required String id,
    required String category,
    required String description,
    required String location,
    required String urgency,
  }) async {
    final tenantId = _requireTenantId();

    final row = await _client
        .from('maintenance_reports')
        .update({
          'category': category.trim(),
          'description': description.trim(),
          'location': location.trim(),
          'urgency': urgency.trim().toLowerCase(),
        })
        .eq('id', id)
        .eq('tenant_id', tenantId)
        .select(
          'id, tenant_id, category, description, location, urgency, status, created_at, updated_at',
        )
        .single();

    return _fromRow(row);
  }

  Future<void> deleteReport(String id) async {
    final tenantId = _requireTenantId();

    final deletedRows = await _client
        .from('maintenance_reports')
        .delete()
        .eq('id', id)
        .eq('tenant_id', tenantId)
        .select('id');

    if (deletedRows.isEmpty) {
      throw Exception(
        'This maintenance report could not be deleted. Only pending reports can be deleted.',
      );
    }
  }

  MaintenanceReport _fromRow(Map<String, dynamic> row) {
    return MaintenanceReport(
      id: row['id'] as String,
      category: row['category'] as String,
      description: row['description'] as String,
      location: row['location'] as String,
      urgency: _label(row['urgency'] as String),
      status: _statusLabel(row['status'] as String),
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    );
  }

  String _label(String value) {
    if (value.isEmpty) return value;

    return '${value[0].toUpperCase()}${value.substring(1)}';
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
