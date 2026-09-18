import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/role_guard.dart';
import '../../models/models.dart';
import '../../services/geofence_service.dart';

/// Available map layer backgrounds for the perimeter visualizer.
enum MapLayerType {
  satellite,
  streets,
  blueprint,
}

/// Developer and Administrator Geofence Dashboard.
///
/// Features:
/// 1. Real aerial satellite and street map tile visualizer with mathematically exact
///    Web Mercator overlay of the measured 4-corner Carmelita Dormitory polygon.
/// 2. Side-by-side comparison of Polygon vs. Legacy Circular geofence models.
/// 3. Real-time point-in-polygon test evaluator plotting points on the live map.
/// 4. Volatile, in-memory test override panel (strictly non-persistent).
/// 5. Responsive layout guaranteed against RenderFlex overflows on all device sizes.
class GeofenceDevDashboardPage extends StatefulWidget {
  const GeofenceDevDashboardPage({super.key});

  @override
  State<GeofenceDevDashboardPage> createState() =>
      _GeofenceDevDashboardPageState();
}

class _GeofenceDevDashboardPageState extends State<GeofenceDevDashboardPage> {
  // Test evaluator fields
  final _latController = TextEditingController(text: '14.949396');
  final _lngController = TextEditingController(text: '120.884694');
  String _previousDirection = 'NONE';
  GeofenceCheckResult? _lastResult;
  double? _lastEdgeDistance;
  double? _lastCenterDistance;

  // Map view controls
  MapLayerType _selectedLayer = MapLayerType.satellite;
  double _zoomLevel = 19.0;
  double _panOffsetX = 0.0;
  double _panOffsetY = 0.0;

  // Test override form fields
  bool _showOverridePanel = false;
  final _overrideRadiusController = TextEditingController(text: '50.0');

  @override
  void initState() {
    super.initState();
    _evaluateTestPoint();
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    _overrideRadiusController.dispose();
    super.dispose();
  }

  void _evaluateTestPoint() {
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());

    if (lat == null || lng == null) {
      setState(() {
        _lastResult = null;
        _lastEdgeDistance = null;
        _lastCenterDistance = null;
      });
      return;
    }

    final prevDir = _previousDirection == 'NONE' ? null : _previousDirection;
    final result = GeofenceLocationService.evaluateCoordinates(
      latitude: lat,
      longitude: lng,
      previousDirection: prevDir,
    );

    final edgeDist = GeofenceLocationService.distanceToPolygonEdgeMeters(
      lat,
      lng,
      GeofenceLocationService.activePolygon,
    );

    final centerDist = Geolocator.distanceBetween(
      lat,
      lng,
      GeofenceLocationService.carmelitaLatitude,
      GeofenceLocationService.carmelitaLongitude,
    );

