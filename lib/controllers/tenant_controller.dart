import 'package:flutter/foundation.dart';

import '../core/config/supabase_config.dart';
import '../models/models.dart';
import '../services/curfew_service.dart';
import '../services/confidential_report_service.dart';
import '../services/gate_service.dart';
import '../services/geofence_service.dart';
import '../services/maintenance_service.dart';
import '../services/payment_service.dart';
import '../services/room_service.dart';
import '../services/visitor_service.dart';

class TenantController extends ChangeNotifier {
  TenantController._();

  static final TenantController instance = TenantController._();

  final CurfewService _curfewService = const CurfewService();
  final ConfidentialReportService _confidentialReportService =
      const ConfidentialReportService();
  final MaintenanceService _maintenanceService = const MaintenanceService();
  final PaymentService _paymentService = const PaymentService();
  final RoomService _roomService = const RoomService();
  final GateService _gateService = const GateService();
  final GeofenceLocationService _geofenceService =
      const GeofenceLocationService();
  final VisitorService _visitorService = const VisitorService();

  final List<MaintenanceReport> _maintenance = [];
  final List<Payment> _payments = [];
  final List<CurfewRequest> _curfewRequests = [];
  final List<ConcernReport> _concerns = [];
  final List<VisitorRequest> _visitors = [];
  List<GateEvent> _gateEvents = [];
  Room? _room;

  bool _gateLoading = false;
  String? _gateError;
  bool _gateLoadedOnce = false;

  String _currentGateStatus = 'IN';
  DateTime? _lastGateEventAt;
  bool _checkingPresence = false;

  bool _maintenanceLoading = false;
  String? _maintenanceError;
  bool _maintenanceLoadedOnce = false;

  bool _paymentsLoading = false;
  String? _paymentsError;
  bool _paymentsLoadedOnce = false;

  bool _curfewLoading = false;
  String? _curfewError;
  bool _curfewLoadedOnce = false;

  bool _concernsLoading = false;
  String? _concernsError;
  bool _concernsLoadedOnce = false;

  bool _roomLoading = false;
  String? _roomError;
  bool _roomLoadedOnce = false;

  bool _visitorsLoading = false;
  String? _visitorsError;
  bool _visitorsLoadedOnce = false;

  Room? get room => _room;
  bool get roomLoading => _roomLoading;
  String? get roomError => _roomError;
  bool get roomLoadedOnce => _roomLoadedOnce;
  bool get isRoomAssigned => _room != null;

  List<Payment> get payments => List.unmodifiable(_payments);

  bool get paymentsLoading => _paymentsLoading;
  String? get paymentsError => _paymentsError;
  bool get paymentsLoadedOnce => _paymentsLoadedOnce;

  double get outstandingBalance {
    final list = payments;
    return list
        .where((p) => !p.isVerified)
        .fold<double>(0.0, (sum, p) => sum + p.amount);
  }

  Payment? get nextDuePayment {
    final due = payments.where((p) => p.isDue).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return due.isNotEmpty ? due.first : null;
  }

  List<Payment> get duePayments => payments.where((p) => p.isDue).toList();
  List<Payment> get pendingPayments =>
      payments.where((p) => p.isPending).toList();
  List<Payment> get verifiedPayments =>
      payments.where((p) => p.isVerified).toList();
  List<Payment> get overduePayments =>
      payments.where((p) => p.isOverdue).toList();

  List<MaintenanceReport> get maintenance => List.unmodifiable(_maintenance);

  List<CurfewRequest> get curfewRequests => List.unmodifiable(_curfewRequests);
  bool get curfewLoading => _curfewLoading;
  String? get curfewError => _curfewError;
  bool get curfewLoadedOnce => _curfewLoadedOnce;

  CurfewRequest? get activeCurfewRequest {
    final active =
        _curfewRequests.where((r) => r.isPending || r.isApproved).toList();
    return active.isNotEmpty ? active.first : null;
  }

  List<GateEvent> get gateEvents => List.unmodifiable(_gateEvents);

