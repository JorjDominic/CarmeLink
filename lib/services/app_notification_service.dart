import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';

String announcementRecipientRole(String audience) =>
    switch (audience.trim().toLowerCase()) {
      'tenants' => 'tenant',
      'guardians' => 'guardian',
      'staff' => 'staff',
      'all' => 'all',
      _ => throw ArgumentError.value(
          audience, 'audience', 'Unknown announcement audience'),
    };

int compareNotificationsNewestFirst(
    AppNotificationItem a, AppNotificationItem b) {
  final date = b.createdAt.compareTo(a.createdAt);
  return date != 0 ? date : b.id.compareTo(a.id);
}

String notificationPageCursorFilter(DateTime before, String beforeId) {
  if (!RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
      .hasMatch(beforeId)) {
    throw ArgumentError.value(
        beforeId, 'beforeId', 'Expected a notification UUID');
  }
  final timestamp = before.toUtc().toIso8601String();
  return 'created_at.lt.$timestamp,and(created_at.eq.$timestamp,id.lt.$beforeId)';
}

class AppNotificationItem {
  const AppNotificationItem({
    required this.id,
    required this.recipientId,
    required this.notificationType,
    required this.title,
    required this.body,
    this.routeType,
    this.routeId,
    this.data = const {},
    required this.createdAt,
    this.readAt,
  });

