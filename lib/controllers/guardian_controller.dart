import 'package:flutter/foundation.dart';

import '../data/mock_data.dart';
import '../models/models.dart';

class GuardianController extends ChangeNotifier {
  GuardianController._();

  static final GuardianController instance = GuardianController._();

  String get linkedTenantName => 'Anna Dela Cruz';

  List<GeofenceEvent> get geofenceEvents =>
      List.unmodifiable(MockData.gateEvents);
  List<GeofenceEvent> get gateEvents => geofenceEvents;
  List<Payment> get payments => List.unmodifiable(MockData.payments);
  List<ChatMessage> get messages =>
      List.unmodifiable(MockData.guardianMessages);

  String get linkedTenantPresence => 'Inside';

  double get outstandingTotal => payments
      .where((payment) => payment.status != 'Verified')
      .fold<double>(0, (sum, payment) => sum + payment.amount);

  void sendMessage(String body) {
    final clean = body.trim();
    if (clean.isEmpty) return;

    MockData.guardianMessages.add(
      ChatMessage(
        id: 'gm${DateTime.now().millisecondsSinceEpoch}',
        senderName: 'Maria Dela Cruz',
        senderRole: 'guardian',
        body: clean,
        sentAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }
}