  List<GateEvent> get geofenceEvents => gateEvents;
  bool get gateLoading => _gateLoading;
  String? get gateError => _gateError;
  bool get gateLoadedOnce => _gateLoadedOnce;

  String get currentGateStatus => _currentGateStatus;
  DateTime? get lastGateEventAt => _lastGateEventAt;
  bool get checkingPresence => _checkingPresence;

  bool get isInside =>
      _currentGateStatus == 'IN' || _currentGateStatus == 'Inside';
  bool get isOutside =>
      _currentGateStatus == 'OUT' || _currentGateStatus == 'Outside';
  bool get isUnavailable =>
      _currentGateStatus == 'UNAVAILABLE' ||
      _currentGateStatus == 'Unavailable';

  List<Announcement> get announcements => const [];

  List<VisitorRequest> get visitors => List.unmodifiable(_visitors);
  bool get visitorsLoading => _visitorsLoading;
  String? get visitorsError => _visitorsError;
  bool get visitorsLoadedOnce => _visitorsLoadedOnce;

  List<ConcernReport> get concerns => List.unmodifiable(_concerns);
  bool get concernsLoading => _concernsLoading;
  String? get concernsError => _concernsError;
  bool get concernsLoadedOnce => _concernsLoadedOnce;

  List<ChatMessage> get messages => const [];

  bool get maintenanceLoading => _maintenanceLoading;

  String? get maintenanceError => _maintenanceError;

  bool get maintenanceLoadedOnce => _maintenanceLoadedOnce;

