import 'package:flutter/foundation.dart';

import '../data/mock_data.dart';
import '../models/models.dart';
import '../services/curfew_service.dart';
import '../services/confidential_report_service.dart';
import '../services/gate_service.dart';
import '../services/payment_service.dart';
import '../services/room_service.dart';
import '../services/staff_maintenance_service.dart';
import '../services/tenant_service.dart';

class OwnerController extends ChangeNotifier {
  OwnerController._();

  static final OwnerController instance = OwnerController._();

  final CurfewService _curfewService = const CurfewService();
  final ConfidentialReportService _confidentialReportService =
      const ConfidentialReportService();
  final List<ConcernReport> _concerns = [];
  bool _concernsLoading = false;
  String? _concernsError;
  bool _concernsLoadedOnce = false;
  final List<CurfewRequest> _curfewRequests = [];
  bool _curfewLoading = false;
  String? _curfewError;
  bool _curfewLoadedOnce = false;

  final PaymentService _paymentService = const PaymentService();
  final List<Payment> _payments = [];
  bool _paymentsLoading = false;
  String? _paymentsError;
  bool _paymentsLoadedOnce = false;

  final RoomService _roomService = const RoomService();
  final List<RoomRecord> _roomRecords = [];
  bool _roomsLoading = false;
  String? _roomsError;

  final StaffMaintenanceService _staffMaintenanceService =
      const StaffMaintenanceService();
  final List<StaffMaintenanceReport> _staffMaintenanceReports = [];
  bool _maintenanceLoading = false;
  String? _maintenanceError;
  bool _maintenanceLoadedOnce = false;

  final GateService _gateService = const GateService();
  final TenantService _tenantService = const TenantService();
  List<GateEvent> _gateEvents = [];
  bool _gateLoading = false;
  String? _gateError;
  bool _gateLoadedOnce = false;

  List<TenantDirectoryEntry> _tenants = [];
  bool _tenantsLoading = false;
  bool _tenantsLoadedOnce = false;

  List<CurfewRequest> get curfewRequests => List.unmodifiable(_curfewRequests);
  bool get curfewLoading => _curfewLoading;
  String? get curfewError => _curfewError;
  bool get curfewLoadedOnce => _curfewLoadedOnce;

  int get pendingStaffCurfewCount =>
      _curfewRequests.where((r) => r.status == 'pending_staff').length;

  int get pendingTotalCurfewCount =>
      _curfewRequests.where((r) => r.isPending).length;

  List<StaffMaintenanceReport> get staffMaintenanceReports =>
      List.unmodifiable(_staffMaintenanceReports);
  bool get maintenanceLoading => _maintenanceLoading;
  String? get maintenanceError => _maintenanceError;
  bool get maintenanceLoadedOnce => _maintenanceLoadedOnce;

  int get highPriorityMaintenance =>
      _staffMaintenanceReports.where((r) => r.isOpen && r.isHighUrgency).length;

  int get inProgressMaintenanceCount =>
      _staffMaintenanceReports.where((r) => r.isInProgress).length;

  int get resolvedMaintenanceCount =>
      _staffMaintenanceReports.where((r) => r.isResolved).length;

  List<TenantDirectoryEntry> get tenants => List.unmodifiable(_tenants);
  bool get tenantsLoading => _tenantsLoading;

  List<DormRoomStatus> get rooms {
    if (_roomRecords.isEmpty) {
      return List.unmodifiable(MockData.roomStatuses);
    }
    return _roomRecords.map((r) {
      final status = r.occupied >= r.capacity
          ? 'Full'
          : (r.occupied > 0 ? 'Partially occupied' : 'Available');
      return DormRoomStatus(
        roomNumber: r.number,
        floor: r.floor,
        capacity: r.capacity,
        occupied: r.occupied,
        status: status,
      );
    }).toList();
  }

