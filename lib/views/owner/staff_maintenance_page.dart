import 'package:flutter/material.dart';

import '../../controllers/owner_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/common_widgets.dart';
import '../../services/staff_maintenance_service.dart';
import '../../services/table_refresh_subscription.dart';
import '../widgets/feature_widgets.dart';

class StaffMaintenancePage extends StatefulWidget {
  const StaffMaintenancePage({super.key});

  @override
  State<StaffMaintenancePage> createState() => _StaffMaintenancePageState();
}

class _StaffMaintenancePageState extends State<StaffMaintenancePage> {
  final _controller = OwnerController.instance;
  late final TableRefreshSubscription _subscription;
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _selectedStatus = 'open';
  String _selectedUrgency = 'all';
  bool _showFloorPlan = false;

  @override
  void initState() {
    super.initState();
    _controller.loadStaffMaintenance();
    _subscription = TableRefreshSubscription(
      'staff-maintenance',
      ['maintenance_reports', 'maintenance_staff_history'],
      _onRealtimeRefresh,
    );
  }

  @override
  void dispose() {
    _subscription.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onRealtimeRefresh() {
    if (mounted) {
      _controller.loadStaffMaintenance(force: true);
    }
  }

  IconData _categoryIcon(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('plumb')) return Icons.plumbing;
    if (lower.contains('electr')) return Icons.bolt;
    if (lower.contains('furnitur') || lower.contains('bed')) return Icons.chair;
    if (lower.contains('appliance') || lower.contains('fridge')) {
      return Icons.kitchen;
    }
    if (lower.contains('carpentr') ||
        lower.contains('door') ||
        lower.contains('window')) {
      return Icons.home_repair_service;
    }
    if (lower.contains('internet') || lower.contains('wifi')) {
      return Icons.wifi;
    }
    if (lower.contains('clean')) return Icons.cleaning_services;
    if (lower.contains('lock') || lower.contains('key')) return Icons.lock;
    return Icons.build_outlined;
  }

  Color _urgencyColor(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'high':
        return AppColors.danger;
      case 'medium':
        return AppColors.warning;
      case 'low':
        return AppColors.info;
      default:
        return AppColors.taupe;
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    }
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final allReports = _controller.staffMaintenanceReports;
        final isLoading = _controller.maintenanceLoading && allReports.isEmpty;
        final error = _controller.maintenanceError;

        // Apply filters
        final filteredReports = allReports.where((report) {
          // Status filter
          if (_selectedStatus == 'open' && !report.isOpen) return false;
          if (_selectedStatus != 'all' &&
              _selectedStatus != 'open' &&
              report.status != _selectedStatus) {
            return false;
          }

          // Urgency filter
          if (_selectedUrgency != 'all' &&
              report.urgency.toLowerCase() != _selectedUrgency) {
            return false;
          }

          // Search query
          if (_searchQuery.isNotEmpty) {
            final query = _searchQuery.toLowerCase();
            final matches = report.category.toLowerCase().contains(query) ||
                report.location.toLowerCase().contains(query) ||
                report.tenantName.toLowerCase().contains(query) ||
                report.description.toLowerCase().contains(query) ||
                report.statusLabel.toLowerCase().contains(query);
            if (!matches) return false;
          }

          return true;
        }).toList();

        final pendingCount =
            allReports.where((r) => r.status == 'pending').length;
        final assignedCount =
            allReports.where((r) => r.status == 'assigned').length;
        final inProgressCount =
            allReports.where((r) => r.status == 'in_progress').length;
        final resolvedCount =
            allReports.where((r) => r.status == 'resolved').length;
        final cancelledCount =
            allReports.where((r) => r.status == 'cancelled').length;

