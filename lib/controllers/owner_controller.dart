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
