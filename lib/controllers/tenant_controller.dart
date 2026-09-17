import 'package:flutter/foundation.dart';

import '../data/mock_data.dart';
import '../models/models.dart';
import '../services/curfew_service.dart';
import '../services/maintenance_service.dart';
import '../services/payment_service.dart';
import '../services/room_service.dart';

class TenantController extends ChangeNotifier {
  TenantController._();

  static final TenantController instance = TenantController._();

  final CurfewService _curfewService = const CurfewService();
  final MaintenanceService _maintenanceService = const MaintenanceService();
  final PaymentService _paymentService = const PaymentService();
  final RoomService _roomService = const RoomService();

  final List<MaintenanceReport> _maintenance = [];
  final List<Payment> _payments = [];
  final List<CurfewRequest> _curfewRequests = [];
  Room? _room;

  bool _maintenanceLoading = false;
  String? _maintenanceError;
  bool _maintenanceLoadedOnce = false;

  bool _paymentsLoading = false;
  String? _paymentsError;
  bool _paymentsLoadedOnce = false;

  bool _curfewLoading = false;
  String? _curfewError;
  bool _curfewLoadedOnce = false;

  bool _roomLoading = false;
  String? _roomError;
  bool _roomLoadedOnce = false;

  Room? get room => _room;
  bool get roomLoading => _roomLoading;
  String? get roomError => _roomError;
  bool get isRoomAssigned => _room != null;

  List<Payment> get payments => _payments.isEmpty
      ? List.unmodifiable(MockData.payments)
      : List.unmodifiable(_payments);

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

  List<CurfewRequest> get curfewRequests =>
      List.unmodifiable(_curfewRequests);
  bool get curfewLoading => _curfewLoading;
  String? get curfewError => _curfewError;
  bool get curfewLoadedOnce => _curfewLoadedOnce;

  CurfewRequest? get activeCurfewRequest {
    final active =
        _curfewRequests.where((r) => r.isPending || r.isApproved).toList();
    return active.isNotEmpty ? active.first : null;
  }

  List<GeofenceEvent> get geofenceEvents =>
      List.unmodifiable(MockData.gateEvents);

  List<GeofenceEvent> get gateEvents => geofenceEvents;

  List<Announcement> get announcements => List.unmodifiable(
        MockData.announcements,
      );

  List<VisitorRequest> get visitors => List.unmodifiable(MockData.visitors);

  List<ConcernReport> get concerns => List.unmodifiable(MockData.concerns);

  List<ChatMessage> get messages => List.unmodifiable(
        MockData.tenantMessages,
      );

  bool get maintenanceLoading => _maintenanceLoading;

  String? get maintenanceError => _maintenanceError;

  bool get maintenanceLoadedOnce => _maintenanceLoadedOnce;

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
    final updated = await _curfewService.cancelRequest(requestId);
    final index = _curfewRequests.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      _curfewRequests[index] = updated;
    }
    notifyListeners();
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
    } catch (_) {
      final mock = Payment(
        id: targetId,
        label: '$method payment submission',
        amount: amount,
        dueDate: DateTime.now(),
        status: 'Pending verification',
        reference: reference.trim().isEmpty ? null : reference.trim(),
        paymentMethod: method,
      );
      final localIndex = _payments.indexWhere((p) => p.id == targetId);
      if (localIndex != -1) {
        _payments[localIndex] = mock;
      } else {
        _payments.insert(0, mock);
      }
      final index = MockData.payments.indexWhere((p) => p.id == targetId);
      if (index != -1) {
        MockData.payments[index] = mock;
      } else {
        MockData.payments.insert(0, mock);
      }
      notifyListeners();
      return mock;
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

  void submitVisitor({
    required String visitorName,
    required String relationship,
    required DateTime schedule,
  }) {
    MockData.visitors.insert(
      0,
      VisitorRequest(
        id: 'v${DateTime.now().millisecondsSinceEpoch}',
        visitorName: visitorName,
        relationship: relationship,
        schedule: schedule,
        status: 'Pending',
      ),
    );

    notifyListeners();
  }

  void submitConcern({
    required String category,
    required String summary,
  }) {
    MockData.concerns.insert(
      0,
      ConcernReport(
        id: 'r${DateTime.now().millisecondsSinceEpoch}',
        category: category,
        summary: summary,
        status: 'Submitted',
        createdAt: DateTime.now(),
      ),
    );

    notifyListeners();
  }

  void sendMessage(String body) {
    final clean = body.trim();

    if (clean.isEmpty) {
      return;
    }

    MockData.tenantMessages.add(
      ChatMessage(
        id: 'tm${DateTime.now().millisecondsSinceEpoch}',
        senderName: 'Anna Dela Cruz',
        senderRole: 'tenant',
        body: clean,
        sentAt: DateTime.now(),
      ),
    );

    notifyListeners();
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
}