        return PageFrame(
          title: 'Maintenance Management',
          subtitle: 'Live tenant reports, status triage, and audit trail',
          onRefresh: () => _controller.loadStaffMaintenance(force: true),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Operations Overview',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkBrown,
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          _showFloorPlan ? Icons.map : Icons.map_outlined,
                          color: _showFloorPlan
                              ? AppColors.brown
                              : AppColors.taupe,
                        ),
                        tooltip: _showFloorPlan
                            ? 'Hide Floor Plan'
                            : 'Floor Plan Overview',
                        onPressed: () =>
                            setState(() => _showFloorPlan = !_showFloorPlan),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Refresh list',
                        onPressed: () =>
                            _controller.loadStaffMaintenance(force: true),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Metric Summary Cards - using default compact=false to ensure ample height and no vertical overflows
              MutedDashboardGrid(
                compact: false,
                items: [
                  MutedDashboardItem(
                    label: 'Open Issues',
                    value: '${_controller.openMaintenance}',
                    detail: 'Requires attention',
                    icon: Icons.pending_actions,
                    color: AppColors.warning,
                    onTap: () => setState(() => _selectedStatus = 'open'),
                  ),
                  MutedDashboardItem(
                    label: 'High Priority',
                    value: '${_controller.highPriorityMaintenance}',
                    detail: 'Urgent resolution',
                    icon: Icons.priority_high,
                    color: AppColors.danger,
                    onTap: () => setState(() => _selectedUrgency =
                        _selectedUrgency == 'high' ? 'all' : 'high'),
                  ),
                  MutedDashboardItem(
                    label: 'In Progress',
                    value: '${_controller.inProgressMaintenanceCount}',
                    detail: 'Currently handled',
                    icon: Icons.engineering_outlined,
                    color: AppColors.info,
                    onTap: () =>
                        setState(() => _selectedStatus = 'in_progress'),
                  ),
                  MutedDashboardItem(
                    label: 'Resolved',
                    value: '${_controller.resolvedMaintenanceCount}',
                    detail: 'Completed issues',
                    icon: Icons.check_circle_outline,
                    color: AppColors.success,
                    onTap: () => setState(() => _selectedStatus = 'resolved'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Optional Floor Plan Section
              if (_showFloorPlan) ...[
                CarmelitaCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.apartment,
                                  color: AppColors.brown, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Dormitory Floor Plan Monitoring',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () =>
                                setState(() => _showFloorPlan = false),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Inspect active maintenance issues tagged by room location:',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.taupe,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const FloorPlanCanvas(monitorMode: true),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Search Bar
              TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                decoration: InputDecoration(
                  hintText: 'Search by tenant, room, category, or issue...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.softBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.softBorder),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All', 'all', allReports.length),
                    const SizedBox(width: 8),
                    _buildFilterChip('Pending', 'pending', pendingCount),
                    const SizedBox(width: 8),
                    _buildFilterChip('Assigned', 'assigned', assignedCount),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                        'In Progress', 'in_progress', inProgressCount),
                    const SizedBox(width: 8),
                    _buildFilterChip('Resolved', 'resolved', resolvedCount),
                    const SizedBox(width: 8),
                    _buildFilterChip('Cancelled', 'cancelled', cancelledCount),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Content Body
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (error != null && allReports.isEmpty)
                CarmelitaCard(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.danger, size: 40),
                        const SizedBox(height: 8),
                        Text(
                          error,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.danger),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () =>
                              _controller.loadStaffMaintenance(force: true),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (filteredReports.isEmpty)
                CarmelitaCard(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 36),
                    child: Column(
                      children: [
                        const Icon(Icons.assignment_turned_in_outlined,
                            size: 48, color: AppColors.taupe),
                        const SizedBox(height: 12),
                        Text(
                          allReports.isEmpty
                              ? 'No maintenance requests logged yet.'
                              : 'No reports match the selected filters.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkBrown,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          allReports.isEmpty
                              ? 'New issues reported by tenants will appear here in real-time.'
                              : 'Try adjusting your search keywords or filter criteria.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.taupe,
                          ),
                        ),
                        if (_selectedStatus != 'all' ||
                            _selectedUrgency != 'all' ||
                            _searchQuery.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          OutlinedButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _selectedStatus = 'all';
                                _selectedUrgency = 'all';
                              });
                            },
                            child: const Text('Reset Filters'),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredReports.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final report = filteredReports[index];
                    final urgencyCol = _urgencyColor(report.urgency);
                    final categoryIcon = _categoryIcon(report.category);

                    return CarmelitaCard(
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => _StaffMaintenanceDetailsPage(
                              id: report.id,
                              initialReport: report,
                            ),
                          ),
                        );
                        _controller.loadStaffMaintenance(force: true);
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Bar: Category, Location, Status, Urgency
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: urgencyCol.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(categoryIcon,
                                    size: 20, color: urgencyCol),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      report.category,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: AppColors.darkBrown,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        const Icon(Icons.room_outlined,
                                            size: 13, color: AppColors.taupe),
                                        const SizedBox(width: 3),
                                        Expanded(
                                          child: Text(
                                            report.location,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: AppColors.taupe,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  StatusPill(report.statusLabel),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: urgencyCol.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: urgencyCol.withValues(
                                              alpha: 0.3)),
                                    ),
                                    child: Text(
                                      '${report.urgency[0].toUpperCase()}${report.urgency.substring(1).toLowerCase()} Priority',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: urgencyCol,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Description
                          Text(
                            report.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: AppColors.charcoal,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 8),

                          // Footer Row: Tenant, Date, Photo Badge, Chevron
                          Row(
                            children: [
                              const Icon(Icons.person_outline,
                                  size: 14, color: AppColors.taupe),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  report.tenantName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.brown,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '• ${_formatDate(report.createdAt)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.taupe,
                                ),
                              ),
                              if (report.photoPath != null &&
                                  report.photoPath!.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.cream,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.photo_camera_back_outlined,
                                          size: 11, color: AppColors.brown),
                                      SizedBox(width: 2),
                                      Text(
                                        'Photo',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: AppColors.brown,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const Spacer(),
                              const Text(
                                'Triage',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.brown,
                                ),
                              ),
                              const Icon(Icons.chevron_right,
                                  size: 16, color: AppColors.brown),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String label, String value, int count) {
    final isSelected = _selectedStatus == value;
    return FilterChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedStatus = value),
      selectedColor: AppColors.brown,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? Colors.white : AppColors.darkBrown,
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? AppColors.brown : AppColors.softBorder,
        ),
      ),
    );
  }
}

