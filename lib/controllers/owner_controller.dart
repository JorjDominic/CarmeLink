import 'package:flutter/foundation.dart';

import '../data/mock_data.dart';
import '../models/models.dart';

class OwnerController extends ChangeNotifier {
  OwnerController._();

  static final OwnerController instance = OwnerController._();

  List<TenantDirectoryEntry> get tenants =>
      List.unmodifiable(MockData.tenantDirectory);
  List<DormRoomStatus> get rooms => List.unmodifiable(MockData.roomStatuses);
  List<Payment> get payments => List.unmodifiable(MockData.payments);
  List<MaintenanceReport> get maintenance =>
      List.unmodifiable(MockData.maintenance);
  List<MaintenanceReport> get maintenanceByPriority {
    const rank = {'High': 3, 'Medium': 2, 'Low': 1};
    return [...MockData.maintenance]
      ..sort((a, b) => (rank[b.urgency] ?? 0).compareTo(rank[a.urgency] ?? 0));
  }

  List<GateEvent> get gateEvents => List.unmodifiable(MockData.gateEvents);
  List<CurfewRequest> get curfewRequests =>
      List.unmodifiable(MockData.curfewRequests);
  List<VisitorRequest> get visitors => List.unmodifiable(MockData.visitors);
  List<ConcernReport> get concerns => List.unmodifiable(MockData.concerns);
  List<Announcement> get announcements =>
      List.unmodifiable(MockData.announcements);
  List<OwnerConversation> get conversations =>
      List.unmodifiable(MockData.ownerConversations);
  List<GateReviewRecord> get gateReviews =>
      List.unmodifiable(MockData.gateReviews);

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

  int get pendingCurfewReviews => curfewRequests
      .where((request) => request.ownerStatus == 'Pending')
      .length;

  int get pendingVisitors =>
      visitors.where((visitor) => visitor.status == 'Pending').length;

  int get pendingGateReviews =>
      gateReviews.where((review) => review.reviewStatus == 'Pending').length;

  void verifyPayment(Payment payment, bool approve) {
    payment.status = approve ? 'Verified' : 'Rejected';
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

  void decideCurfew(CurfewRequest request, bool approve) {
    request.ownerStatus = approve ? 'Approved' : 'Rejected';
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

  void reviewGateEvent(
    GateReviewRecord review, {
    required String status,
    String note = '',
  }) {
    review.reviewStatus = status;
    review.note = note.trim();
    notifyListeners();
  }

  // Legacy migration stub only. No physical lock/relay is connected and the
  // manual-override screen has no navigation path in the finalized app.
  void addManualOverride({required String reason, required String action}) {}
}
