import 'dart:convert';

import '../core/config/supabase_config.dart';
import 'geofence_service.dart';

/// Service for loading and persisting the dormitory boundary configuration
/// stored in `public.dorm_boundary_config`.
///
/// All writes go through the `update_dorm_boundary_config` SECURITY DEFINER
/// RPC which enforces owner/staff access and validates input server-side.
///
/// Reading updates the in-memory [GeofenceLocationService] state so every
/// subsequent geofence evaluation uses the saved boundary — no app restart
/// required.
class BoundaryConfigService {
  const BoundaryConfigService();

  /// Fetches the active boundary row, applies it to the in-memory geofence
  /// state, and returns the raw row map.
  ///
  /// Returns `null` when no rows are found or on a network error (callers
  /// should treat null as "keep using current in-memory state").
  Future<Map<String, dynamic>?> loadActiveConfig() async {
    try {
      final row = await SupabaseConfig.client
          .from('dorm_boundary_config')
          .select()
          .eq('is_active', true)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (row == null) return null;
      GeofenceLocationService.applyBoundaryConfiguration(row);
      return Map<String, dynamic>.from(row);
    } catch (_) {
      return null;
    }
  }

  /// Updates the active boundary row via the server RPC and refreshes the
  /// in-memory state.
  ///
  /// Only non-null parameters are sent; omit any field you do not want to
  /// change.  Throws on server or network errors — callers should catch and
  /// display an appropriate message.
  Future<void> updateConfig({
    double? centerLat,
    double? centerLng,
    double? radiusMeters,
    double? edgeBufferMeters,
    String? boundaryMode,
    List<LatLngPoint>? polygonPoints,
  }) async {
    final params = <String, dynamic>{};
    if (centerLat != null) params['p_center_lat'] = centerLat;
    if (centerLng != null) params['p_center_lng'] = centerLng;
    if (radiusMeters != null) params['p_radius_meters'] = radiusMeters;
    if (edgeBufferMeters != null) {
      params['p_edge_buffer_meters'] = edgeBufferMeters;
    }
    if (boundaryMode != null) params['p_boundary_mode'] = boundaryMode;
    if (polygonPoints != null) {
      params['p_polygon_points'] = jsonEncode(
        polygonPoints
            .map((p) => {'lat': p.latitude, 'lng': p.longitude})
            .toList(),
      );
    }

    await SupabaseConfig.client.rpc(
      'update_dorm_boundary_config',
      params: params,
    );

    // Refresh in-memory state so subsequent geofence checks use the new
    // boundary without requiring an app restart.
    await loadActiveConfig();
  }

  /// Configures the optional official-gate wake-up corridor.
  ///
  /// The property polygon remains authoritative for IN/OUT decisions. Passing
  /// [enabled] as false removes the extra gate wake-up hint without disabling
  /// automatic boundary events.
  Future<void> updateGateConfig({
    required bool enabled,
    LatLngPoint? start,
    LatLngPoint? end,
    double toleranceMeters = 3.75,
  }) async {
    if (enabled && (start == null || end == null)) {
      throw ArgumentError('Both gate endpoints are required when enabled.');
    }
    await SupabaseConfig.client.rpc('update_dorm_gate_config', params: {
      'p_enabled': enabled,
      'p_start_lat': start?.latitude,
      'p_start_lng': start?.longitude,
      'p_end_lat': end?.latitude,
      'p_end_lng': end?.longitude,
      'p_tolerance_meters': toleranceMeters,
    });
    await loadActiveConfig();
  }

  /// Extracts a typed summary from a raw `dorm_boundary_config` row map.
  static BoundarySnapshot configFromRow(Map<String, dynamic> row) {
    final rawPoints = row['polygon_points'];
    final points = <LatLngPoint>[];
    if (rawPoints is List) {
      for (final v in rawPoints) {
        if (v is Map && v['lat'] is num && v['lng'] is num) {
          points.add(LatLngPoint(
            (v['lat'] as num).toDouble(),
            (v['lng'] as num).toDouble(),
          ));
        }
      }
    }
    return BoundarySnapshot(
      centerLat: (row['center_latitude'] as num?)?.toDouble() ??
          GeofenceLocationService.carmelitaLatitude,
      centerLng: (row['center_longitude'] as num?)?.toDouble() ??
          GeofenceLocationService.carmelitaLongitude,
      radiusMeters: (row['radius_meters'] as num?)?.toDouble() ??
          GeofenceLocationService.geofenceRadiusMeters,
      edgeBufferMeters: (row['edge_buffer_meters'] as num?)?.toDouble() ??
          GeofenceLocationService.debounceBufferMeters,
      boundaryMode: row['boundary_mode'] as String? ?? 'polygon',
      polygonPoints: points,
      gateEnabled: row['gate_enabled'] == true,
      gateStart: row['gate_start_latitude'] is num &&
              row['gate_start_longitude'] is num
          ? LatLngPoint(
              (row['gate_start_latitude'] as num).toDouble(),
              (row['gate_start_longitude'] as num).toDouble(),
            )
          : null,
      gateEnd:
          row['gate_end_latitude'] is num && row['gate_end_longitude'] is num
              ? LatLngPoint(
                  (row['gate_end_latitude'] as num).toDouble(),
                  (row['gate_end_longitude'] as num).toDouble(),
                )
              : null,
      gateToleranceMeters:
          (row['gate_tolerance_meters'] as num?)?.toDouble() ?? 3.75,
      configVersion: (row['config_version'] as num?)?.toInt() ?? 1,
      updatedAt: row['updated_at'] == null
          ? null
          : DateTime.tryParse(row['updated_at'] as String)?.toLocal(),
    );
  }
}

/// Immutable snapshot of a boundary configuration row.
class BoundarySnapshot {
  const BoundarySnapshot({
    required this.centerLat,
    required this.centerLng,
    required this.radiusMeters,
    required this.edgeBufferMeters,
    required this.boundaryMode,
    required this.polygonPoints,
    required this.gateEnabled,
    required this.gateStart,
    required this.gateEnd,
    required this.gateToleranceMeters,
    required this.configVersion,
    this.updatedAt,
  });

  final double centerLat;
  final double centerLng;
  final double radiusMeters;
  final double edgeBufferMeters;

  /// `'polygon'` or `'circle'`.
  final String boundaryMode;
  final List<LatLngPoint> polygonPoints;
  final bool gateEnabled;
  final LatLngPoint? gateStart;
  final LatLngPoint? gateEnd;
  final double gateToleranceMeters;
  final int configVersion;
  final DateTime? updatedAt;

  bool get isPolygon => boundaryMode == 'polygon';
}
