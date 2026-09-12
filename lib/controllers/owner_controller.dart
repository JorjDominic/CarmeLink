import 'package:flutter/foundation.dart';

import '../data/mock_data.dart';
import '../models/models.dart';
import '../services/payment_service.dart';
import '../services/room_service.dart';

class OwnerController extends ChangeNotifier {
  OwnerController._();

  static final OwnerController instance = OwnerController._();

  final PaymentService _paymentService = const PaymentService();
  final List<Payment> _payments = [];
  bool _paymentsLoading = false;
  String? _paymentsError;

  final RoomService _roomService = const RoomService();
  final List<RoomRecord> _roomRecords = [];
  bool _roomsLoading = false;
  String? _roomsError;

  List<TenantDirectoryEntry> get tenants =>
      List.unmodifiable(MockData.tenantDirectory);

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
  List<MaintenanceReport> get maintenance =>
      List.unmodifiable(MockData.maintenance);
  List<MaintenanceReport> get maintenanceByPriority {
    const rank = {'High': 3, 'Medium': 2, 'Low': 1};
    return [...MockData.maintenance]
      ..sort((a, b) => (rank[b.urgency] ?? 0).compareTo(rank[a.urgency] ?? 0));
  }

  List<GeofenceEvent> get geofenceEvents =>
      List.unmodifiable(MockData.gateEvents);
  List<GeofenceEvent> get gateEvents => geofenceEvents;
  List<VisitorRequest> get visitors => List.unmodifiable(MockData.visitors);
  List<ConcernReport> get concerns => List.unmodifiable(MockData.concerns);
  List<Announcement> get announcements =>
      List.unmodifiable(MockData.announcements);
  List<OwnerConversation> get conversations =>
      List.unmodifiable(MockData.ownerConversations);

  int get occupiedBeds =>
      rooms.fold<int>(0, (sum, room) => sum + room.occupied);

  int get totalCapacity =>
      rooms.fold<int>(0, (sum, room) => sum + room.capacity);

  int get pendingPaymentProofs => payments
      .where((payment) =>
          payment.status == 'Pending verification' ||
          payment.status == 'Pending review')
      .length;

  int get openMaintenance => maintenance
      .where(
        (report) => report.status != 'Completed' && report.status != 'Closed',
      )
      .length;

  int get pendingVisitors =>
      visitors.where((visitor) => visitor.status == 'Pending').length;

  int get tenantsInsideCount => tenants
      .where((t) => t.gateStatus == 'IN' || t.gateStatus == 'Inside')
      .length;

  int get tenantsOutsideCount => tenants
      .where((t) => t.gateStatus == 'OUT' || t.gateStatus == 'Outside')
      .length;

  List<Payment> get payments => _payments.isEmpty
      ? List.unmodifiable(MockData.payments)
      : List.unmodifiable(_payments);
  bool get paymentsLoading => _paymentsLoading;
  String? get paymentsError => _paymentsError;

  Future<void> loadPayments({bool force = false}) async {
    if (_paymentsLoading) return;
    if (_payments.isNotEmpty && !force) return;

    _paymentsLoading = true;
    _paymentsError = null;
    notifyListeners();

    try {
      final list = await _paymentService.listAllPayments();
      _payments
        ..clear()
        ..addAll(list);
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

  void updateConcernStatus(ConcernReport report, String status) {
    report.status = status;
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
}
