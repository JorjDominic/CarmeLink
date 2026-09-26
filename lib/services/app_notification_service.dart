import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';

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
        'title': title.trim(),
        'body': body.trim(),
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
    final targetRole = switch (audience.toLowerCase().trim()) {
      'tenants' => 'tenant',
      'guardians' => 'guardian',
      _ => 'all',
    };

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
      routeType: 'payment',
      routeId: chargeId,
      data: {
        'payment_id': chargeId,
        'action_type': actionType,
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
  Future<List<AppNotificationItem>> fetchMyNotifications(
      {int limit = 40}) async {
    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return [];

    try {
      final rows = await client
          .from('app_notifications')
          .select()
          .eq('recipient_id', user.id)
          .order('created_at', ascending: false)
          .limit(limit);

      return (rows as List)
          .map((r) => AppNotificationItem.fromRow(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      return [];
    }
  }

  Stream<List<AppNotificationItem>> streamMyNotifications({int limit = 40}) {
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
            (rows) => rows.map((r) => AppNotificationItem.fromRow(r)).toList());
  }

  Future<void> markAsRead(String notificationId) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.rpc('mark_notification_read', params: {
        'p_notification_id': notificationId,
      });
    } catch (e) {
      // Fallback direct update
      try {
        await client.from('app_notifications').update({
          'read_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', notificationId);
      } catch (_) {}
    }
  }

  Future<void> markAllAsRead() async {
    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return;
    try {
      await client
          .from('app_notifications')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('recipient_id', user.id)
          .isFilter('read_at', null);
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }
}