    setState(() {
      _lastResult = result;
      _lastEdgeDistance = edgeDist;
      _lastCenterDistance = centerDist;
    });
  }

  void _applyPreset(double lat, double lng, String label) {
    _latController.text = lat.toStringAsFixed(6);
    _lngController.text = lng.toStringAsFixed(6);
    _evaluateTestPoint();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Loaded preset: $label'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _resetOverride() {
    setState(() {
      GeofenceLocationService.resetTestOverride();
      _showOverridePanel = false;
    });
    _evaluateTestPoint();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('In-memory test overrides reset to production boundary.'),
      ),
    );
  }

  void _recenterMap() {
    setState(() {
      _panOffsetX = 0.0;
      _panOffsetY = 0.0;
      _zoomLevel = 19.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activePolygon = GeofenceLocationService.activePolygon;
    final isOverridden = GeofenceLocationService.hasActiveTestOverride;
    final testLat = double.tryParse(_latController.text.trim());
    final testLng = double.tryParse(_lngController.text.trim());

    // Centroid of the polygon lot
    double avgLat = 0.0;
    double avgLng = 0.0;
    if (activePolygon.isNotEmpty) {
      for (final p in activePolygon) {
        avgLat += p.latitude;
        avgLng += p.longitude;
      }
      avgLat /= activePolygon.length;
      avgLng /= activePolygon.length;
    } else {
      avgLat = GeofenceLocationService.carmelitaLatitude;
      avgLng = GeofenceLocationService.carmelitaLongitude;
    }

    return RoleGuard(
        allowedRoles: const {UserRole.owner},
        child: PageFrame(
          title: 'Geofence Dev Dashboard',
          subtitle: 'Perimeter map, ray-casting verification, and overrides',
          actions: [
            IconButton(
              tooltip: 'Toggle Evaluation Mode',
              icon: Icon(
                GeofenceLocationService.usePolygonBoundary
                    ? Icons.polyline_rounded
                    : Icons.radio_button_checked_rounded,
              ),
              onPressed: () {
                setState(() {
                  GeofenceLocationService.usePolygonBoundary =
                      !GeofenceLocationService.usePolygonBoundary;
                });
                _evaluateTestPoint();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      GeofenceLocationService.usePolygonBoundary
                          ? 'Switched to Polygon Boundary Mode (Production)'
                          : 'Switched to Legacy Circular Mode (Fallback)',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isOverridden)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    border:
                        Border.all(color: Colors.amber.shade700, width: 1.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Colors.amber.shade800),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'ACTIVE TEST OVERRIDE: Boundary logic is currently using volatile in-memory parameters.',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                      TextButton(
                        onPressed: _resetOverride,
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                ),

              // 1. Status & Mode Overview
              CarmelitaCard(
                emphasis: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'BOUNDARY STATUS',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        StatusPill(
                          GeofenceLocationService.usePolygonBoundary
                              ? 'Polygon Model (Active)'
                              : 'Circular Model (Legacy)',
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      GeofenceLocationService.usePolygonBoundary
                          ? 'Ray-casting point-in-polygon verification is active with ±3.0m edge hysteresis.'
                          : 'Circular radius verification (50.0m) is active for rollback testing.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Zero-Coordinate Persistence: Lat/Lng coordinates are strictly discarded immediately following on-device computation. Gate logs persist only discrete presence state.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 2. Interactive Map Visualizer
              const SectionTitle(
                'Perimeter Map Visualizer',
                subtitle:
                    'Real aerial satellite & street layout (Brgy. Concepcion, Baliwag)',
              ),
              const SizedBox(height: 10),
              CarmelitaCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Layer Selector and Zoom Level Controls
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        SegmentedButton<MapLayerType>(
                          segments: const [
                            ButtonSegment(
                              value: MapLayerType.satellite,
                              icon: Icon(Icons.satellite_alt_rounded, size: 16),
                              label: Text('Satellite',
                                  style: TextStyle(fontSize: 12)),
                            ),
                            ButtonSegment(
                              value: MapLayerType.streets,
                              icon: Icon(Icons.map_rounded, size: 16),
                              label: Text('Streets',
                                  style: TextStyle(fontSize: 12)),
                            ),
                            ButtonSegment(
                              value: MapLayerType.blueprint,
                              icon: Icon(Icons.grid_on_rounded, size: 16),
                              label: Text('Blueprint',
                                  style: TextStyle(fontSize: 12)),
                            ),
                          ],
                          selected: {_selectedLayer},
                          onSelectionChanged: (set) {
                            setState(() => _selectedLayer = set.first);
                          },
                          style: const ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton.filledTonal(
                              tooltip: 'Zoom In',
                              icon: const Icon(Icons.add, size: 18),
                              onPressed: _zoomLevel < 20.5
                                  ? () => setState(() => _zoomLevel += 0.5)
                                  : null,
                              visualDensity: VisualDensity.compact,
                            ),
                            const SizedBox(width: 4),
                            IconButton.filledTonal(
                              tooltip: 'Zoom Out',
                              icon: const Icon(Icons.remove, size: 18),
                              onPressed: _zoomLevel > 16.5
                                  ? () => setState(() => _zoomLevel -= 0.5)
                                  : null,
                              visualDensity: VisualDensity.compact,
                            ),
                            const SizedBox(width: 4),
                            IconButton.filledTonal(
                              tooltip: 'Recenter on Property',
                              icon: const Icon(Icons.my_location_rounded,
                                  size: 18),
                              onPressed: _recenterMap,
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Interactive Map Viewport with Web Mercator Tiles and Vector Overlay
                    SizedBox(
                      height: 340,
                      width: double.infinity,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          color: _selectedLayer == MapLayerType.blueprint
                              ? (theme.brightness == Brightness.dark
                                  ? const Color(0xFF1E232A)
                                  : const Color(0xFFF1F5F9))
                              : const Color(0xFF0F172A),
                          child: GestureDetector(
                            onPanUpdate: (details) {
                              setState(() {
                                _panOffsetX += details.delta.dx;
                                _panOffsetY += details.delta.dy;
                              });
                            },
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final size = Size(constraints.maxWidth,
                                    constraints.maxHeight);

                                return Stack(
                                  clipBehavior: Clip.hardEdge,
                                  children: [
                                    // 1. Real Map Tiles Layer (Satellite or Streets)
                                    if (_selectedLayer !=
                                        MapLayerType.blueprint)
                                      ..._buildMapTiles(
                                        size: size,
                                        centerLat: avgLat,
                                        centerLng: avgLng,
                                        zoom: _zoomLevel.round(),
                                        panOffset:
                                            Offset(_panOffsetX, _panOffsetY),
                                        layer: _selectedLayer,
                                      ),

                                    // 2. Mathematical Vector Polygon Overlay
                                    Positioned.fill(
                                      child: CustomPaint(
                                        painter: _WebMercatorPolygonPainter(
                                          polygon: activePolygon,
                                          testPoint: (testLat != null &&
                                                  testLng != null)
                                              ? LatLngPoint(testLat, testLng)
                                              : null,
                                          isInside:
                                              _lastResult?.isInside ?? false,
                                          centerLat: avgLat,
                                          centerLng: avgLng,
                                          zoom: _zoomLevel,
                                          panOffset:
                                              Offset(_panOffsetX, _panOffsetY),
                                          isDark: theme.brightness ==
                                              Brightness.dark,
                                          isSatellite: _selectedLayer ==
                                              MapLayerType.satellite,
                                          showGrid: _selectedLayer ==
                                              MapLayerType.blueprint,
                                        ),
                                      ),
                                    ),

                                    // 3. Touch to Pan Guide Overlay
                                    Positioned(
                                      bottom: 8,
                                      left: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black
                                              .withValues(alpha: 0.65),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.pan_tool_outlined,
                                                size: 12,
                                                color: Colors.white70),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Drag to pan • Zoom ${_zoomLevel.toStringAsFixed(1)}x',
                                              style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Responsive Legend (Wrap prevents any horizontal overflow)
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          _legendItem(
                              Colors.greenAccent.shade400, 'Polygon Perimeter'),
                          _legendItem(
                              Colors.cyanAccent.shade400, 'Corners (P1–P4)'),
                          _legendItem(
                            _lastResult?.isInside == true
                                ? Colors.greenAccent.shade400
                                : Colors.redAccent,
                            'Test Point (${_lastResult?.direction ?? 'None'})',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 3. Corner Coordinates and Lot Metrics Table
              const SectionTitle(
                'Perimeter Corner Coordinates',
                subtitle: 'On-site measured GPS markers and edge lengths',
              ),
              const SizedBox(height: 10),
              CarmelitaCard(
                child: Column(
                  children: [
                    for (int i = 0; i < activePolygon.length; i++) ...[
                      _cornerRow(
                        index: i + 1,
                        point: activePolygon[i],
                        nextPoint:
                            activePolygon[(i + 1) % activePolygon.length],
                      ),
                      if (i < activePolygon.length - 1) const Divider(),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 4. Interactive Test Coordinate Evaluator
              const SectionTitle(
                'Coordinate Evaluator',
                subtitle:
                    'Simulate resident position and verify boundary calculation',
              ),
              const SizedBox(height: 10),
              CarmelitaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _latController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Latitude',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => _evaluateTestPoint(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _lngController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Longitude',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => _evaluateTestPoint(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Wrap prevents overflow on narrow screens
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        const Text('Previous direction: ',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        DropdownButton<String>(
                          value: _previousDirection,
                          isDense: true,
                          items: const [
                            DropdownMenuItem(
                                value: 'NONE',
                                child: Text('None (First check)')),
                            DropdownMenuItem(
                                value: 'IN',
                                child: Text('IN (Test Hysteresis)')),
                            DropdownMenuItem(
                                value: 'OUT',
                                child: Text('OUT (Test Hysteresis)')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _previousDirection = val);
                              _evaluateTestPoint();
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Presets
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          label: const Text('Lot Center (IN)'),
                          avatar: const Icon(Icons.location_on, size: 16),
                          onPressed: () =>
                              _applyPreset(14.949396, 120.884694, 'Lot Center'),
                        ),
                        ActionChip(
                          label: const Text('Corner 1 (NE)'),
                          avatar: const Icon(Icons.pin_drop, size: 16),
                          onPressed: () =>
                              _applyPreset(14.949435, 120.884892, 'Corner 1'),
                        ),
                        ActionChip(
                          label: const Text('East Street (OUT)'),
                          avatar: const Icon(Icons.directions_walk, size: 16),
                          onPressed: () => _applyPreset(
                              14.949400, 120.885100, 'East Street'),
                        ),
                        ActionChip(
                          label: const Text('Baliwag Center (OUT)'),
                          avatar: const Icon(Icons.near_me_disabled, size: 16),
                          onPressed: () => _applyPreset(
                              14.954200, 120.900800, 'Baliwag Center'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Evaluation Result Box
                    if (_lastResult != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _lastResult!.isInside
                              ? Colors.green.withValues(alpha: 0.12)
                              : Colors.redAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _lastResult!.isInside
                                ? Colors.green.shade600
                                : Colors.redAccent,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _lastResult!.isInside
                                      ? Icons.check_circle_rounded
                                      : Icons.cancel_rounded,
                                  color: _lastResult!.isInside
                                      ? Colors.green.shade700
                                      : Colors.redAccent.shade700,
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'EVALUATION: ${_lastResult!.direction ?? 'UNAVAILABLE'}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    color: _lastResult!.isInside
                                        ? Colors.green.shade800
                                        : Colors.redAccent.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Distance to property perimeter: ${_lastEdgeDistance?.toStringAsFixed(2)} meters',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'Distance to dorm center: ${_lastCenterDistance?.toStringAsFixed(2)} meters',
                              style: theme.textTheme.bodySmall,
                            ),
                            if (_lastEdgeDistance != null &&
                                _lastEdgeDistance! <=
                                    GeofenceLocationService
                                        .debounceBufferMeters)
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Note: Point is inside the ±3.0m edge hysteresis band. Previous direction will prevent boundary flapping.',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 5. Volatile In-Memory Test Override Panel
              CarmelitaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.science_outlined),
                      title: const Text(
                        'In-Memory Test Override Panel',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: const Text(
                        'Modify boundary parameters for local testing. Strictly volatile, never written to DB.',
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          _showOverridePanel
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                        ),
                        onPressed: () => setState(
                            () => _showOverridePanel = !_showOverridePanel),
                      ),
                    ),
                    if (_showOverridePanel) ...[
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        'STRICT ISOLATION GUARANTEE: Any values configured below exist only in ephemeral process memory. They will not persist across app restarts and will never modify Supabase configuration.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 360;
                          if (isNarrow) {
                            return Column(
                              children: [
                                TextField(
                                  controller: _overrideRadiusController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'Test Circular Radius (meters)',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      final r = double.tryParse(
                                          _overrideRadiusController.text
                                              .trim());
                                      if (r != null && r > 0) {
                                        setState(() {
                                          GeofenceLocationService
                                              .setTestRadiusOverride(r);
                                          GeofenceLocationService
                                              .usePolygonBoundary = false;
                                        });
                                        _evaluateTestPoint();
                                      }
                                    },
                                    child: const Text('Apply Radius'),
                                  ),
                                ),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _overrideRadiusController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'Test Circular Radius (meters)',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                onPressed: () {
                                  final r = double.tryParse(
                                      _overrideRadiusController.text.trim());
                                  if (r != null && r > 0) {
                                    setState(() {
                                      GeofenceLocationService
                                          .setTestRadiusOverride(r);
                                      GeofenceLocationService
                                          .usePolygonBoundary = false;
                                    });
                                    _evaluateTestPoint();
                                  }
                                },
                                child: const Text('Apply Radius'),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: _resetOverride,
                            icon: const Icon(Icons.restart_alt_rounded),
                            label: const Text('Reset to Production'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ));
  }

  /// Generates the Web Mercator map image tiles covering the active viewport.
  List<Widget> _buildMapTiles({
    required Size size,
    required double centerLat,
    required double centerLng,
    required int zoom,
    required Offset panOffset,
    required MapLayerType layer,
  }) {
    final centerWorldX =
        _lngToWorldX(centerLng, zoom.toDouble()) - panOffset.dx;
    final centerWorldY =
        _latToWorldY(centerLat, zoom.toDouble()) - panOffset.dy;

    final minWorldX = centerWorldX - size.width / 2.0;
    final maxWorldX = centerWorldX + size.width / 2.0;
    final minWorldY = centerWorldY - size.height / 2.0;
    final maxWorldY = centerWorldY + size.height / 2.0;

    final minTileX = (minWorldX / 256.0).floor();
    final maxTileX = (maxWorldX / 256.0).floor();
    final minTileY = (minWorldY / 256.0).floor();
    final maxTileY = (maxWorldY / 256.0).floor();

    final List<Widget> tileWidgets = [];
    final maxTileIndex = (1 << zoom) - 1;

    for (int tx = minTileX; tx <= maxTileX; tx++) {
      for (int ty = minTileY; ty <= maxTileY; ty++) {
        if (ty < 0 || ty > maxTileIndex) continue;
        final wrappedTx = (tx % (1 << zoom) + (1 << zoom)) % (1 << zoom);

        final screenX = (size.width / 2.0) + (tx * 256.0 - centerWorldX);
        final screenY = (size.height / 2.0) + (ty * 256.0 - centerWorldY);

        final String tileUrl;
        if (layer == MapLayerType.satellite) {
          tileUrl =
              'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/$zoom/$ty/$wrappedTx';
        } else {
          tileUrl = 'https://tile.openstreetmap.org/$zoom/$wrappedTx/$ty.png';
        }

        tileWidgets.add(
          Positioned(
            left: screenX,
            top: screenY,
            width: 256,
            height: 256,
            child: Image.network(
              tileUrl,
              fit: BoxFit.cover,
              headers: const {'User-Agent': 'CarmelitasDormitory/1.0'},
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        );
      }
    }
    return tileWidgets;
  }

  Widget _legendItem(Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(label,
              style:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      );

  Widget _cornerRow({
    required int index,
    required LatLngPoint point,
    required LatLngPoint nextPoint,
  }) {
    final edgeLength = Geolocator.distanceBetween(
      point.latitude,
      point.longitude,
      nextPoint.latitude,
      nextPoint.longitude,
    );

    final cornerLabels = [
      'Corner 1 (East / NE)',
      'Corner 2 (South / SE)',
      'Corner 3 (West / SW)',
      'Corner 4 (North / NW)',
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Text(
              'P$index',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cornerLabels[(index - 1) % cornerLabels.length],
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${point.latitude.toStringAsFixed(8)}, ${point.longitude.toStringAsFixed(8)}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '→ P${index == 4 ? 1 : index + 1}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              Text(
                '${edgeLength.toStringAsFixed(1)}m',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Helpers for Web Mercator EPSG:3857 projection
double _lngToWorldX(double lng, double zoom) =>
    ((lng + 180.0) / 360.0) * 256.0 * math.pow(2, zoom);

double _latToWorldY(double lat, double zoom) {
  final sinLat = math.sin(lat * math.pi / 180.0).clamp(-0.9999, 0.9999);
  return (0.5 - math.log((1.0 + sinLat) / (1.0 - sinLat)) / (4.0 * math.pi)) *
      256.0 *
      math.pow(2, zoom);
}

/// Custom canvas painter that projects geographic GPS coordinates using standard
/// Web Mercator EPSG:3857 math onto the map tiles viewport.
class _WebMercatorPolygonPainter extends CustomPainter {
  const _WebMercatorPolygonPainter({
    required this.polygon,
    this.testPoint,
    required this.isInside,
    required this.centerLat,
    required this.centerLng,
    required this.zoom,
    required this.panOffset,
    required this.isDark,
    required this.isSatellite,
    required this.showGrid,
  });

  final List<LatLngPoint> polygon;
  final LatLngPoint? testPoint;
  final bool isInside;
  final double centerLat;
  final double centerLng;
  final double zoom;
  final Offset panOffset;
  final bool isDark;
  final bool isSatellite;
  final bool showGrid;

  @override
  void paint(Canvas canvas, Size size) {
    if (polygon.isEmpty) return;

    final centerWorldX = _lngToWorldX(centerLng, zoom) - panOffset.dx;
    final centerWorldY = _latToWorldY(centerLat, zoom) - panOffset.dy;

    Offset toCanvas(LatLngPoint p) {
      final wx = _lngToWorldX(p.longitude, zoom);
      final wy = _latToWorldY(p.latitude, zoom);
      final sx = (size.width / 2.0) + (wx - centerWorldX);
      final sy = (size.height / 2.0) + (wy - centerWorldY);
      return Offset(sx, sy);
    }

    // 1. Draw subtle background grid if in blueprint mode
    if (showGrid) {
      final gridPaint = Paint()
        ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06)
        ..strokeWidth = 1.0;
      for (int i = 1; i < 7; i++) {
        final x = size.width * (i / 7.0);
        final y = size.height * (i / 7.0);
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }
    }

    // 2. Draw Polygon Fill and Outline
    final polyPath = Path();
    final offsets = polygon.map(toCanvas).toList();
    polyPath.moveTo(offsets[0].dx, offsets[0].dy);
    for (int i = 1; i < offsets.length; i++) {
      polyPath.lineTo(offsets[i].dx, offsets[i].dy);
    }
    polyPath.close();

    // High contrast translucent fill
    final fillPaint = Paint()
      ..color = Colors.greenAccent.withValues(alpha: isSatellite ? 0.35 : 0.25)
      ..style = PaintingStyle.fill;
    canvas.drawPath(polyPath, fillPaint);

    // Outer dark shadow stroke for readability on light or bright aerial imagery
    final shadowStroke = Paint()
      ..color = Colors.black.withValues(alpha: 0.75)
      ..strokeWidth = 5.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(polyPath, shadowStroke);

    // Inner bright neon boundary stroke
    final strokePaint = Paint()
      ..color = const Color(0xFF00E676)
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke;
    canvas.drawPath(polyPath, strokePaint);

    // 3. Draw North Cardinal Compass Indicator
    const compassCenter = Offset(32, 32);
    final compassBg = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(compassCenter, 18, compassBg);

    final northPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.2;
    canvas.drawLine(const Offset(32, 40), const Offset(32, 20), northPaint);

    final arrowHead = Path()
      ..moveTo(32, 17)
      ..lineTo(28, 24)
      ..lineTo(36, 24)
      ..close();
    canvas.drawPath(arrowHead, Paint()..color = Colors.redAccent);

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'N',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, const Offset(29, 36));

    // 4. Draw Vertex Badges and Labels
    for (int i = 0; i < offsets.length; i++) {
      final pt = offsets[i];

      // White halo
      canvas.drawCircle(
        pt,
        8.0,
        Paint()..color = Colors.black.withValues(alpha: 0.7),
      );
      // Cyan vertex circle
      canvas.drawCircle(
        pt,
        6.0,
        Paint()..color = Colors.cyanAccent.shade400,
      );
      canvas.drawCircle(
        pt,
        2.5,
        Paint()..color = Colors.black,
      );

      // Label background chip
      final labelBg = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(pt.dx + 16, pt.dy - 12),
          width: 24,
          height: 16,
        ),
        const Radius.circular(4),
      );
      canvas.drawRRect(
        labelBg,
        Paint()..color = Colors.black.withValues(alpha: 0.75),
      );

      final labelPainter = TextPainter(
        text: TextSpan(
          text: 'P${i + 1}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 10,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      labelPainter.paint(canvas, Offset(pt.dx + 9, pt.dy - 19));
    }

    // 5. Draw Simulated Test Point if present
    if (testPoint != null) {
      final pt = toCanvas(testPoint!);
      final pointColor =
          isInside ? Colors.greenAccent.shade400 : Colors.redAccent;

      // Outer ripple
      canvas.drawCircle(
        pt,
        14.0,
        Paint()..color = pointColor.withValues(alpha: 0.35),
      );
      // Center halo
      canvas.drawCircle(
        pt,
        7.0,
        Paint()..color = Colors.black.withValues(alpha: 0.8),
      );
      // Main dot
      canvas.drawCircle(
        pt,
        5.5,
        Paint()..color = pointColor,
      );
      canvas.drawCircle(
        pt,
        2.0,
        Paint()..color = Colors.white,
      );

      // Label
      final testLabelBg = RRect.fromRectAndRadius(
        Rect.fromLTWH(pt.dx + 10, pt.dy - 12, 66, 20),
        const Radius.circular(5),
      );
      canvas.drawRRect(
        testLabelBg,
        Paint()..color = Colors.black.withValues(alpha: 0.8),
      );

      final testLabel = TextPainter(
        text: TextSpan(
          text: isInside ? 'Test: IN' : 'Test: OUT',
          style: TextStyle(
            color: pointColor,
            fontWeight: FontWeight.w900,
            fontSize: 11,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      testLabel.paint(canvas, Offset(pt.dx + 15, pt.dy - 9));
    }
  }

  @override
  bool shouldRepaint(covariant _WebMercatorPolygonPainter oldDelegate) =>
      oldDelegate.polygon != polygon ||
      oldDelegate.testPoint != testPoint ||
      oldDelegate.isInside != isInside ||
      oldDelegate.centerLat != centerLat ||
      oldDelegate.centerLng != centerLng ||
      oldDelegate.zoom != zoom ||
      oldDelegate.panOffset != panOffset ||
      oldDelegate.isDark != isDark ||
      oldDelegate.isSatellite != isSatellite ||
      oldDelegate.showGrid != showGrid;
}