  List<RoomRecord> get roomRecords => List.unmodifiable(_roomRecords);
  bool get roomsLoading => _roomsLoading;
  String? get roomsError => _roomsError;
  List<MaintenanceReport> get maintenance {
    if (_staffMaintenanceReports.isNotEmpty) {
      return _staffMaintenanceReports
          .map((s) => MaintenanceReport(
                id: s.id,
                category: s.category,
                description: s.description,
                location: s.location,
                urgency: s.urgency.isNotEmpty
                    ? '${s.urgency[0].toUpperCase()}${s.urgency.substring(1).toLowerCase()}'
                    : s.urgency,
                status: s.statusLabel,
                createdAt: s.createdAt,
                photoPath: s.photoPath,
                notes: s.notes,
                staffNotes: s.notes,
                resolvedAt: s.resolvedAt,
              ))
          .toList();
    }
    return List.unmodifiable(MockData.maintenance);
  }

  List<MaintenanceReport> get maintenanceByPriority {
    final list = [...maintenance];
    const rank = {'High': 3, 'Medium': 2, 'Low': 1};
    return list
      ..sort((a, b) => (rank[b.urgency] ?? 0).compareTo(rank[a.urgency] ?? 0));
  }

  List<GateEvent> get gateEvents => List.unmodifiable(_gateEvents);
  List<GateEvent> get geofenceEvents => gateEvents;
  bool get gateLoading => _gateLoading;
  String? get gateError => _gateError;
  List<VisitorRequest> get visitors => List.unmodifiable(MockData.visitors);
  List<ConcernReport> get concerns => List.unmodifiable(_concerns);
  bool get concernsLoading => _concernsLoading;
  String? get concernsError => _concernsError;
  List<Announcement> get announcements =>
      List.unmodifiable(MockData.announcements);
  List<OwnerConversation> get conversations =>
      List.unmodifiable(MockData.ownerConversations);

  int get occupiedBeds =>
      rooms.fold<int>(0, (sum, room) => sum + room.occupied);

  int get totalCapacity =>
      rooms.fold<int>(0, (sum, room) => sum + room.capacity);

  int get pendingPaymentProofs =>
      payments.where((payment) => payment.isPending).length;

  int get overduePaymentCount =>
      payments.where((payment) => payment.isOverdue).length;

  double get totalCollectedRevenue => payments
      .where((payment) => payment.isVerified)
      .fold<double>(0.0, (sum, p) => sum + p.amount);

  double get totalOutstandingRevenue => payments
      .where((payment) => payment.isDue || payment.isPending)
      .fold<double>(0.0, (sum, p) => sum + p.amount);

  int get openMaintenance => _maintenanceLoadedOnce
      ? _staffMaintenanceReports.where((report) => report.isOpen).length
      : maintenance
          .where(
            (report) =>
                report.status != 'Completed' &&
                report.status != 'Closed' &&
                report.status != 'Resolved' &&
                report.status != 'Cancelled',
          )
          .length;

  int get pendingVisitors =>
      visitors.where((visitor) => visitor.status == 'Pending').length;

  int get tenantsInsideCount => tenants.where((t) => t.isInside).length;

  int get tenantsOutsideCount => tenants.where((t) => t.isOutside).length;

  int get tenantsUnavailableCount =>
      tenants.where((t) => t.isUnavailable).length;

  List<Payment> get payments => _payments.isEmpty
      ? List.unmodifiable(MockData.payments)
      : List.unmodifiable(_payments);
  bool get paymentsLoading => _paymentsLoading;
  String? get paymentsError => _paymentsError;
  bool get paymentsLoadedOnce => _paymentsLoadedOnce;

