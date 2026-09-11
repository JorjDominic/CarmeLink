import 'package:flutter/foundation.dart';

import '../data/mock_data.dart';
import '../models/models.dart';
import '../services/maintenance_service.dart';

class TenantController extends ChangeNotifier {
  TenantController._();

  static final TenantController instance = TenantController._();

  final MaintenanceService _maintenanceService = const MaintenanceService();

  final List<MaintenanceReport> _maintenance = [];

  bool _maintenanceLoading = false;
  String? _maintenanceError;

  Room get room => MockData.room;

  List<Payment> get payments => List.unmodifiable(MockData.payments);

  List<MaintenanceReport> get maintenance => List.unmodifiable(_maintenance);

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

  Future<void> loadMaintenance() async {
    if (_maintenanceLoading) {
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
    } catch (error) {
      _maintenanceError = _message(error);
    } finally {
      _maintenanceLoading = false;
      notifyListeners();
    }
  }

  void submitPaymentProof({
    required double amount,
    required String method,
    required String reference,
  }) {
    MockData.payments.insert(
      0,
      Payment(
        id: 'p${DateTime.now().millisecondsSinceEpoch}',
        label: '$method payment submission',
        amount: amount,
        dueDate: DateTime.now(),
        status: 'Pending review',
        reference: reference.trim().isEmpty ? null : reference.trim(),
      ),
    );

    notifyListeners();
  }

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

  Future<String?> maintenancePhotoUrl(
    String? photoPath,
  ) {
    return _maintenanceService.createPhotoUrl(photoPath);
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