  Future<void> loadConcerns({bool force = false}) async {
    if (_concernsLoading || (_concernsLoadedOnce && !force)) return;
    _concernsLoading = true;
    _concernsError = null;
    notifyListeners();
    try {
      final reports = await _confidentialReportService.listOwnReports();
      _concerns
        ..clear()
        ..addAll(reports);
      _concernsLoadedOnce = true;
    } catch (error) {
      _concernsError = _message(error);
    } finally {
      _concernsLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadCurfewRequests({bool force = false}) async {
    if (_curfewLoading && !force) return;
    if (_curfewLoadedOnce && !force) return;

    _curfewLoading = true;
    _curfewError = null;
    notifyListeners();

    try {
      final list = await _curfewService.listOwnRequests();
      _curfewRequests
        ..clear()
        ..addAll(list);
      _curfewLoadedOnce = true;
    } catch (e) {
      _curfewError = _message(e);
    } finally {
      _curfewLoading = false;
      notifyListeners();
    }
  }

  Future<CurfewRequest> submitCurfewRequest({
    required String destination,
    required String reason,
    required DateTime departureTime,
    required DateTime expectedReturnTime,
    String requestType = 'late_return',
  }) async {
    final created = await _curfewService.submitRequest(
      destination: destination,
      reason: reason,
      departureTime: departureTime,
      expectedReturnTime: expectedReturnTime,
      requestType: requestType,
    );

    _curfewRequests.insert(0, created);
    _curfewError = null;
    notifyListeners();
    return created;
  }

  Future<void> cancelCurfewRequest(String requestId) async {
    try {
      final updated = await _curfewService.cancelRequest(requestId);
      final index = _curfewRequests.indexWhere((r) => r.id == requestId);
      if (index != -1) {
        _curfewRequests[index] = updated;
      }
      notifyListeners();
    } catch (_) {
      final index = _curfewRequests.indexWhere((r) => r.id == requestId);
      if (index != -1) {
        _curfewRequests[index].status = 'cancelled';
        notifyListeners();
      }
    }
  }

  Future<void> loadMaintenance({bool force = false}) async {
    if (_maintenanceLoading && !force) {
      return;
    }
    if (_maintenanceLoadedOnce && !force) {
      return;
    }

    _maintenanceLoading = true;
    _maintenanceError = null;
    notifyListeners();

    try {
      final reports = await _maintenanceService.listOwnReports();

      _maintenance
        ..clear()
        ..addAll(reports);
      _maintenanceLoadedOnce = true;
    } catch (error) {
      _maintenanceError = _message(error);
    } finally {
      _maintenanceLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _room = null;
    _roomLoadedOnce = false;
    _roomLoading = false;
    _roomError = null;
    _maintenance.clear();
    _maintenanceLoading = false;
    _maintenanceError = null;
    _maintenanceLoadedOnce = false;
    _payments.clear();
    _paymentsLoading = false;
    _paymentsError = null;
    _paymentsLoadedOnce = false;
    _curfewRequests.clear();
    _curfewLoading = false;
    _curfewError = null;
    _curfewLoadedOnce = false;
    _concerns.clear();
    _concernsLoading = false;
    _concernsError = null;
    _concernsLoadedOnce = false;
    _visitors.clear();
    _visitorsLoading = false;
    _visitorsError = null;
    _visitorsLoadedOnce = false;
    _gateEvents.clear();
    _gateLoading = false;
    _gateError = null;
    _gateLoadedOnce = false;
    _currentGateStatus = 'IN';
    _lastGateEventAt = null;
    _checkingPresence = false;
    notifyListeners();
  }

  Future<void> loadMyRoom({bool force = false}) async {
    if (_roomLoading && !force) {
      return;
    }
    if (_room != null && _roomLoadedOnce && !force) {
      return;
    }

    _roomLoading = true;
    _roomError = null;
    notifyListeners();

    try {
      _room = await _roomService.getMyRoomDetails();
      _roomLoadedOnce = true;
    } catch (error) {
      _roomError = _message(error);
    } finally {
      _roomLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadPayments({bool force = false}) async {
    if (_paymentsLoading && !force) return;
    if (_paymentsLoadedOnce && !force) return;
    _paymentsLoading = true;
    _paymentsError = null;
    notifyListeners();

    try {
      final latest = await _paymentService.listOwnPayments();
      _payments
        ..clear()
        ..addAll(latest);
      _paymentsLoadedOnce = true;
    } catch (e) {
      _paymentsError = _message(e);
    } finally {
      _paymentsLoading = false;
      notifyListeners();
    }
  }

  @visibleForTesting
  void setPaymentsForTesting(List<Payment> items) {
    _payments
      ..clear()
      ..addAll(items);
    _paymentsLoadedOnce = true;
    _paymentsLoading = false;
    _paymentsError = null;
    notifyListeners();
  }

  Future<Payment> submitPaymentProof({
    String? paymentId,
    required double amount,
    required String method,
    required String reference,
    Uint8List? receiptBytes,
    String? fileName,
    String? mimeType,
  }) async {
    final targetId = paymentId ??
        (payments.isNotEmpty
            ? payments.first.id
            : 'p${DateTime.now().millisecondsSinceEpoch}');

    try {
      final updated = await _paymentService.submitPaymentProof(
        paymentId: targetId,
        method: method,
        referenceNumber: reference,
        receiptBytes: receiptBytes,
        fileName: fileName,
        mimeType: mimeType,
      );

      final index = _payments.indexWhere((p) => p.id == targetId);
      if (index != -1) {
        _payments[index] = updated;
      } else {
        _payments.insert(0, updated);
      }
      notifyListeners();
      return updated;
    } catch (error) {
      _paymentsError = _message(error);
      notifyListeners();
      rethrow;
    }
  }

  Future<String?> paymentReceiptUrl(String? path) =>
      _paymentService.createReceiptUrl(path);

  Future<void> submitMaintenance({
    required String category,
    required String description,
    required String location,
    required String urgency,
    Uint8List? photoBytes,
    String? photoFileName,
    String? photoMimeType,
  }) async {
    final report = await _maintenanceService.createReport(
      category: category,
      description: description,
      location: location,
      urgency: urgency,
      photoBytes: photoBytes,
      photoFileName: photoFileName,
      photoMimeType: photoMimeType,
    );

    _maintenance.insert(0, report);
    _maintenanceError = null;
    notifyListeners();
  }

  Future<void> updateMaintenance({
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
    final updated = await _maintenanceService.updateReport(
      id: id,
      category: category,
      description: description,
      location: location,
      urgency: urgency,
      photoBytes: photoBytes,
      photoFileName: photoFileName,
      photoMimeType: photoMimeType,
      removePhoto: removePhoto,
    );

    final index = _maintenance.indexWhere(
      (report) => report.id == id,
    );

    if (index != -1) {
      _maintenance[index] = updated;
    }

    _maintenanceError = null;
    notifyListeners();
  }

  Future<void> deleteMaintenance(
    String id,
  ) async {
    await _maintenanceService.deleteReport(id);

    _maintenance.removeWhere(
      (report) => report.id == id,
    );

    _maintenanceError = null;
    notifyListeners();
  }

  Future<void> cancelMaintenance(String id) => deleteMaintenance(id);

  Future<String?> maintenancePhotoUrl(
    String? photoPath,
  ) {
    return _maintenanceService.createPhotoUrl(photoPath);
  }

  @visibleForTesting
  void setMaintenanceForTesting(List<MaintenanceReport> list) {
    _maintenance
      ..clear()
      ..addAll(list);
    _maintenanceLoadedOnce = true;
    _maintenanceLoading = false;
    _maintenanceError = null;
    notifyListeners();
  }

  Future<void> loadVisitors({bool force = false}) async {
    if (_visitorsLoading || (_visitorsLoadedOnce && !force)) return;
    _visitorsLoading = true;
    _visitorsError = null;
    notifyListeners();
    try {
      final items = await _visitorService.listOwnRequests();
      _visitors
        ..clear()
        ..addAll(items);
      _visitorsLoadedOnce = true;
    } catch (error) {
      _visitorsError = _message(error);
    } finally {
      _visitorsLoading = false;
      notifyListeners();
    }
  }

  Future<VisitorRequest> submitVisitor({
    required String visitorName,
    required String relationship,
    required String purpose,
    required String contactNumber,
    required DateTime schedule,
    required DateTime expectedDepartureAt,
  }) async {
    final request = await _visitorService.submit(
      visitorName: visitorName,
      relationship: relationship,
      purpose: purpose,
      contactNumber: contactNumber,
      schedule: schedule,
      expectedDepartureAt: expectedDepartureAt,
    );
    _visitors.insert(0, request);
    _visitorsLoadedOnce = true;
    _visitorsError = null;
    notifyListeners();
    return request;
  }

  Future<VisitorRequest> updateVisitor({
    required VisitorRequest request,
    required String visitorName,
    required String relationship,
    required String purpose,
    required String contactNumber,
    required DateTime schedule,
    required DateTime expectedDepartureAt,
  }) async {
    final updated = await _visitorService.updatePending(
      requestId: request.id,
      visitorName: visitorName,
      relationship: relationship,
      purpose: purpose,
      contactNumber: contactNumber,
      schedule: schedule,
      expectedDepartureAt: expectedDepartureAt,
    );
    _replaceVisitor(updated);
    return updated;
  }

  Future<void> cancelVisitor(VisitorRequest request) async {
    final updated = await _visitorService.transition(
      requestId: request.id,
      action: 'cancel',
    );
    _replaceVisitor(updated);
  }

  Future<List<VisitorEvent>> loadVisitorEvents(String requestId) =>
      _visitorService.listEvents(requestId);

  void _replaceVisitor(VisitorRequest updated) {
    final index = _visitors.indexWhere((item) => item.id == updated.id);
    if (index == -1) {
      _visitors.insert(0, updated);
    } else {
      _visitors[index] = updated;
    }
    _visitorsError = null;
    notifyListeners();
  }

  @visibleForTesting
  void setVisitorsForTesting(List<VisitorRequest> items) {
    _visitors
      ..clear()
      ..addAll(items);
    _visitorsLoadedOnce = true;
    _visitorsLoading = false;
    _visitorsError = null;
    notifyListeners();
  }

  Future<ConcernReport> submitConcern({
    required String category,
    required String summary,
  }) async {
    final report = await _confidentialReportService.submit(
      category: category,
      summary: summary,
    );
    _concerns.insert(0, report);
    _concernsLoadedOnce = true;
    _concernsError = null;
    notifyListeners();
    return report;
  }

  String _message(Object error) {
    return error
        .toString()
        .replaceFirst(
          'Exception: ',
          '',
        )
        .replaceFirst(
          'AuthException(message: ',
          '',
        )
        .replaceFirst(
          RegExp(r', statusCode:.*$'),
          '',
        )
        .replaceAll(')', '');
  }

  Future<void> loadGateEvents({bool force = false}) async {
    if (_gateLoading && !force) return;
    if (_gateLoadedOnce && !force) return;

    _gateLoading = true;
    _gateError = null;
    notifyListeners();

    try {
      final client = SupabaseConfig.clientSafe;
      final uid = client?.auth.currentUser?.id;
      if (client == null || uid == null) {
        _gateEvents = [];
        _gateLoadedOnce = true;
        return;
      }
      final events = await _gateService.loadGateEvents(
        tenantId: uid,
        forceRefresh: force,
      );
      _gateEvents = events;
      _gateLoadedOnce = true;
      if (events.isNotEmpty) {
        final latest = events.first;
        _currentGateStatus =
            latest.isUnavailable ? 'UNAVAILABLE' : (latest.direction ?? 'IN');
        _lastGateEventAt = latest.checkedAt;
      } else {
        try {
          final row = await client
              .from('tenant_details')
              .select('current_gate_status, last_gate_event_at')
              .eq('profile_id', uid)
              .maybeSingle();
          if (row != null) {
            if (row['current_gate_status'] != null) {
              _currentGateStatus = row['current_gate_status'] as String;
            }
            if (row['last_gate_event_at'] != null) {
              _lastGateEventAt =
                  DateTime.parse(row['last_gate_event_at'] as String);
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      _gateError = _message(e);
    } finally {
      _gateLoading = false;
      notifyListeners();
    }
  }

  /// On-demand or scheduled GPS geofence check-in.
  ///
  /// Zero coordinates are persisted; evaluates on-device and passes only
  /// the resulting status/direction to the secure RPC.
  Future<GeofenceCheckResult> performGeofenceCheckIn({
    String checkpointType = 'on_demand',
  }) async {
    _checkingPresence = true;
    notifyListeners();

    try {
      final previous =
          _currentGateStatus == 'UNAVAILABLE' ? null : _currentGateStatus;
      final result = await _geofenceService.checkCurrentPresence(
        previousDirection: previous,
      );

      _currentGateStatus =
          result.isUnavailable ? 'UNAVAILABLE' : (result.direction ?? 'IN');
      _lastGateEventAt = DateTime.now();

      final client = SupabaseConfig.clientSafe;
      final uid = client?.auth.currentUser?.id;

      try {
        await _gateService.recordGeofenceCheckIn(
          direction: result.direction,
          status: result.status,
          checkpointType: checkpointType,
        );
      } catch (dbError) {
        _gateError = _message(dbError);
        final localEvent = GateEvent(
          id: 'ge_${DateTime.now().millisecondsSinceEpoch}',
          person: 'Me',
          tenantId: uid,
          direction: result.direction,
          time: _lastGateEventAt ?? DateTime.now(),
          verification: 'GPS Geofence',
          status: result.status,
          checkpointType: checkpointType,
        );
        _gateEvents.insert(0, localEvent);
        return GeofenceCheckResult(
          direction: result.direction,
          status: result.status,
          failureReason: result.failureReason,
          errorMessage: result.errorMessage ??
              'Database sync error: ${_message(dbError)}',
        );
      }

      await loadGateEvents(force: true);
      return result;
    } catch (e) {
      _gateError = _message(e);
      return GeofenceCheckResult(
        direction: null,
        status: 'UNAVAILABLE',
        failureReason: GeofenceFailureReason.timeoutOrSignalError,
        errorMessage: _message(e),
      );
    } finally {
      _checkingPresence = false;
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
      _currentGateStatus =
          latest.isUnavailable ? 'UNAVAILABLE' : (latest.direction ?? 'IN');
      _lastGateEventAt = latest.checkedAt;
    }
    notifyListeners();
  }

  @visibleForTesting
  void setCurrentGateStatusForTesting(String status) {
    _currentGateStatus = status;
    notifyListeners();
  }
}