class _StaffMaintenanceDetailsPage extends StatefulWidget {
  const _StaffMaintenanceDetailsPage({
    required this.id,
    this.initialReport,
  });

  final String id;
  final StaffMaintenanceReport? initialReport;

  @override
  State<_StaffMaintenanceDetailsPage> createState() =>
      _StaffMaintenanceDetailsPageState();
}

class _StaffMaintenanceDetailsPageState
    extends State<_StaffMaintenanceDetailsPage> {
  final _service = const StaffMaintenanceService();
  final _notes = TextEditingController();

  StaffMaintenanceReport? _report;
  List<Map<String, dynamic>> _history = [];
  String? _photoUrl;
  String? _photoError;
  String? _error;
  String? _status;
  bool _loading = true;
  bool _saving = false;
  bool _showFloorPlanModal = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialReport != null) {
      _report = widget.initialReport;
      _status = widget.initialReport!.status;
      _notes.text = widget.initialReport!.notes;
    }
    _load();
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _report == null;
      _error = null;
    });

    try {
      final report = await _service.getReport(widget.id);
      final history = await _service.history(widget.id);
      String? photo;
      String? photoError;

      try {
        photo = await _service.photoUrl(report.photoPath);
      } catch (error) {
        photoError = staffMaintenanceError(error);
      }

      if (!mounted) return;
      setState(() {
        _report = report;
        _history = history;
        _photoUrl = photo;
        _photoError = photoError;
        _status = report.status;
        _notes.text = report.notes;
      });
    } catch (error) {
      if (mounted) setState(() => _error = staffMaintenanceError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if ((_status == 'resolved' || _status == 'cancelled') &&
        _notes.text.trim().isEmpty) {
      setState(() => _error =
          'Resolution details or a cancellation reason must be recorded in the notes.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await _service.save(_report!, _status!, _notes.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maintenance status updated successfully.'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) setState(() => _error = staffMaintenanceError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showZoomablePhoto(String url) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black.withValues(alpha: 0.65),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Maintenance Triage'),
        actions: [
          IconButton(
            onPressed: _loading || _saving ? null : _load,
            tooltip: 'Reload report',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.danger.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppColors.danger, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                  color: AppColors.danger, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (report != null) ...[
                    // Report Header Card
                    CarmelitaCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  report.category,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.darkBrown,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              StatusPill(
                                maintenanceStatusLabels[_status] ??
                                    _status ??
                                    report.statusLabel,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.meeting_room_outlined,
                                  size: 16, color: AppColors.brown),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  report.location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.brown,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: report.isHighUrgency
                                      ? AppColors.danger.withValues(alpha: 0.1)
                                      : AppColors.warning
                                          .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${report.urgency[0].toUpperCase()}${report.urgency.substring(1).toLowerCase()} Urgency',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: report.isHighUrgency
                                        ? AppColors.danger
                                        : AppColors.warning,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const CircleAvatar(
                                radius: 14,
                                backgroundColor: AppColors.cream,
                                child: Icon(Icons.person,
                                    size: 16, color: AppColors.brown),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      report.tenantName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      'Submitted: ${report.createdAt.month}/${report.createdAt.day}/${report.createdAt.year} at ${report.createdAt.hour}:${report.createdAt.minute.toString().padLeft(2, '0')}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.taupe,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Problem Description
                    CarmelitaCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.notes,
                                  size: 18, color: AppColors.brown),
                              SizedBox(width: 8),
                              Text(
                                'Issue Description',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.darkBrown,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            report.description,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: AppColors.charcoal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Floor Plan Location Card
                    CarmelitaCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined,
                                  size: 18, color: AppColors.brown),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Location: ${report.location}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.darkBrown,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: () => setState(() =>
                                    _showFloorPlanModal = !_showFloorPlanModal),
                                icon: Icon(
                                  _showFloorPlanModal
                                      ? Icons.keyboard_arrow_up
                                      : Icons.map,
                                  size: 16,
                                ),
                                label: Text(_showFloorPlanModal
                                    ? 'Hide Map'
                                    : 'Floor Plan'),
                              ),
                            ],
                          ),
                          if (_showFloorPlanModal) ...[
                            const SizedBox(height: 10),
                            const FloorPlanCanvas(monitorMode: true),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Photo Inspection Card
                    CarmelitaCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.camera_alt_outlined,
                                  size: 18, color: AppColors.brown),
                              SizedBox(width: 8),
                              Text(
                                'Attached Photo Evidence',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.darkBrown,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_photoUrl != null)
                            GestureDetector(
                              onTap: () => _showZoomablePhoto(_photoUrl!),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Stack(
                                  children: [
                                    Image.network(
                                      _photoUrl!,
                                      height: 220,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      loadingBuilder:
                                          (context, child, loadingProgress) {
                                        if (loadingProgress == null) {
                                          return child;
                                        }
                                        return Container(
                                          height: 220,
                                          alignment: Alignment.center,
                                          child:
                                              const CircularProgressIndicator(),
                                        );
                                      },
                                      errorBuilder: (_, __, ___) => Container(
                                        height: 160,
                                        color: AppColors.cream,
                                        alignment: Alignment.center,
                                        child: const Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.broken_image_outlined,
                                              size: 36,
                                              color: AppColors.taupe,
                                            ),
                                            SizedBox(height: 6),
                                            Text(
                                              'Could not load attached photo',
                                              style: TextStyle(
                                                color: AppColors.taupe,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: Colors.black
                                              .withValues(alpha: 0.65),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.zoom_in,
                                                color: Colors.white, size: 14),
                                            SizedBox(width: 4),
                                            Text(
                                              'Tap to inspect',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else if (_photoError != null)
                            Text(
                              'Photo error: $_photoError',
                              style: const TextStyle(
                                  color: AppColors.danger, fontSize: 13),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              alignment: Alignment.center,
                              child: const Column(
                                children: [
                                  Icon(Icons.image_not_supported_outlined,
                                      color: AppColors.taupe, size: 36),
                                  SizedBox(height: 6),
                                  Text(
                                    'No photo was attached by the tenant.',
                                    style: TextStyle(
                                        color: AppColors.taupe, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Status Triage & Transitions
                    CarmelitaCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.tune,
                                  size: 18, color: AppColors.brown),
                              SizedBox(width: 8),
                              Text(
                                'Status Triage & Staff Actions',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.darkBrown,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Quick Action Buttons
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (_status != 'in_progress' &&
                                  allowedMaintenanceStatuses(report.status)
                                      .contains('in_progress'))
                                ActionChip(
                                  avatar: const Icon(Icons.play_arrow,
                                      size: 16, color: Colors.white),
                                  label: const Text('Start Work'),
                                  backgroundColor: const Color(0xFF3B5998),
                                  labelStyle: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                  onPressed: _saving
                                      ? null
                                      : () => setState(
                                          () => _status = 'in_progress'),
                                ),
                              if (_status != 'assigned' &&
                                  allowedMaintenanceStatuses(report.status)
                                      .contains('assigned'))
                                ActionChip(
                                  avatar: const Icon(Icons.person_add,
                                      size: 16, color: Colors.white),
                                  label: const Text('Assign Staff'),
                                  backgroundColor: AppColors.info,
                                  labelStyle: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                  onPressed: _saving
                                      ? null
                                      : () =>
                                          setState(() => _status = 'assigned'),
                                ),
                              if (_status != 'resolved' &&
                                  allowedMaintenanceStatuses(report.status)
                                      .contains('resolved'))
                                ActionChip(
                                  avatar: const Icon(Icons.check,
                                      size: 16, color: Colors.white),
                                  label: const Text('Mark Resolved'),
                                  backgroundColor: AppColors.success,
                                  labelStyle: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                  onPressed: _saving
                                      ? null
                                      : () =>
                                          setState(() => _status = 'resolved'),
                                ),
                              if (_status != 'cancelled' &&
                                  allowedMaintenanceStatuses(report.status)
                                      .contains('cancelled'))
                                ActionChip(
                                  avatar: const Icon(Icons.cancel_outlined,
                                      size: 16, color: Colors.white),
                                  label: const Text('Cancel Request'),
                                  backgroundColor: AppColors.danger,
                                  labelStyle: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                  onPressed: _saving
                                      ? null
                                      : () =>
                                          setState(() => _status = 'cancelled'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          DropdownButtonFormField<String>(
                            initialValue: _status,
                            decoration: const InputDecoration(
                              labelText: 'Select Status',
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(),
                            ),
                            items: allowedMaintenanceStatuses(report.status)
                                .map((status) => DropdownMenuItem(
                                      value: status,
                                      child: Text(
                                        maintenanceStatusLabels[status] ??
                                            status,
                                      ),
                                    ))
                                .toList(),
                            onChanged: _saving
                                ? null
                                : (value) => setState(() => _status = value),
                          ),
                          const SizedBox(height: 16),

                          TextField(
                            controller: _notes,
                            enabled: !_saving,
                            maxLength: 2000,
                            minLines: 3,
                            maxLines: 6,
                            decoration: InputDecoration(
                              labelText: 'Staff & Resolution Notes',
                              hintText:
                                  'Record actions taken, technician assigned, parts replaced, or reason for cancellation...',
                              helperText: (_status == 'resolved' ||
                                      _status == 'cancelled')
                                  ? 'Notes are mandatory when marking as resolved or cancelled.'
                                  : 'Optional notes for staff records and tenant updates.',
                              helperStyle: TextStyle(
                                color: (_status == 'resolved' ||
                                        _status == 'cancelled')
                                    ? AppColors.danger
                                    : AppColors.taupe,
                                fontWeight: (_status == 'resolved' ||
                                        _status == 'cancelled')
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),

                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton.icon(
                              onPressed: _saving ? null : _save,
                              icon: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save),
                              label: Text(_saving
                                  ? 'Saving Changes…'
                                  : 'Update Maintenance Report'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.brown,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // History Timeline
                    CarmelitaCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.history,
                                  size: 18, color: AppColors.brown),
                              const SizedBox(width: 8),
                              Text(
                                'Audit Trail & History (${_history.length})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.darkBrown,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_history.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'No staff updates logged yet. Every status change and note will be recorded here.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.taupe,
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _history.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 16),
                              itemBuilder: (context, idx) {
                                final entry = _history[idx];
                                final prevLabel = maintenanceStatusLabels[
                                        entry['previous_status']] ??
                                    entry['previous_status'] ??
                                    'New';
                                final nextLabel = maintenanceStatusLabels[
                                        entry['next_status']] ??
                                    entry['next_status'] ??
                                    'Updated';
                                final actor = entry['actor_name'] ?? 'Staff';
                                final notes = (entry['notes'] as String?) ?? '';
                                final dt = DateTime.parse(
                                        entry['created_at'] as String)
                                    .toLocal();

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(top: 2),
                                      child: Icon(
                                        Icons.check_circle,
                                        size: 16,
                                        color: AppColors.brown,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.cream,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4),
                                                  ),
                                                  child: Text(
                                                    '$prevLabel → $nextLabel',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: AppColors.brown,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.taupe,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Updated by $actor',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.darkBrown,
                                            ),
                                          ),
                                          if (notes.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              notes,
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                                color: AppColors.charcoal,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
    );
  }
}
