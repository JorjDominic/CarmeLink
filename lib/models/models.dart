enum UserRole { tenant, guardian, caretaker, owner }

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone = '',
  });

  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String phone;
}

class Roommate {
  const Roommate({
    required this.name,
    required this.bed,
    this.isSelf = false,
  });

  factory Roommate.fromJson(Map<String, dynamic> json) => Roommate(
        name: json['name'] as String? ?? 'Resident',
        bed: json['bed'] as String? ?? '',
        isSelf: json['is_self'] as bool? ?? false,
      );

  final String name;
  final String bed;
  final bool isSelf;
}

class Room {
  const Room({
    required this.id,
    required this.number,
    required this.floor,
    required this.capacity,
    required this.occupied,
    required this.bedSpace,
    required this.roommates,
    required this.utilitySummary,
    this.description = '',
    this.roommateDetails = const [],
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    final rawRoommates = json['roommates'] as List<dynamic>? ?? const [];
    final roommateList = <Roommate>[];
    final roommateNames = <String>[];
    for (final item in rawRoommates) {
      if (item is Map<String, dynamic>) {
        final r = Roommate.fromJson(item);
        roommateList.add(r);
        if (!r.isSelf) {
          roommateNames.add(r.name);
        }
      } else if (item is String) {
        roommateNames.add(item);
        roommateList.add(Roommate(name: item, bed: ''));
      }
    }

    return Room(
      id: json['room_id'] as String? ?? json['id'] as String? ?? '',
      number: json['room_number'] as String? ?? json['number'] as String? ?? '',
      floor: json['floor'] as String? ?? '',
      capacity: (json['capacity'] as num?)?.toInt() ?? 4,
      occupied: (json['occupied'] as num?)?.toInt() ?? 0,
      bedSpace:
          json['bed_space'] as String? ?? json['bedSpace'] as String? ?? '',
      description: json['description'] as String? ?? '',
      utilitySummary: json['utility_summary'] as String? ??
          json['utilitySummary'] as String? ??
          'Electricity & water included • Submetered AC',
      roommates: roommateNames,
      roommateDetails: roommateList,
    );
  }

  final String id;
  final String number;
  final String floor;
  final int capacity;
  final int occupied;
  final String bedSpace;
  final List<String> roommates;
  final String utilitySummary;
  final String description;
  final List<Roommate> roommateDetails;
}

class Payment {
  Payment({
    required this.id,
    required this.label,
    required this.amount,
    required this.dueDate,
    required this.status,
    this.reference,
    this.tenantId = '',
    this.tenantName,
    this.tenantRoom,
    this.category = 'rent',
    this.paymentMethod,
    this.receiptPath,
    this.paidAt,
    this.reviewedBy,
    this.reviewedAt,
    this.reviewNotes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? dueDate;

  final String id;
  final String tenantId;
  final String? tenantName;
  final String? tenantRoom;
  final String label;
  final String category;
  final double amount;
  final DateTime dueDate;
  String status;
  final String? paymentMethod;
  final String? reference;
  final String? receiptPath;
  final DateTime? paidAt;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? reviewNotes;
  final DateTime createdAt;

  bool get isPending => status.toLowerCase().contains('pending');
  bool get isVerified => status.toLowerCase().contains('verified');
  bool get isRejected => status.toLowerCase().contains('rejected');
  bool get isDue => status.toLowerCase() == 'due';

  bool get isOverdue {
    if (!isDue) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return due.isBefore(today);
  }

  bool get canSubmitProof => isDue || isRejected;

  String get formattedAmount => '₱${amount.toStringAsFixed(2)}';

  Payment copyWith({
    String? id,
    String? tenantId,
    String? tenantName,
    String? tenantRoom,
    String? label,
    String? category,
    double? amount,
    DateTime? dueDate,
    String? status,
    String? paymentMethod,
    String? reference,
    String? receiptPath,
    DateTime? paidAt,
    String? reviewedBy,
    DateTime? reviewedAt,
    String? reviewNotes,
    DateTime? createdAt,
  }) {
    return Payment(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      tenantName: tenantName ?? this.tenantName,
      tenantRoom: tenantRoom ?? this.tenantRoom,
      label: label ?? this.label,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      reference: reference ?? this.reference,
      receiptPath: receiptPath ?? this.receiptPath,
      paidAt: paidAt ?? this.paidAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewNotes: reviewNotes ?? this.reviewNotes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static String formatStatus(String raw) {
    return switch (raw.toLowerCase().replaceAll(' ', '_')) {
      'pending_verification' ||
      'pending_review' ||
      'pending' =>
        'Pending verification',
      'verified' || 'paid' || 'approved' => 'Verified',
      'rejected' => 'Rejected',
      _ => 'Due',
    };
  }

  static String toDbStatus(String ui) {
    return switch (ui.toLowerCase().replaceAll(' ', '_')) {
      'pending_verification' ||
      'pending_review' ||
      'pending' =>
        'pending_verification',
      'verified' || 'paid' || 'approved' => 'verified',
      'rejected' => 'rejected',
      _ => 'due',
    };
  }

  factory Payment.fromJson(
    Map<String, dynamic> json, {
    String? tenantName,
    String? tenantRoom,
  }) {
    final rawDueDate = json['due_date'];
    final DateTime parsedDueDate;
    if (rawDueDate is String) {
      parsedDueDate = DateTime.tryParse(rawDueDate) ?? DateTime.now();
    } else {
      parsedDueDate = DateTime.now();
    }

    final rawCreatedAt = json['created_at'];
    final DateTime? parsedCreatedAt =
        rawCreatedAt is String ? DateTime.tryParse(rawCreatedAt) : null;

    final rawPaidAt = json['paid_at'];
    final DateTime? parsedPaidAt =
        rawPaidAt is String ? DateTime.tryParse(rawPaidAt) : null;

    final rawReviewedAt = json['reviewed_at'];
    final DateTime? parsedReviewedAt =
        rawReviewedAt is String ? DateTime.tryParse(rawReviewedAt) : null;

    final rawAmount = json['amount'];
    final double parsedAmount = rawAmount is num
        ? rawAmount.toDouble()
        : double.tryParse(rawAmount?.toString() ?? '') ?? 0.0;

    final rawStatus = json['status'] as String? ?? 'due';

    return Payment(
      id: json['id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      tenantName: tenantName ?? json['tenant_name'] as String?,
      tenantRoom: tenantRoom ?? json['tenant_room'] as String?,
      label: json['title'] as String? ?? json['label'] as String? ?? 'Payment',
      category: json['category'] as String? ?? 'rent',
      amount: parsedAmount,
      dueDate: parsedDueDate,
      status: formatStatus(rawStatus),
      paymentMethod: json['payment_method'] as String?,
      reference:
          json['reference_number'] as String? ?? json['reference'] as String?,
      receiptPath: json['receipt_path'] as String?,
      paidAt: parsedPaidAt,
      reviewedBy: json['reviewed_by'] as String?,
      reviewedAt: parsedReviewedAt,
      reviewNotes: json['review_notes'] as String?,
      createdAt: parsedCreatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenant_id': tenantId,
        'title': label,
        'category': category,
        'amount': amount,
        'due_date':
            '${dueDate.year.toString().padLeft(4, '0')}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}',
        'status': toDbStatus(status),
        if (paymentMethod != null) 'payment_method': paymentMethod,
        if (reference != null) 'reference_number': reference,
        if (receiptPath != null) 'receipt_path': receiptPath,
        if (paidAt != null) 'paid_at': paidAt!.toIso8601String(),
        if (reviewedBy != null) 'reviewed_by': reviewedBy,
        if (reviewedAt != null) 'reviewed_at': reviewedAt!.toIso8601String(),
        if (reviewNotes != null) 'review_notes': reviewNotes,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Payment && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class MaintenanceReport {
  MaintenanceReport({
    required this.id,
    required this.category,
    required this.description,
    required this.location,
    required this.urgency,
    required this.status,
    required this.createdAt,
    this.photoPath,
    this.notes = '',
    this.staffNotes = '',
    this.resolvedAt,
  });

  final String id;
  final String category;
  final String description;
  final String location;
  final String urgency;
  String status;
  final DateTime createdAt;
  final String? photoPath;
  String notes;
  final String staffNotes;
  final DateTime? resolvedAt;

  bool get isPending => status.trim().toLowerCase() == 'pending';
  bool get isAssigned => status.trim().toLowerCase() == 'assigned';
  bool get isInProgress {
    final s = status.trim().toLowerCase();
    return s == 'in progress' || s == 'in_progress';
  }

  bool get isResolved => status.trim().toLowerCase() == 'resolved';
  bool get isCancelled => status.trim().toLowerCase() == 'cancelled';

  bool get canCancel => isPending;
  bool get canEdit => isPending;

  MaintenanceReport copyWith({
    String? id,
    String? category,
    String? description,
    String? location,
    String? urgency,
    String? status,
    DateTime? createdAt,
    String? photoPath,
    String? notes,
    String? staffNotes,
    DateTime? resolvedAt,
  }) {
    return MaintenanceReport(
      id: id ?? this.id,
      category: category ?? this.category,
      description: description ?? this.description,
      location: location ?? this.location,
      urgency: urgency ?? this.urgency,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      photoPath: photoPath ?? this.photoPath,
      notes: notes ?? this.notes,
      staffNotes: staffNotes ?? this.staffNotes,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MaintenanceReport &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class GateEvent {
  const GateEvent({
    required this.id,
    required this.person,
    this.tenantId,
    this.direction,
    required this.time,
    required this.verification,
    required this.status,
    this.checkpointType = 'on_demand',
    this.notes,
    this.createdByName,
  });

  factory GateEvent.fromRow(Map<String, dynamic> row) {
    final profile =
        (row['profiles'] ?? row['user_profiles']) as Map<String, dynamic>?;
    final creator = row['creator'] as Map<String, dynamic>?;
    final checkedAtStr =
        row['checked_at'] as String? ?? row['created_at'] as String?;
    final time =
        checkedAtStr != null ? DateTime.parse(checkedAtStr) : DateTime.now();
    final direction = row['direction'] as String?;
    final status = row['status'] as String? ?? 'Verified';
    final verificationMethod =
        row['verification_method'] as String? ?? 'GPS Geofence';

    return GateEvent(
      id: row['id'] as String,
      tenantId: row['tenant_id'] as String?,
      person: profile?['full_name'] as String? ?? 'Tenant',
      direction: direction,
      time: time,
      verification: verificationMethod,
      status: status,
      checkpointType: row['checkpoint_type'] as String? ?? 'on_demand',
      notes: row['notes'] as String?,
      createdByName: creator?['full_name'] as String?,
    );
  }

  final String id;
  final String? tenantId;
  final String person;
  final String? direction;
  final DateTime time;
  final String verification;
  final String status;
  final String checkpointType;
  final String? notes;
  final String? createdByName;

  DateTime get checkedAt => time;
  String get verificationMethod => verification;

  bool get isInside => direction == 'IN';
  bool get isOutside => direction == 'OUT';
  bool get isUnavailable => status == 'UNAVAILABLE';
  bool get isFlagged => status == 'Flagged';
  bool get isVerified => status == 'Verified';
  bool get isManualLog => verification == 'Staff Manual Log';
}

typedef GeofenceEvent = GateEvent;

class VisitorRequest {
  const VisitorRequest({
    required this.id,
    required this.visitorName,
    required this.relationship,
    required this.schedule,
    required this.status,
    this.tenantId = '',
    this.tenantName = '',
    this.purpose = '',
    this.contactNumber = '',
    this.expectedDepartureAt,
    this.reviewNote,
    this.decidedBy,
    this.decidedAt,
    this.arrivedAt,
    this.departedAt,
    this.createdAt,
  });

  final String id;
  final String tenantId;
  final String tenantName;
  final String visitorName;
  final String relationship;
  final String purpose;
  final String contactNumber;
  final DateTime schedule;
  final DateTime? expectedDepartureAt;
  final String status;
  final String? reviewNote;
  final String? decidedBy;
  final DateTime? decidedAt;
  final DateTime? arrivedAt;
  final DateTime? departedAt;
  final DateTime? createdAt;

  bool get isPending => status.toLowerCase() == 'pending';
  bool get isApproved => status.toLowerCase() == 'approved';
  bool get isRejected => status.toLowerCase() == 'rejected';
  bool get isCancelled => status.toLowerCase() == 'cancelled';
  bool get hasArrived => status.toLowerCase() == 'arrived';
  bool get isCompleted => status.toLowerCase() == 'completed';

  String get statusLabel => status
      .split('_')
      .map((part) => part.isEmpty
          ? part
          : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
      .join(' ');

  factory VisitorRequest.fromRow(Map<String, dynamic> row) {
    final tenant = row['tenant'];
    final tenantName = tenant is Map
        ? tenant['full_name'] as String? ?? ''
        : row['tenant_name'] as String? ?? '';
    return VisitorRequest(
      id: row['id'] as String,
      tenantId: row['tenant_id'] as String? ?? '',
      tenantName: tenantName,
      visitorName: row['visitor_name'] as String? ?? '',
      relationship: row['relationship'] as String? ?? '',
      purpose: row['purpose'] as String? ?? '',
      contactNumber: row['contact_number'] as String? ?? '',
      schedule: DateTime.parse(row['schedule'] as String).toLocal(),
      expectedDepartureAt: _optionalLocalDate(row['expected_departure_at']),
      status: row['status'] as String? ?? 'pending',
      reviewNote: row['review_note'] as String?,
      decidedBy: row['decided_by'] as String?,
      decidedAt: _optionalLocalDate(row['decided_at']),
      arrivedAt: _optionalLocalDate(row['arrived_at']),
      departedAt: _optionalLocalDate(row['departed_at']),
      createdAt: _optionalLocalDate(row['created_at']),
    );
  }

  static DateTime? _optionalLocalDate(dynamic value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;
}

class VisitorEvent {
  const VisitorEvent({
    required this.id,
    required this.requestId,
    required this.eventType,
    required this.actorId,
    required this.occurredAt,
    this.actorName = '',
    this.note,
  });

  final String id;
  final String requestId;
  final String eventType;
  final String actorId;
  final String actorName;
  final String? note;
  final DateTime occurredAt;

  String get eventLabel => eventType == 'departed'
      ? 'Departed'
      : '${eventType[0].toUpperCase()}${eventType.substring(1)}';

  factory VisitorEvent.fromRow(Map<String, dynamic> row) {
    final actor = row['actor'];
    return VisitorEvent(
      id: row['id'] as String,
      requestId: row['request_id'] as String,
      eventType: row['event_type'] as String,
      actorId: row['actor_id'] as String,
      actorName: actor is Map ? actor['full_name'] as String? ?? '' : '',
      note: row['note'] as String?,
      occurredAt: DateTime.parse(row['occurred_at'] as String).toLocal(),
    );
  }
}

class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.audience,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final String audience;
}

class ConcernReport {
  ConcernReport({
    required this.id,
    required this.category,
    required this.summary,
    required this.status,
    required this.createdAt,
    this.tenantId = '',
    this.tenantName = 'Confidential tenant',
    this.responseNotes = '',
    this.reviewedAt,
  });

  final String id;
  final String category;
  final String summary;
  String status;
  final DateTime createdAt;
  final String tenantId;
  final String tenantName;
  final String responseNotes;
  final DateTime? reviewedAt;

  bool get isSubmitted => status.toLowerCase() == 'submitted';
  bool get isResolved => status.toLowerCase() == 'resolved';

  factory ConcernReport.fromRow(Map<String, dynamic> row) {
    final rawCategory = row['category'] as String? ?? 'other';
    final category = rawCategory
        .split('_')
        .map((part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
    final rawStatus = row['status'] as String? ?? 'submitted';
    final status = rawStatus
        .split('_')
        .map((part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
    return ConcernReport(
      id: row['id'] as String,
      tenantId: row['tenant_id'] as String? ?? '',
      tenantName: row['tenant_name'] as String? ?? 'Confidential tenant',
      category: category,
      summary: row['summary'] as String? ?? '',
      status: status,
      responseNotes: row['response_notes'] as String? ?? '',
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      reviewedAt: row['reviewed_at'] == null
          ? null
          : DateTime.tryParse(row['reviewed_at'] as String)?.toLocal(),
    );
  }
}

class AppNotification {
  const AppNotification({
    required this.title,
    required this.body,
    required this.time,
    required this.type,
  });

  final String title;
  final String body;
  final DateTime time;
  final String type;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderName,
    required this.senderRole,
    required this.body,
    required this.sentAt,
    this.conversationId = '',
    this.senderId = '',
    this.isRead = false,
    this.readAt,
  });

  final String id;
  final String senderName;
  final String senderRole;
  final String body;
  final DateTime sentAt;
  final String conversationId;
  final String senderId;
  final bool isRead;
  final DateTime? readAt;

  bool isMine(String? currentUserId) {
    if (currentUserId == null || currentUserId.isEmpty) return false;
    return senderId == currentUserId;
  }

  factory ChatMessage.fromRow(
    Map<String, dynamic> row, {
    String? currentUserId,
  }) {
    final profile = row['profiles'] as Map<String, dynamic>?;
    final senderName = profile?['full_name'] as String? ??
        row['sender_name'] as String? ??
        'User';
    final role = profile?['role'] as String? ??
        row['sender_role'] as String? ??
        'tenant';

    return ChatMessage(
      id: row['id'] as String,
      conversationId: row['conversation_id'] as String? ?? '',
      senderId: row['sender_id'] as String? ?? '',
      senderName: senderName,
      senderRole: role,
      body: row['body'] as String? ?? '',
      isRead: row['is_read'] as bool? ?? false,
      readAt: row['read_at'] == null
          ? null
          : DateTime.parse(row['read_at'] as String).toLocal(),
      sentAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String).toLocal()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toInsertRow() {
    return {
      'conversation_id': conversationId,
      'sender_id': senderId,
      'sender_role': senderRole,
      'body': body,
      'is_read': isRead,
    };
  }

  ChatMessage copyWith({bool? isRead, DateTime? readAt}) => ChatMessage(
        id: id,
        senderName: senderName,
        senderRole: senderRole,
        body: body,
        sentAt: sentAt,
        conversationId: conversationId,
        senderId: senderId,
        isRead: isRead ?? this.isRead,
        readAt: readAt ?? this.readAt,
      );
}

class ConversationRecord {
  const ConversationRecord({
    required this.id,
    required this.type,
    this.tenantId,
    this.guardianId,
    this.title = '',
    this.subtitle = '',
    this.participantName = '',
    this.participantRole = '',
    this.roomNumber,
    this.bedSpace,
    this.lastMessagePreview,
    this.lastMessageAt,
    this.unreadCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String
      type; // 'tenant_management', 'guardian_management', 'internal_staff'
  final String? tenantId;
  final String? guardianId;
  final String title;
  final String subtitle;
  final String participantName;
  final String participantRole;
  final String? roomNumber;
  final String? bedSpace;
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isInternalStaff => type == 'internal_staff';
  bool get isTenantManagement => type == 'tenant_management';
  bool get isGuardianManagement => type == 'guardian_management';

  factory ConversationRecord.fromRow(
    Map<String, dynamic> row, {
    String? currentUserId,
    String? currentRole,
  }) {
    final type = row['type'] as String? ?? 'tenant_management';
    final tenantProfile = row['tenant_profile'] as Map<String, dynamic>?;
    final guardianProfile = row['guardian_profile'] as Map<String, dynamic>?;

    String participantName = '';
    String participantRole = '';
    String title = '';
    String subtitle = '';
    String? roomNumber;
    String? bedSpace;

    if (type == 'internal_staff') {
      title = 'Staff Channel';
      subtitle = 'Owner & Caretaker Coordination';
      participantName = 'Staff Room';
      participantRole = 'Staff Only';
    } else if (type == 'guardian_management') {
      final gName = guardianProfile?['full_name'] as String? ?? 'Guardian';
      final tName = tenantProfile?['full_name'] as String?;
      participantName = gName;
      participantRole = 'Guardian';
      title = gName;
      subtitle = tName != null && tName.isNotEmpty
          ? 'Guardian of $tName'
          : 'Guardian Inquiry';
    } else {
      // tenant_management
      final tName = tenantProfile?['full_name'] as String? ?? 'Tenant';
      participantName = tName;
      participantRole = 'Tenant';
      title = tName;
      subtitle = 'Resident';

      final assignment = tenantProfile?['assignment'] as Map<String, dynamic>?;
      if (assignment != null) {
        roomNumber = assignment['room_number'] as String?;
        bedSpace = assignment['bed_space'] as String?;
        if (roomNumber != null) {
          subtitle =
              'Room $roomNumber${bedSpace != null ? ' ($bedSpace)' : ''}';
        }
      }
    }

    if (currentRole == 'tenant' || currentRole == 'guardian') {
      title = 'Dormitory Management';
      subtitle = 'Owner & Caretaker';
    }

    DateTime? lastMsgAt;
    if (row['last_message_at'] != null) {
      lastMsgAt = DateTime.parse(row['last_message_at'] as String).toLocal();
    }

    return ConversationRecord(
      id: row['id'] as String,
      type: type,
      tenantId: row['tenant_id'] as String?,
      guardianId: row['guardian_id'] as String?,
      title: title,
      subtitle: subtitle,
      participantName: participantName,
      participantRole: participantRole,
      roomNumber: roomNumber,
      bedSpace: bedSpace,
      lastMessagePreview: row['last_message_preview'] as String?,
      lastMessageAt: lastMsgAt,
      unreadCount: (row['unread_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
    );
  }
}

class DormRoomStatus {
  DormRoomStatus({
    required this.roomNumber,
    required this.floor,
    required this.capacity,
    required this.occupied,
    required this.status,
  });

  final String roomNumber;
  final String floor;
  final int capacity;
  int occupied;
  String status;

  int get available => capacity - occupied;
}

class TenantDirectoryEntry {
  const TenantDirectoryEntry({
    required this.id,
    required this.name,
    required this.room,
    required this.bedSpace,
    required this.phone,
    required this.guardianName,
    required this.guardianPhone,
    this.residencyStatus = 'active',
    this.gateStatus = 'Unavailable',
    this.paymentSummary = 'Unavailable',
    this.assignmentId,
    this.contractStartsOn,
    this.contractEndsOn,
    this.lastGateEventAt,
    this.hasContract,
  });

  final String id;
  final String name;
  final String room;
  final String bedSpace;
  final String phone;
  final String guardianName;
  final String guardianPhone;
  final String residencyStatus;
  final String gateStatus;
  final String paymentSummary;
  final String? assignmentId;
  final DateTime? contractStartsOn;
  final DateTime? contractEndsOn;
  final DateTime? lastGateEventAt;
  final bool? hasContract;

  bool get isInside => gateStatus == 'IN' || gateStatus == 'Inside';
  bool get isOutside => gateStatus == 'OUT' || gateStatus == 'Outside';
  bool get isUnavailable =>
      gateStatus == 'UNAVAILABLE' || gateStatus == 'Unavailable';
}

class TenantContract {
  const TenantContract({
    required this.id,
    required this.tenantId,
    required this.tenantName,
    required this.contractNumber,
    required this.startsOn,
    required this.endsOn,
    required this.monthlyRent,
    required this.securityDeposit,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.notes,
    this.signatureStatus = 'not_generated',
  });

  factory TenantContract.fromRow(Map<String, dynamic> row) {
    final profile = row['profiles'] as Map<String, dynamic>?;
    return TenantContract(
      id: row['id'] as String,
      tenantId: row['tenant_id'] as String,
      tenantName: profile?['full_name'] as String? ?? 'Unknown tenant',
      contractNumber: row['contract_number'] as String,
      startsOn: DateTime.parse(row['starts_on'] as String),
      endsOn: DateTime.parse(row['ends_on'] as String),
      monthlyRent: (row['monthly_rent'] as num).toDouble(),
      securityDeposit: (row['security_deposit'] as num).toDouble(),
      status: row['status'] as String,
      notes: row['notes'] as String?,
      signatureStatus: row['signature_status'] as String? ?? 'not_generated',
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  final String id;
  final String tenantId;
  final String tenantName;
  final String contractNumber;
  final DateTime startsOn;
  final DateTime endsOn;
  final double monthlyRent;
  final double securityDeposit;
  final String status;
  final String? notes;
  final String signatureStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isActive => status == 'active';
  bool get isExpired => status == 'expired' || endsOn.isBefore(DateTime.now());

  TenantContract copyWith({
    String? tenantId,
    String? tenantName,
    String? contractNumber,
    DateTime? startsOn,
    DateTime? endsOn,
    double? monthlyRent,
    double? securityDeposit,
    String? status,
    String? notes,
    String? signatureStatus,
  }) =>
      TenantContract(
        id: id,
        tenantId: tenantId ?? this.tenantId,
        tenantName: tenantName ?? this.tenantName,
        contractNumber: contractNumber ?? this.contractNumber,
        startsOn: startsOn ?? this.startsOn,
        endsOn: endsOn ?? this.endsOn,
        monthlyRent: monthlyRent ?? this.monthlyRent,
        securityDeposit: securityDeposit ?? this.securityDeposit,
        status: status ?? this.status,
        notes: notes ?? this.notes,
        signatureStatus: signatureStatus ?? this.signatureStatus,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

class ContractDocument {
  const ContractDocument({
    required this.id,
    required this.contractId,
    required this.version,
    required this.documentType,
    required this.storagePath,
    required this.originalFilename,
    required this.mimeType,
    required this.sizeBytes,
    required this.sha256,
    required this.reviewStatus,
    required this.uploadedAt,
    this.reviewedAt,
    this.reviewNotes,
  });

  factory ContractDocument.fromRow(Map<String, dynamic> row) =>
      ContractDocument(
        id: row['id'] as String,
        contractId: row['contract_id'] as String,
        version: row['version'] as int,
        documentType: row['document_type'] as String,
        storagePath: row['storage_path'] as String,
        originalFilename: row['original_filename'] as String,
        mimeType: row['mime_type'] as String,
        sizeBytes: (row['size_bytes'] as num).toInt(),
        sha256: row['sha256'] as String,
        reviewStatus: row['review_status'] as String,
        uploadedAt: DateTime.parse(row['uploaded_at'] as String),
        reviewedAt: row['reviewed_at'] == null
            ? null
            : DateTime.parse(row['reviewed_at'] as String),
        reviewNotes: row['review_notes'] as String?,
      );

  final String id;
  final String contractId;
  final int version;
  final String documentType;
  final String storagePath;
  final String originalFilename;
  final String mimeType;
  final int sizeBytes;
  final String sha256;
  final String reviewStatus;
  final DateTime uploadedAt;
  final DateTime? reviewedAt;
  final String? reviewNotes;

  bool get isGenerated => documentType == 'generated';
  bool get isSigned => documentType == 'signed';
  bool get isPending => reviewStatus == 'pending';
}

class OwnerConversation {
  OwnerConversation({
    required this.id,
    required this.personName,
    required this.personRole,
    required this.messages,
  });

  final String id;
  final String personName;
  final String personRole;
  final List<ChatMessage> messages;
}

class LinkedTenant {
  const LinkedTenant({
    required this.linkId,
    required this.tenantId,
    required this.name,
    required this.phone,
    required this.relationship,
    this.email = '',
    this.isPrimary = false,
    this.schoolName = '',
    this.courseOrProgram = '',
    this.yearLevel,
    this.emergencyContactName = '',
    this.emergencyContactPhone = '',
    this.residencyStatus = 'active',
  });

  final String linkId;
  final String tenantId;
  final String name;
  final String phone;
  final String email;
  final String relationship;
  final bool isPrimary;
  final String schoolName;
  final String courseOrProgram;
  final int? yearLevel;
  final String emergencyContactName;
  final String emergencyContactPhone;
  final String residencyStatus;

  String get educationSummary {
    final parts = <String>[];
    if (courseOrProgram.isNotEmpty) parts.add(courseOrProgram);
    if (yearLevel != null) parts.add('Year $yearLevel');
    if (schoolName.isNotEmpty) parts.add(schoolName);
    return parts.isEmpty ? 'Not specified' : parts.join(' • ');
  }
}

class CurfewRequest {
  CurfewRequest({
    required this.id,
    required this.tenantId,
    required this.destination,
    required this.reason,
    required this.departureTime,
    required this.expectedReturnTime,
    required this.status,
    this.requestType = 'late_return',
    this.tenantName,
    this.guardianId,
    this.guardianDecision,
    this.guardianRemarks,
    this.guardianDecidedAt,
    this.staffId,
    this.staffDecision,
    this.staffNotes,
    this.staffDecidedAt,
    this.actualReturnTime,
    this.createdAt,
    this.updatedAt,
  });

  factory CurfewRequest.fromJson(Map<String, dynamic> json) {
    final tenantObj = json['tenant'] as Map<String, dynamic>?;

    return CurfewRequest(
      id: json['id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      destination: json['destination'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      departureTime:
          DateTime.tryParse(json['departure_time']?.toString() ?? '') ??
              DateTime.now(),
      expectedReturnTime:
          DateTime.tryParse(json['expected_return_time']?.toString() ?? '') ??
              DateTime.now().add(const Duration(hours: 4)),
      status: json['status'] as String? ?? 'pending_guardian',
      requestType: json['request_type'] as String? ?? 'late_return',
      tenantName: tenantObj?['full_name'] as String?,
      guardianId: json['guardian_id'] as String?,
      guardianDecision: json['guardian_decision'] as String?,
      guardianRemarks:
          (json['guardian_remarks'] ?? json['guardian_notes']) as String?,
      guardianDecidedAt: json['guardian_decided_at'] != null
          ? DateTime.tryParse(json['guardian_decided_at'].toString())
          : null,
      staffId: json['staff_id'] as String?,
      staffDecision: json['staff_decision'] as String?,
      staffNotes: json['staff_notes'] as String?,
      staffDecidedAt: json['staff_decided_at'] != null
          ? DateTime.tryParse(json['staff_decided_at'].toString())
          : null,
      actualReturnTime: json['actual_return_time'] != null
          ? DateTime.tryParse(json['actual_return_time'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  final String id;
  final String tenantId;
  final String destination;
  final String reason;
  final DateTime departureTime;
  final DateTime expectedReturnTime;
  String status;
  final String requestType;
  final String? tenantName;
  final String? guardianId;
  final String? guardianDecision;
  final String? guardianRemarks;
  final DateTime? guardianDecidedAt;
  final String? staffId;
  final String? staffDecision;
  final String? staffNotes;
  final DateTime? staffDecidedAt;
  final DateTime? actualReturnTime;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String? get guardianNotes => guardianRemarks;

  bool get isLateReturn => requestType == 'late_return';
  bool get isOvernightLeave => requestType == 'overnight_leave';
  String get requestTypeLabel =>
      isOvernightLeave ? 'Overnight Leave' : 'Late Return';

  bool get isPending =>
      status == 'pending_guardian' || status == 'pending_staff';
  bool get isPendingGuardian => status == 'pending_guardian';
  bool get isPendingStaff => status == 'pending_staff';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isCancelled => status == 'cancelled';
  bool get isCompleted => status == 'completed';

  bool get canCancel =>
      status == 'pending_guardian' || status == 'pending_staff';
  bool get canReviewGuardian => status == 'pending_guardian';
  bool get canReviewStaff => status == 'pending_staff';

  String get statusLabel {
    switch (status) {
      case 'pending_guardian':
        return 'Awaiting Guardian';
      case 'pending_staff':
        return 'Awaiting Staff';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'cancelled':
        return 'Cancelled';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenant_id': tenantId,
        'destination': destination,
        'reason': reason,
        'departure_time': departureTime.toIso8601String(),
        'expected_return_time': expectedReturnTime.toIso8601String(),
        'status': status,
        'request_type': requestType,
        if (guardianId != null) 'guardian_id': guardianId,
        if (guardianDecision != null) 'guardian_decision': guardianDecision,
        if (guardianRemarks != null) 'guardian_remarks': guardianRemarks,
        if (guardianDecidedAt != null)
          'guardian_decided_at': guardianDecidedAt!.toIso8601String(),
        if (staffId != null) 'staff_id': staffId,
        if (staffDecision != null) 'staff_decision': staffDecision,
        if (staffNotes != null) 'staff_notes': staffNotes,
        if (staffDecidedAt != null)
          'staff_decided_at': staffDecidedAt!.toIso8601String(),
        if (actualReturnTime != null)
          'actual_return_time': actualReturnTime!.toIso8601String(),
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      };

  CurfewRequest copyWith({
    String? id,
    String? tenantId,
    String? destination,
    String? reason,
    DateTime? departureTime,
    DateTime? expectedReturnTime,
    String? status,
    String? requestType,
    String? tenantName,
    String? guardianId,
    String? guardianDecision,
    String? guardianRemarks,
    String? guardianNotes,
    DateTime? guardianDecidedAt,
    String? staffId,
    String? staffDecision,
    String? staffNotes,
    DateTime? staffDecidedAt,
    DateTime? actualReturnTime,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CurfewRequest(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      destination: destination ?? this.destination,
      reason: reason ?? this.reason,
      departureTime: departureTime ?? this.departureTime,
      expectedReturnTime: expectedReturnTime ?? this.expectedReturnTime,
      status: status ?? this.status,
      requestType: requestType ?? this.requestType,
      tenantName: tenantName ?? this.tenantName,
      guardianId: guardianId ?? this.guardianId,
      guardianDecision: guardianDecision ?? this.guardianDecision,
      guardianRemarks: guardianRemarks ?? guardianNotes ?? this.guardianRemarks,
      guardianDecidedAt: guardianDecidedAt ?? this.guardianDecidedAt,
      staffId: staffId ?? this.staffId,
      staffDecision: staffDecision ?? this.staffDecision,
      staffNotes: staffNotes ?? this.staffNotes,
      staffDecidedAt: staffDecidedAt ?? this.staffDecidedAt,
      actualReturnTime: actualReturnTime ?? this.actualReturnTime,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
