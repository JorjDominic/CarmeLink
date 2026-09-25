import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import 'app_notification_service.dart';

const maintenanceStatusLabels = <String, String>{
  'pending': 'Pending',
  'assigned': 'Assigned',
  'in_progress': 'In Progress',
  'resolved': 'Resolved',
  'cancelled': 'Cancelled',
};

List<String> allowedMaintenanceStatuses(String status) => switch (status) {
      'pending' => ['pending', 'assigned', 'in_progress', 'cancelled'],
      'assigned' => ['assigned', 'in_progress', 'cancelled'],
      'in_progress' => ['in_progress', 'resolved', 'cancelled'],
      'resolved' => ['resolved', 'in_progress'],
      'cancelled' => ['cancelled'],
      _ => [status],
    };

class StaffMaintenanceReport {
  StaffMaintenanceReport.fromRow(Map<String, dynamic> row)
      : id = row['id'] as String,
        tenantId = row['tenant_id'] as String? ?? '',
        tenantName = (row['tenant'] as Map?)?['full_name'] as String? ??
            'Tenant unavailable',
        category = row['category'] as String,
        description = row['description'] as String,
        location = row['location'] as String,
        urgency = row['urgency'] as String,
        status = row['status'] as String,
        photoPath = row['photo_path'] as String?,
        notes = (row['staff_notes'] as String?) ?? '',
        updatedAt = (row['updated_at'] as String?) ?? '',
        createdAt = row['created_at'] != null
            ? DateTime.parse(row['created_at'] as String).toLocal()
            : DateTime.now(),
        resolvedAt = row['resolved_at'] == null
            ? null
            : DateTime.parse(row['resolved_at'] as String).toLocal();

  const StaffMaintenanceReport({
    required this.id,
    this.tenantId = '',
    required this.tenantName,
    required this.category,
    required this.description,
    required this.location,
    required this.urgency,
    required this.status,
    required this.notes,
    required this.updatedAt,
    this.photoPath,
    required this.createdAt,
    this.resolvedAt,
  });

  final String id;
  final String tenantId;
  final String tenantName;
  final String category;
  final String description;
  final String location;
  final String urgency;
  final String status;
  final String notes;

  // Keep the original timestamp for the concurrent-edit check.
  final String updatedAt;

  final String? photoPath;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  String get statusLabel => maintenanceStatusLabels[status] ?? status;

  bool get isOpen => status != 'resolved' && status != 'cancelled';
  bool get isPending => status == 'pending';
  bool get isAssigned => status == 'assigned';
  bool get isInProgress => status == 'in_progress';
  bool get isResolved => status == 'resolved';
  bool get isCancelled => status == 'cancelled';

  bool get isHighUrgency => urgency.toLowerCase() == 'high';
  bool get isMediumUrgency => urgency.toLowerCase() == 'medium';
  bool get isLowUrgency => urgency.toLowerCase() == 'low';

  StaffMaintenanceReport copyWith({
    String? id,
    String? tenantId,
    String? tenantName,
    String? category,
    String? description,
    String? location,
    String? urgency,
    String? status,
    String? notes,
    String? updatedAt,
    String? photoPath,
    DateTime? createdAt,
    DateTime? resolvedAt,
  }) {
    return StaffMaintenanceReport(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      tenantName: tenantName ?? this.tenantName,
      category: category ?? this.category,
      description: description ?? this.description,
      location: location ?? this.location,
      urgency: urgency ?? this.urgency,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
      photoPath: photoPath ?? this.photoPath,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }
}

class StaffMaintenanceService {
  const StaffMaintenanceService([SupabaseClient? client])
      : _clientOverride = client;

  final SupabaseClient? _clientOverride;
  SupabaseClient get _client => _clientOverride ?? SupabaseConfig.client;

  static const _columns =
      'id, tenant_id, category, description, location, urgency, status, photo_path, '
      'staff_notes, updated_at, created_at, resolved_at, '
      'tenant:profiles!maintenance_reports_tenant_id_fkey(full_name)';

  Future<List<StaffMaintenanceReport>> listReports() async {
    final rows = await _client
        .from('maintenance_reports')
        .select(_columns)
        .order('created_at', ascending: false);

    final reports = rows.map(StaffMaintenanceReport.fromRow).toList();

    const priority = {
      'high': 0,
      'medium': 1,
      'low': 2,
    };

    reports.sort((a, b) {
      if (a.isOpen != b.isOpen) {
        return a.isOpen ? -1 : 1;
      }

      final rank =
          (priority[a.urgency] ?? 3).compareTo(priority[b.urgency] ?? 3);

      return rank == 0 ? b.createdAt.compareTo(a.createdAt) : rank;
    });

    return reports;
  }

  Future<StaffMaintenanceReport> getReport(String id) async {
    final row = await _client
        .from('maintenance_reports')
        .select(_columns)
        .eq('id', id)
        .single();

    return StaffMaintenanceReport.fromRow(row);
  }

  Future<List<Map<String, dynamic>>> history(String id) async {
    final rows = await _client
        .from('maintenance_staff_history')
        .select(
          'actor_name, previous_status, next_status, notes, created_at',
        )
        .eq('report_id', id)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(rows);
  }

  Future<String?> photoUrl(String? path) async {
    if (path == null || path.isEmpty) {
      return null;
    }

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    return _client.storage
        .from('maintenance-photos')
        .createSignedUrl(path, 3600);
  }

  Future<void> save(
    StaffMaintenanceReport report,
    String status,
    String notes,
  ) async {
    await _client.rpc(
      'update_staff_maintenance',
      params: {
        'p_report_id': report.id,
        'p_expected_updated_at': report.updatedAt,
        'p_status': status,
        'p_notes': notes.trim(),
      },
    );
    if (report.tenantId.isNotEmpty && status != report.status) {
      unawaited(AppNotificationService.instance.notifyMaintenanceStatusChanged(
        tenantId: report.tenantId,
        reportId: report.id,
        category: report.category,
        status: maintenanceStatusLabels[status] ?? status,
        notes: notes,
      ));
    }
  }
}

String staffMaintenanceError(Object error) {
  if (error is PostgrestException) {
    return error.message;
  }

  if (error is AuthException) {
    return error.message;
  }

  if (error is StorageException) {
    return error.message;
  }

  return 'Unable to load or save maintenance data. '
      'Check your connection and retry.';
}