  Future<void> loadPayments({bool force = false}) async {
    if (_paymentsLoading && !force) return;
    if (_paymentsLoadedOnce && !force) return;

    _paymentsLoading = true;
    _paymentsError = null;
    notifyListeners();

    try {
      final list = await _paymentService.listAllPayments();
      _payments
        ..clear()
        ..addAll(list);
      _paymentsLoadedOnce = true;
    } catch (e) {
      _paymentsError = e.toString();
    } finally {
      _paymentsLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadRooms({bool force = false}) async {
    if (_roomsLoading) return;
    if (_roomRecords.isNotEmpty && !force) return;

    _roomsLoading = true;
    _roomsError = null;
    notifyListeners();

    try {
      final list = await _roomService.listRooms(forceRefresh: force);
      _roomRecords
        ..clear()
        ..addAll(list);
    } catch (e) {
      _roomsError = e.toString();
    } finally {
      _roomsLoading = false;
      notifyListeners();
    }
  }

  Future<void> verifyPayment(Payment payment, bool approve,
      {String? notes}) async {
    try {
      final updated = await _paymentService.verifyPayment(
        paymentId: payment.id,
        approve: approve,
        reviewNotes: notes,
      );

      final index = _payments.indexWhere((p) => p.id == payment.id);
      if (index != -1) {
        _payments[index] = updated;
      }
      payment.status = updated.status;
    } catch (_) {
      // Local fallback
      payment.status = approve ? 'Verified' : 'Rejected';
    }
    notifyListeners();
  }

  Future<Payment> createInvoice({
    required String tenantId,
    required String title,
    required String category,
    required double amount,
    required DateTime dueDate,
  }) async {
    final invoice = await _paymentService.createInvoice(
      tenantId: tenantId,
      title: title,
      category: category,
      amount: amount,
      dueDate: dueDate,
    );

    final index = _payments.indexWhere((p) => p.id == invoice.id);
    if (index != -1) {
      _payments[index] = invoice;
    } else {
      _payments.insert(0, invoice);
    }
    notifyListeners();
    return invoice;
  }

  void updateMaintenance(
    MaintenanceReport report,
    String status, {
    String? notes,
  }) {
    report.status = status;
    if (notes != null && notes.trim().isNotEmpty) {
      report.notes = notes.trim();
    }
    notifyListeners();
  }

  void decideVisitor(VisitorRequest request, bool approve) {
    request.status = approve ? 'Approved' : 'Rejected';
    notifyListeners();
  }

  Future<void> loadConcerns({bool force = false}) async {
    if (_concernsLoading || (_concernsLoadedOnce && !force)) return;
    _concernsLoading = true;
    _concernsError = null;
    notifyListeners();
    try {
      final items = await _confidentialReportService.listForOwner();
      _concerns
        ..clear()
        ..addAll(items);
      _concernsLoadedOnce = true;
    } catch (error) {
      _concernsError = error.toString().replaceFirst('Exception: ', '');
    } finally {
      _concernsLoading = false;
      notifyListeners();
    }
  }

  Future<void> reviewConcern({
    required ConcernReport report,
    required String status,
    required String notes,
  }) async {
    final updated = await _confidentialReportService.review(
      reportId: report.id,
      status: status,
      notes: notes,
    );
    final index = _concerns.indexWhere((item) => item.id == report.id);
    if (index >= 0) _concerns[index] = updated;
    notifyListeners();
  }

  void publishAnnouncement({
    required String title,
    required String body,
    required String audience,
  }) {
    final cleanTitle = title.trim();
    final cleanBody = body.trim();
    if (cleanTitle.isEmpty || cleanBody.isEmpty) return;

    MockData.announcements.insert(
      0,
      Announcement(
        id: 'a${DateTime.now().millisecondsSinceEpoch}',
        title: cleanTitle,
        body: cleanBody,
        createdAt: DateTime.now(),
        audience: audience,
      ),
    );
    notifyListeners();
  }

  void sendOwnerMessage(
    OwnerConversation conversation,
    String body,
  ) {
    final clean = body.trim();
    if (clean.isEmpty) return;

    conversation.messages.add(
      ChatMessage(
        id: 'ocm${DateTime.now().millisecondsSinceEpoch}',
        senderName: 'Caretaker',
        senderRole: 'ownerCaretaker',
        body: clean,
        sentAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  Future<void> loadCurfewRequests({bool force = false}) async {
    if (_curfewLoading && !force) return;
    if (_curfewLoadedOnce && !force) return;

    _curfewLoading = true;
    _curfewError = null;
    notifyListeners();

    try {
      final list = await _curfewService.listStaffRequests();
      _curfewRequests
        ..clear()
        ..addAll(list);
      _curfewLoadedOnce = true;
    } catch (e) {
      _curfewError = e.toString();
    } finally {
      _curfewLoading = false;
      notifyListeners();
    }
  }

  Future<CurfewRequest> decideCurfewRequest({
    required String requestId,
    required bool approve,
    String? notes,
  }) async {
    final updated = await _curfewService.decideStaffRequest(
      requestId: requestId,
      approve: approve,
      notes: notes,
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

  Future<void> loadStaffMaintenance({bool force = false}) async {
    if (_maintenanceLoading && !force) return;
    if (_maintenanceLoadedOnce && !force) return;

    _maintenanceLoading = true;
    _maintenanceError = null;
    notifyListeners();

    try {
      final reports = await _staffMaintenanceService.listReports();
      _staffMaintenanceReports
        ..clear()
        ..addAll(reports);
      _maintenanceLoadedOnce = true;
    } catch (e) {
      _maintenanceError = staffMaintenanceError(e);
    } finally {
      _maintenanceLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateStaffMaintenance({
    required StaffMaintenanceReport report,
    required String status,
    required String notes,
  }) async {
    await _staffMaintenanceService.save(report, status, notes);
    await loadStaffMaintenance(force: true);
  }

  @visibleForTesting
  void setStaffMaintenanceForTesting(List<StaffMaintenanceReport> reports) {
    _staffMaintenanceReports
      ..clear()
      ..addAll(reports);
    _maintenanceLoadedOnce = true;
    _maintenanceLoading = false;
    _maintenanceError = null;
    notifyListeners();
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

  Future<void> loadGateEvents({bool force = false}) async {
    if (_gateLoading && !force) return;
    if (_gateLoadedOnce && !force) return;

    _gateLoading = true;
    _gateError = null;
    notifyListeners();

    try {
      final events = await _gateService.loadGateEvents(forceRefresh: force);
      _gateEvents = events;
      _gateLoadedOnce = true;
    } catch (e) {
      _gateError = e.toString();
    } finally {
      _gateLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadTenants({bool force = false}) async {
    if (_tenantsLoading && !force) return;
    if (_tenantsLoadedOnce && !force) return;

    _tenantsLoading = true;
    notifyListeners();

    try {
      final list = await _tenantService.loadTenants(forceRefresh: force);
      _tenants = list;
      _tenantsLoadedOnce = true;
    } catch (_) {
      // Fallback preserves existing or MockData
    } finally {
      _tenantsLoading = false;
      notifyListeners();
    }
  }

  Future<void> recordStaffManualLog({
    required String tenantId,
    required String direction,
    required String notes,
    String? tenantName,
  }) async {
    await _gateService.recordStaffManualLog(
      tenantId: tenantId,
      direction: direction,
      notes: notes,
      tenantName: tenantName,
    );
    await loadGateEvents(force: true);
    await loadTenants(force: true);
  }

  @visibleForTesting
  void setGateEventsForTesting(List<GateEvent> events) {
    _gateEvents
      ..clear()
      ..addAll(events);
    _gateLoadedOnce = true;
    _gateLoading = false;
    _gateError = null;
    notifyListeners();
  }

  @visibleForTesting
  void setTenantsForTesting(List<TenantDirectoryEntry> items) {
    _tenants
      ..clear()
      ..addAll(items);
    _tenantsLoadedOnce = true;
    _tenantsLoading = false;
    notifyListeners();
  }

  void clear() {
    _payments.clear();
    _paymentsLoading = false;
    _paymentsError = null;
    _paymentsLoadedOnce = false;
    _roomRecords.clear();
    _roomsLoading = false;
    _roomsError = null;
    _curfewRequests.clear();
    _curfewLoading = false;
    _curfewError = null;
    _curfewLoadedOnce = false;
    _concerns.clear();
    _concernsLoading = false;
    _concernsError = null;
    _concernsLoadedOnce = false;
    _staffMaintenanceReports.clear();
    _maintenanceLoading = false;
    _maintenanceError = null;
    _maintenanceLoadedOnce = false;
    _gateEvents.clear();
    _gateLoading = false;
    _gateError = null;
    _gateLoadedOnce = false;
    _tenants.clear();
    _tenantsLoading = false;
    _tenantsLoadedOnce = false;
    notifyListeners();
  }
}
