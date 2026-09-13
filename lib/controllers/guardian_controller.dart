import 'package:flutter/foundation.dart';

import '../data/mock_data.dart';
import '../models/models.dart';
import '../services/guardian_service.dart';
import '../services/table_refresh_subscription.dart';

class GuardianController extends ChangeNotifier {
  GuardianController._();

  static final GuardianController instance = GuardianController._();

  final GuardianService _guardianService = const GuardianService();

  final List<LinkedTenant> _linkedTenants = [];
  LinkedTenant? _selectedTenant;
  Room? _room;
  final List<Payment> _payments = [];

  bool _loading = false;
  String? _error;
  bool _loadedOnce = false;
  TableRefreshSubscription? _refreshSub;

  List<LinkedTenant> get linkedTenants => List.unmodifiable(_linkedTenants);
  LinkedTenant? get selectedTenant => _selectedTenant;
  bool get hasLinkedTenant => _selectedTenant != null;

  String get linkedTenantName {
    if (_selectedTenant != null) {
      return _selectedTenant!.name;
    }
    return _loadedOnce ? 'No linked resident' : 'Loading resident...';
  }

  String get linkedTenantRoomSubtitle {
    if (_room != null) {
      return 'Room ${_room!.number} • ${_room!.bedSpace} • Floor ${_room!.floor}';
    }
    return _loading ? 'Checking room assignment...' : 'No active room assignment';
  }

  Room? get room => _room;
  List<Payment> get payments => List.unmodifiable(_payments);

  bool get loading => _loading;
  String? get error => _error;
  bool get loadedOnce => _loadedOnce;

  double get outstandingTotal => _payments
      .where((payment) => !payment.isVerified)
      .fold<double>(0, (sum, payment) => sum + payment.amount);

  List<GeofenceEvent> get geofenceEvents =>
      List.unmodifiable(MockData.gateEvents);
  List<GeofenceEvent> get gateEvents => geofenceEvents;

  List<ChatMessage> get messages =>
      List.unmodifiable(MockData.guardianMessages);

  String get linkedTenantPresence => 'Inside';

  /// Loads linked tenants, room assignment, and payment records.
  Future<void> loadData({bool force = false}) async {
    if (_loading && !force) return;
    if (_loadedOnce && !force && _selectedTenant != null) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final tenants = await _guardianService.loadLinkedTenants(
        forceRefresh: force,
      );

      _linkedTenants
        ..clear()
        ..addAll(tenants);

      if (_linkedTenants.isNotEmpty) {
        // Keep current selection if still valid, otherwise pick primary or first
        final currentId = _selectedTenant?.tenantId;
        final matching = _linkedTenants.where((t) => t.tenantId == currentId);

        _selectedTenant = matching.isNotEmpty
            ? matching.first
            : _linkedTenants.firstWhere(
                (t) => t.isPrimary,
                orElse: () => _linkedTenants.first,
              );

        // Fetch room & payments concurrently for the selected tenant
        final results = await Future.wait([
          _guardianService.loadTenantRoom(_selectedTenant!.tenantId),
          _guardianService.loadTenantPayments(_selectedTenant!.tenantId),
        ]);

        _room = results[0] as Room?;
        _payments
          ..clear()
          ..addAll(results[1] as List<Payment>);
      } else {
        _selectedTenant = null;
        _room = null;
        _payments.clear();
      }

      _initRealtimeSubscription();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _loading = false;
      _loadedOnce = true;
      notifyListeners();
    }
  }

  /// Switches active linked tenant if the guardian is linked to multiple residents.
  Future<void> selectTenant(LinkedTenant tenant) async {
    if (_selectedTenant?.tenantId == tenant.tenantId) return;

    _selectedTenant = tenant;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _guardianService.loadTenantRoom(tenant.tenantId),
        _guardianService.loadTenantPayments(tenant.tenantId),
      ]);

      _room = results[0] as Room?;
      _payments
        ..clear()
        ..addAll(results[1] as List<Payment>);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void _initRealtimeSubscription() {
    if (_refreshSub != null) return;
    _refreshSub = TableRefreshSubscription(
      'guardian-data-sync',
      ['guardian_tenant_links', 'tenant_assignments', 'payments'],
      () => loadData(force: true),
    );
  }

  /// Resets state on sign-out.
  void clear() {
    _refreshSub?.dispose();
    _refreshSub = null;
    _linkedTenants.clear();
    _selectedTenant = null;
    _room = null;
    _payments.clear();
    _loading = false;
    _error = null;
    _loadedOnce = false;
    GuardianService.invalidateCache();
    notifyListeners();
  }

  void sendMessage(String body) {
    final clean = body.trim();
    if (clean.isEmpty) return;

    MockData.guardianMessages.add(
      ChatMessage(
        id: 'gm${DateTime.now().millisecondsSinceEpoch}',
        senderName: 'Guardian',
        senderRole: 'guardian',
        body: clean,
        sentAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }
}
