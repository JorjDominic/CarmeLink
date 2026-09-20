import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/curfew_service.dart';
import '../services/gate_service.dart';
import '../services/guardian_service.dart';
import '../services/table_refresh_subscription.dart';

class GuardianController extends ChangeNotifier {
  GuardianController._();

  static final GuardianController instance = GuardianController._();

  final GuardianService _guardianService = const GuardianService();
  final CurfewService _curfewService = const CurfewService();
  final GateService _gateService = const GateService();

  final List<LinkedTenant> _linkedTenants = [];
  LinkedTenant? _selectedTenant;
  Room? _room;
  final List<Payment> _payments = [];
  final List<CurfewRequest> _curfewRequests = [];
  final List<GateEvent> _gateEvents = [];

  bool _gateLoading = false;
  String? _gateError;
  bool _gateLoadedOnce = false;
  String _linkedTenantPresence = 'Inside';

  bool _loading = false;
  String? _error;
  bool _loadedOnce = false;

  bool _curfewLoading = false;
  String? _curfewError;
  bool _curfewLoadedOnce = false;

  TableRefreshSubscription? _refreshSub;

  List<LinkedTenant> get linkedTenants => List.unmodifiable(_linkedTenants);
  LinkedTenant? get selectedTenant => _selectedTenant;
  bool get hasLinkedTenant => _selectedTenant != null;

  List<CurfewRequest> get curfewRequests => List.unmodifiable(_curfewRequests);
  bool get curfewLoading => _curfewLoading;
  String? get curfewError => _curfewError;
  bool get curfewLoadedOnce => _curfewLoadedOnce;
  int get pendingGuardianCurfewCount =>
      _curfewRequests.where((r) => r.isPendingGuardian).length;

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
    return _loading
        ? 'Checking room assignment...'
        : 'No active room assignment';
  }

  Room? get room => _room;
  List<Payment> get payments => List.unmodifiable(_payments);

  bool get loading => _loading;
  String? get error => _error;
  bool get loadedOnce => _loadedOnce;

  double get outstandingTotal => _payments
      .where(
          (payment) => payment.isDue || payment.isPending || payment.isRejected)
      .fold<double>(0, (sum, payment) => sum + payment.outstandingAmount);

  List<GateEvent> get gateEvents => List.unmodifiable(_gateEvents);
  List<GateEvent> get geofenceEvents => gateEvents;
  bool get gateLoading => _gateLoading;
  String? get gateError => _gateError;

  List<ChatMessage> get messages => const [];

  String get linkedTenantPresence => _linkedTenantPresence;

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

        await Future.wait([
          loadCurfewRequests(force: force),
          loadGateEvents(force: force),
        ]);
      } else {
        _selectedTenant = null;
        _room = null;
        _payments.clear();
        _curfewRequests.clear();
        _gateEvents.clear();
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

      await loadCurfewRequests(force: true);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Loads curfew exception requests for the linked tenant(s).
  Future<void> loadCurfewRequests({bool force = false}) async {
    if (_curfewLoading && !force) return;
    if (_curfewLoadedOnce && !force) return;

    _curfewLoading = true;
    _curfewError = null;
    notifyListeners();

    try {
      final list = await _curfewService.listGuardianRequests(
        tenantId: _selectedTenant?.tenantId,
      );
      _curfewRequests
        ..clear()
        ..addAll(list);
      _curfewLoadedOnce = true;
    } catch (e) {
      _curfewError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _curfewLoading = false;
      notifyListeners();
    }
  }

  /// Submits guardian endorsement or rejection on an overnight leave request.
  Future<CurfewRequest> decideCurfewRequest({
    required String requestId,
    required bool approve,
    String? remarks,
  }) async {
    final updated = await _curfewService.decideGuardianRequest(
      requestId: requestId,
      approve: approve,
      remarks: remarks,
    );

    final index = _curfewRequests.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      _curfewRequests[index] = updated;
    } else {
      _curfewRequests.insert(0, updated);
    }
    notifyListeners();
    return updated;
  }

  void _initRealtimeSubscription() {
    if (_refreshSub != null) return;
    _refreshSub = TableRefreshSubscription(
      'guardian-data-sync',
      [
        'guardian_tenant_links',
        'tenant_assignments',
        'payments',
        'curfew_requests',
        'gate_events',
      ],
      () {
        loadData(force: true);
        loadCurfewRequests(force: true);
        loadGateEvents(force: true);
      },
    );
  }

  Future<void> loadGateEvents({bool force = false}) async {
    final tenantId = _selectedTenant?.tenantId;
    if (tenantId == null) return;
    if (_gateLoading && !force) return;
    if (_gateLoadedOnce && !force) return;

    _gateLoading = true;
    _gateError = null;
    notifyListeners();

    try {
      final events = await _gateService.loadGateEvents(
        tenantId: tenantId,
        forceRefresh: force,
      );
      _gateEvents
        ..clear()
        ..addAll(events);
      _gateLoadedOnce = true;

      if (events.isNotEmpty) {
        final latest = events.first;
        if (latest.isUnavailable) {
          _linkedTenantPresence = 'Unavailable';
        } else if (latest.direction == 'IN') {
          _linkedTenantPresence = 'Inside';
        } else if (latest.direction == 'OUT') {
          _linkedTenantPresence = 'Outside';
        }
      }
    } catch (e) {
      _gateError = e.toString();
    } finally {
      _gateLoading = false;
      notifyListeners();
    }
  }

  @visibleForTesting
  void setGateEventsForTesting(List<GateEvent> events) {
    _gateEvents
      ..clear()
      ..addAll(events);
    _gateLoadedOnce = true;
    _gateLoading = false;
    _gateError = null;
    if (events.isNotEmpty) {
      final latest = events.first;
      if (latest.isUnavailable) {
        _linkedTenantPresence = 'Unavailable';
      } else if (latest.direction == 'IN') {
        _linkedTenantPresence = 'Inside';
      } else if (latest.direction == 'OUT') {
        _linkedTenantPresence = 'Outside';
      }
    }
    notifyListeners();
  }

  @visibleForTesting
  void setLinkedTenantPresenceForTesting(String status) {
    _linkedTenantPresence = status;
    notifyListeners();
  }

  /// Resets state on sign-out.
  void clear() {
    _refreshSub?.dispose();
    _refreshSub = null;
    _linkedTenants.clear();
    _selectedTenant = null;
    _room = null;
    _payments.clear();
    _curfewRequests.clear();
    _gateEvents.clear();
    _loading = false;
    _error = null;
    _loadedOnce = false;
    _curfewLoading = false;
    _curfewError = null;
    _curfewLoadedOnce = false;
    _gateLoading = false;
    _gateError = null;
    _gateLoadedOnce = false;
    _linkedTenantPresence = 'Inside';
    GuardianService.invalidateCache();
    notifyListeners();
  }
}