  factory AppNotificationItem.fromRow(Map<String, dynamic> row) {
    return AppNotificationItem(
      id: row['id'] as String,
      recipientId: row['recipient_id'] as String,
      notificationType: row['notification_type'] as String? ?? 'system',
      title: row['title'] as String? ?? '',
      body: row['body'] as String? ?? '',
      routeType: row['route_type'] as String?,
      routeId: row['route_id']?.toString(),
      data: row['data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(row['data'] as Map)
          : const {},
      createdAt: row['created_at'] != null
          ? DateTime.tryParse(row['created_at'] as String)?.toLocal() ??
              DateTime.now()
          : DateTime.now(),
      readAt: row['read_at'] != null
          ? DateTime.tryParse(row['read_at'] as String)?.toLocal()
          : null,
    );
  }

  final String id;
  final String recipientId;
  final String notificationType;
  final String title;
  final String body;
  final String? routeType;
  final String? routeId;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  String get destinationType {
    final route = routeType?.trim().toLowerCase();
    return route == null || route.isEmpty
        ? notificationType.trim().toLowerCase()
        : route;
  }

  String? get destinationId {
    final direct = routeId?.trim();
    if (direct != null && direct.isNotEmpty) return direct;
    final key = switch (destinationType) {
      'conduct_case' => 'case_id',
      'confidential_report' ||
      'maintenance' ||
      'cleaning_report' =>
        'report_id',
      'message' || 'conversation' => 'conversation_id',
      'payment' => 'payment_id',
      'curfew' => 'request_id',
      'visitor' => 'pass_id',
      'announcement' => 'announcement_id',
      'inspection' => 'inspection_id',
      'onboarding' => 'contract_id',
      'move_out' => 'case_id',
      'cleaning_schedule' => 'bed_space_id',
      'employee_curfew' => 'profile_id',
      'room_assignment' => 'room_id',
      'guardian_link' => 'tenant_id',
      'gate' || 'gate_event' => 'event_id',
      _ => '',
    };
    final value = data[key]?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  factory AppNotificationItem.fromPush(Map<String, dynamic> payload,
      {required String recipientId}) {
    return AppNotificationItem(
      id: payload['notification_id']?.toString() ?? '',
      recipientId: recipientId,
      notificationType: payload['notification_type']?.toString() ?? 'system',
      title: payload['title']?.toString() ?? 'CarmeLink update',
      body: payload['body']?.toString() ??
          'Open Notifications to view this update.',
      routeType: payload['route_type']?.toString(),
      routeId: payload['route_id']?.toString(),
      data: Map<String, dynamic>.from(payload),
      createdAt: DateTime.now(),
    );
  }
}

class AppNotificationService {
  AppNotificationService._();
  static final AppNotificationService instance = AppNotificationService._();

  SupabaseClient? get _client => SupabaseConfig.clientSafe;

  /// Low-level dispatcher that invokes the Supabase `send-fcm-notification` Edge Function
  Future<bool> sendNotification({
    required String title,
    required String body,
    required String notificationType,
    String? recipientId,
    List<String>? recipientIds,
    String? recipientRole,
    String? tenantId,
    bool notifyGuardians = false,
    bool notifyTenant = false,
    String? routeType,
    String? routeId,
    Map<String, dynamic>? data,
  }) async {
    final client = _client;
    if (client == null) return false;

    try {
      final payload = <String, dynamic>{
        'title': String.fromCharCodes(title.trim().runes.take(120)),
        'body': String.fromCharCodes(body.trim().runes.take(500)),
        'notification_type': notificationType.trim().toLowerCase(),
        if (recipientId != null && recipientId.isNotEmpty)
          'recipient_id': recipientId,
        if (recipientIds != null && recipientIds.isNotEmpty)
          'recipient_ids': recipientIds,
        if (recipientRole != null && recipientRole.isNotEmpty)
          'recipient_role': recipientRole,
        if (tenantId != null && tenantId.isNotEmpty) 'tenant_id': tenantId,
        'notify_guardians': notifyGuardians,
        'notify_tenant': notifyTenant,
        if (routeType != null && routeType.isNotEmpty) 'route_type': routeType,
        if (routeId != null && routeId.isNotEmpty) 'route_id': routeId,
        if (data != null && data.isNotEmpty) 'data': data,
      };

      final response = await client.functions.invoke(
        'send-fcm-notification',
        body: payload,
      );

      if (response.status >= 200 && response.status < 300) {
        final result = response.data;
        if (result is! Map ||
            result['created'] is! num ||
            result['recipients'] is! num ||
            (result['created'] as num) <= 0 ||
            (result['created'] as num) < (result['recipients'] as num)) {
          debugPrint('Notification was not saved for every recipient: $result');
          return false;
        }
        debugPrint(
            'FCM Notification dispatched successfully: ${response.data}');
        return true;
      } else {
        debugPrint(
            'FCM Notification invoke returned status ${response.status}: ${response.data}');
        return false;
      }
    } catch (e) {
      debugPrint('FCM Notification dispatch error (non-fatal): $e');
      return false;
    }
  }

  // ==========================================
  // MODULE: ANNOUNCEMENTS
  // ==========================================
  Future<bool> notifyNewAnnouncement({
    required String title,
    required String body,
    required String audience,
    required String announcementId,
  }) async {
    final targetRole = announcementRecipientRole(audience);

    return sendNotification(
      title: '📢 $title',
      body: body.length > 200 ? '${body.substring(0, 197)}...' : body,
      notificationType: 'announcement',
      recipientRole: targetRole,
      routeType: 'announcement',
      routeId: announcementId,
      data: {'announcement_id': announcementId, 'audience': audience},
    );
  }

  // ==========================================
  // MODULE: MAINTENANCE / REPAIRS
  // ==========================================
  Future<void> notifyMaintenanceSubmitted({
    required String reportId,
    required String location,
    required String category,
    required String description,
  }) async {
    await sendNotification(
      title: '🛠️ Maintenance Request: $location',
      body: '$category: $description',
      notificationType: 'maintenance',
      recipientRole: 'staff',
      routeType: 'maintenance',
      routeId: reportId,
      data: {
        'report_id': reportId,
        'location': location,
        'category': category,
      },
    );
  }

  Future<void> notifyMaintenanceStatusChanged({
    required String tenantId,
    required String reportId,
    required String category,
    required String status,
    String? notes,
  }) async {
    final notePart = (notes != null && notes.trim().isNotEmpty)
        ? ' Note: ${notes.trim()}'
        : '';
    await sendNotification(
      title: '🛠️ Maintenance Update: $status',
      body: 'Your maintenance request for "$category" is now $status.$notePart',
      notificationType: 'maintenance',
      recipientId: tenantId,
      routeType: 'maintenance',
      routeId: reportId,
      data: {
        'report_id': reportId,
        'status': status,
        'category': category,
      },
    );
  }

  // ==========================================
  // MODULE: PAYMENTS & BILLING
  // ==========================================
  Future<void> notifyPaymentSubmitted({
    required String paymentId,
    required String tenantName,
    required double amount,
    required String referenceNumber,
  }) async {
    final formattedAmount = '₱${amount.toStringAsFixed(2)}';
    await sendNotification(
      title: '💳 Payment Submitted',
      body: '$tenantName submitted $formattedAmount (Ref: $referenceNumber).',
      notificationType: 'payment',
      recipientRole: 'staff',
      routeType: 'payment',
      routeId: paymentId,
      data: {
        'payment_id': paymentId,
        'amount': amount.toString(),
        'reference_number': referenceNumber,
      },
    );
  }

  Future<void> notifyPaymentReviewed({
    required String tenantId,
    required String paymentId,
    required bool approved,
    required double amount,
    String? reason,
  }) async {
    final formattedAmount = '₱${amount.toStringAsFixed(2)}';
    final statusText = approved ? 'Verified & Approved' : 'Rejected';
    final detail = approved
        ? 'Your payment of $formattedAmount has been officially credited.'
        : 'Your payment of $formattedAmount was rejected.${reason != null && reason.trim().isNotEmpty ? ' Reason: $reason' : ''}';

    await sendNotification(
      title: approved ? '✅ Payment $statusText' : '⚠️ Payment $statusText',
      body: detail,
      notificationType: 'payment',
      recipientId: tenantId,
      tenantId: tenantId,
      notifyGuardians: true,
      routeType: 'payment',
      routeId: paymentId,
      data: {
        'payment_id': paymentId,
        'approved': approved.toString(),
        'amount': amount.toString(),
      },
    );
  }

  Future<void> notifyUtilityBillCreated({
    required String tenantId,
    required String title,
    required double amount,
    required String dueDate,
  }) async {
    final formattedAmount = '₱${amount.toStringAsFixed(2)}';
    await sendNotification(
      title: '📄 New Bill Issued: $title',
      body: 'A charge of $formattedAmount is due on $dueDate.',
      notificationType: 'payment',
      recipientId: tenantId,
      tenantId: tenantId,
      notifyGuardians: true,
      routeType: 'payment',
      data: {
        'title': title,
        'amount': amount.toString(),
        'due_date': dueDate,
      },
    );
  }

  Future<void> notifyBillingChargeChanged({
    required String tenantId,
    required String chargeId,
    required String title,
    required String actionType,
    required String reason,
  }) async {
    final action = switch (actionType) {
      'void' => 'voided',
      'credit' => 'credited',
      'debit' => 'adjusted',
      'due_date_extension' => 'given a new due date',
      _ => 'updated',
    };
    await sendNotification(
      title: 'Billing charge updated',
      body: '$title was $action. Reason: $reason',
      notificationType: 'payment',
      recipientId: tenantId,
      tenantId: tenantId,
      notifyGuardians: true,
      routeType: 'payment',
      routeId: chargeId,
      data: {
        'payment_id': chargeId,
        'action_type': actionType,
      },
    );
  }

  Future<void> notifyRentRateChanged({
    required String tenantId,
    required double newMonthlyRent,
    required String effectiveDate,
    required int adjustedChargeCount,
  }) async {
    final formattedAmount = '₱${newMonthlyRent.toStringAsFixed(2)}';
    await sendNotification(
      title: 'Rent rate updated',
      body:
          'Your monthly rent is now $formattedAmount effective $effectiveDate. '
          '$adjustedChargeCount future unpaid charge(s) were adjusted.',
      notificationType: 'payment',
      recipientId: tenantId,
      tenantId: tenantId,
      notifyGuardians: true,
      routeType: 'payment',
      data: {
        'tenant_id': tenantId,
        'new_monthly_rent': newMonthlyRent.toString(),
        'effective_date': effectiveDate,
        'adjusted_charge_count': adjustedChargeCount.toString(),
      },
    );
  }

  Future<void> notifyPaymentDueToStaff({
    required String tenantName,
    required String paymentTitle,
    required double amount,
    required DateTime dueDate,
    required bool isOverdue,
    String? paymentId,
  }) async {
    final formattedAmount = '₱${amount.toStringAsFixed(2)}';
    final formattedDate =
        '${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}';
    final title = isOverdue
        ? '⚠️ Overdue Payment: $tenantName'
        : '📅 Payment Due: $tenantName';
    final body = isOverdue
        ? '$tenantName has an overdue payment for "$paymentTitle" of $formattedAmount (Due: $formattedDate).'
        : '$tenantName has a payment for "$paymentTitle" of $formattedAmount due today ($formattedDate).';

    await sendNotification(
      title: title,
      body: body,
      notificationType: 'payment',
      recipientRole: 'staff',
      routeType: 'payment',
      routeId: paymentId,
      data: {
        if (paymentId != null) 'payment_id': paymentId,
        'tenant_name': tenantName,
        'amount': amount.toString(),
        'due_date': formattedDate,
        'is_overdue': isOverdue.toString(),
      },
    );
  }

  Future<void> notifyPaymentDueSummaryToStaff({
    required int dueTodayCount,
    required int overdueCount,
    required double totalUncollectedAmount,
  }) async {
    final formattedAmount = '₱${totalUncollectedAmount.toStringAsFixed(2)}';
    String title;
    String body;

    if (overdueCount > 0 && dueTodayCount > 0) {
      title =
          '⚠️ Payment Due Alert: $overdueCount Overdue, $dueTodayCount Due Today';
      body =
          'Total uncollected: $formattedAmount across active dormitory charges.';
    } else if (overdueCount > 0) {
      title = '⚠️ Payment Alert: $overdueCount Overdue Payments';
      body =
          'There are $overdueCount overdue payments totaling $formattedAmount requiring review.';
    } else {
      title = '📅 Payment Reminder: $dueTodayCount Payments Due Today';
      body =
          '$dueTodayCount tenant charges totaling $formattedAmount are due for collection today.';
    }

    await sendNotification(
      title: title,
      body: body,
      notificationType: 'payment',
      recipientRole: 'staff',
      routeType: 'payment',
      data: {
        'due_today_count': dueTodayCount.toString(),
        'overdue_count': overdueCount.toString(),
        'total_amount': totalUncollectedAmount.toString(),
      },
    );
  }

  // ==========================================
  // MODULE: GATE & GEOFENCE CROSSINGS
  // ==========================================
  Future<void> notifyGateCrossing({
    required String tenantId,
    required String tenantName,
    required String direction,
    bool isFlagged = false,
    String? eventId,
  }) async {
    final isEntry = direction == 'IN';
    final title = isFlagged
        ? '⚠️ Curfew Alert: $tenantName'
        : (isEntry
            ? '🏠 Dorm Arrival: $tenantName'
            : '🚪 Dorm Departure: $tenantName');
    final body = isFlagged
        ? '$tenantName was detected outside during curfew hours.'
        : '$tenantName has ${isEntry ? "entered" : "left"} the dormitory premises.';

    // Dispatches to linked guardians for this tenant
    await sendNotification(
      title: title,
      body: body,
      notificationType: 'gate',
      tenantId: tenantId,
      notifyGuardians: true,
      routeType: 'gate_event',
      routeId: eventId,
      data: {
        'tenant_id': tenantId,
        'direction': direction,
        'is_flagged': isFlagged.toString(),
        if (eventId != null) 'event_id': eventId,
      },
    );
  }

  // ==========================================
  // MODULE: VISITOR PASSES
  // ==========================================
  Future<void> notifyVisitorPassRequested({
    required String passId,
    required String tenantName,
    required String visitorName,
    required String visitDate,
  }) async {
    await sendNotification(
      title: '👥 Visitor Pass Request',
      body: '$tenantName requested a pass for $visitorName on $visitDate.',
      notificationType: 'visitor',
      recipientRole: 'staff',
      routeType: 'visitor',
      routeId: passId,
      data: {
        'pass_id': passId,
        'visitor_name': visitorName,
        'visit_date': visitDate,
      },
    );
  }

  Future<void> notifyVisitorPassStatusChanged({
    required String tenantId,
    required String passId,
    required String visitorName,
    required String status,
  }) async {
    await sendNotification(
      title: '👥 Visitor Pass: $status',
      body: 'The pass for $visitorName has been marked as $status.',
      notificationType: 'visitor',
      recipientId: tenantId,
      routeType: 'visitor',
      routeId: passId,
      data: {
        'pass_id': passId,
        'visitor_name': visitorName,
        'status': status,
      },
    );
  }

  // ==========================================
  // MODULE: CURFEW REQUESTS
  // ==========================================
  Future<void> notifyCurfewPassRequested({
    required String requestId,
    required String tenantId,
    required String tenantName,
    required String requestType,
    required String curfewDate,
    required bool requiresGuardianReview,
  }) async {
    await sendNotification(
      title: '🌙 Curfew Pass Request',
      body: '$tenantName requested a $requestType pass for $curfewDate.',
      notificationType: 'curfew',
      recipientRole: 'staff',
      tenantId: tenantId,
      notifyGuardians: requiresGuardianReview,
      routeType: 'curfew',
      routeId: requestId,
      data: {
        'request_id': requestId,
        'request_type': requestType,
        'curfew_date': curfewDate,
      },
    );
  }

  Future<void> notifyCurfewPassStatusChanged({
    required String tenantId,
    required String requestId,
    required String requestType,
    required String status,
  }) async {
    await sendNotification(
      title: '🌙 Curfew Pass: $status',
      body: 'Your $requestType pass has been $status.',
      notificationType: 'curfew',
      recipientId: tenantId,
      tenantId: tenantId,
      notifyGuardians: true, // Also keeps guardians informed
      routeType: 'curfew',
      routeId: requestId,
      data: {
        'request_id': requestId,
        'request_type': requestType,
        'status': status,
      },
    );
  }

  Future<void> notifyCurfewGuardianDecisionToStaff({
    required String tenantId,
    required String requestId,
    required String requestType,
    required bool approved,
  }) async {
    await sendNotification(
      title: approved
          ? 'Guardian approved overnight leave'
          : 'Guardian declined overnight leave',
      body: approved
          ? 'The guardian approved the $requestType request. No staff approval is required.'
          : 'The guardian declined the $requestType request.',
      notificationType: 'curfew',
      recipientRole: 'staff',
      tenantId: tenantId,
      routeType: 'curfew',
      routeId: requestId,
      data: {
        'request_id': requestId,
        'request_type': requestType,
        'guardian_decision': approved ? 'approved' : 'rejected',
      },
    );
  }

  // ==========================================
  // MODULE: CONDUCT CASES & APPEALS
  // ==========================================
  Future<void> notifyConductCaseFiled({
    required String tenantId,
    required String caseId,
    required String title,
    required String severity,
  }) async {
    await sendNotification(
      title: '⚠️ Conduct Incident Notice',
      body: 'A $severity conduct report "$title" has been documented.',
      notificationType: 'safety',
      recipientId: tenantId,
      tenantId: tenantId,
      notifyGuardians: true,
      routeType: 'conduct_case',
      routeId: caseId,
      data: {
        'case_id': caseId,
        'severity': severity,
      },
    );
  }

  Future<void> notifyConductAppealSubmitted({
    required String caseId,
    required String tenantName,
  }) async {
    await sendNotification(
      title: '📋 Conduct Case Appeal Filed',
      body: '$tenantName filed an appeal for review.',
      notificationType: 'safety',
      recipientRole: 'staff',
      routeType: 'conduct_case',
      routeId: caseId,
      data: {'case_id': caseId},
    );
  }

  Future<void> notifyConductAppealResolved({
    required String tenantId,
    required String caseId,
    required String decision,
  }) async {
    await sendNotification(
      title: '📋 Conduct Appeal Decision: $decision',
      body: 'The appeal for your conduct case has been resolved: $decision.',
      notificationType: 'safety',
      recipientId: tenantId,
      tenantId: tenantId,
      notifyGuardians: true,
      routeType: 'conduct_case',
      routeId: caseId,
      data: {
        'case_id': caseId,
        'decision': decision,
      },
    );
  }

  // ==========================================
  // MODULE: ROOM INSPECTIONS
  // ==========================================
  Future<void> notifyInspectionCompleted({
    required String tenantId,
    required String inspectionId,
    required String roomName,
    required String status,
  }) async {
    await sendNotification(
      title: '🔍 Room Inspection: $status',
      body: 'Room inspection for $roomName has been completed ($status).',
      notificationType: 'maintenance',
      recipientId: tenantId,
      routeType: 'inspection',
      routeId: inspectionId,
      data: {
        'inspection_id': inspectionId,
        'room_name': roomName,
        'status': status,
      },
    );
  }

  // ==========================================
  // IN-APP NOTIFICATIONS QUERY & MANAGEMENT
  // ==========================================
  Future<List<AppNotificationItem>> fetchMyNotificationsPage({
    int limit = 15,
    DateTime? before,
    String? beforeId,
  }) async {
    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return const [];

    dynamic query = client
        .from('app_notifications')
        .select(
          'id, recipient_id, notification_type, title, body, route_type, '
          'route_id, data, created_at, read_at',
        )
        .eq('recipient_id', user.id);

    if (before != null) {
      query = beforeId == null
          ? query.lt('created_at', before.toUtc().toIso8601String())
          : query.or(notificationPageCursorFilter(before, beforeId));
    }

    final rows = await query
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(limit.clamp(1, 60).toInt());

    return (rows as List)
        .map((row) => AppNotificationItem.fromRow(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<AppNotificationItem>> fetchMyNotifications({
    int limit = 40,
  }) async {
    try {
      return await fetchMyNotificationsPage(limit: limit);
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      return const [];
    }
  }

  Stream<List<AppNotificationItem>> streamMyNotifications({int limit = 30}) {
    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return const Stream.empty();

    return client
        .from('app_notifications')
        .stream(primaryKey: ['id'])
        .eq('recipient_id', user.id)
        .order('created_at', ascending: false)
        .limit(limit)
        .map(
          (rows) => rows
              .map((row) => AppNotificationItem.fromRow(row))
              .toList(growable: false),
        );
  }

  Future<bool> tryMarkAsRead(String notificationId) async {
    final client = _client;
    if (client == null) return false;
    try {
      await client.rpc('mark_notification_read', params: {
        'p_notification_id': notificationId,
      });
      return true;
    } catch (e) {
      debugPrint('Error marking notification read: $e');
      return false;
    }
  }

  Future<void> markAsRead(String notificationId) async {
    await tryMarkAsRead(notificationId);
  }

  Future<bool> tryMarkAllAsRead() async {
    final client = _client;
    if (client == null) return false;
    try {
      await client.rpc('mark_all_notifications_read');
      return true;
    } catch (e) {
      debugPrint('Error marking all notifications read: $e');
      return false;
    }
  }

  Future<void> markAllAsRead() async {
    await tryMarkAllAsRead();
  }

  Future<int?> fetchMyUnreadCount() async {
    final client = _client;
    if (client == null) return null;
    try {
      final result = await client.rpc('my_unread_notification_count');
      if (result is int) return result;
      return int.tryParse(result?.toString() ?? '');
    } catch (e) {
      debugPrint('Error loading unread notification count: $e');
      return null;
    }
  }

  Future<void> cleanupExpiredNotifications() async {
    final client = _client;
    if (client == null) return;
    try {
      await client.rpc('cleanup_my_expired_notifications');
    } catch (e) {
      // Retention cleanup is best-effort and must never block app startup.
      debugPrint('Notification retention cleanup skipped: $e');
    }
  }

  Future<AppNotificationItem?> fetchNotification(String id) async {
    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null || user == null || id.isEmpty) return null;
    final row = await client
        .from('app_notifications')
        .select()
        .eq('id', id)
        .eq('recipient_id', user.id)
        .maybeSingle();
    return row == null ? null : AppNotificationItem.fromRow(row);
  }
}
