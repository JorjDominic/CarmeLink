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

class GeofenceEvent {
  const GeofenceEvent({
    required this.id,
    required this.person,
    required this.direction,
    required this.time,
    required this.verification,
    required this.status,
  });

  final String id;
  final String person;
  final String direction;
  final DateTime time;
  final String verification;
  final String status;
}

typedef GateEvent = GeofenceEvent;

class VisitorRequest {
  VisitorRequest({
    required this.id,
    required this.visitorName,
    required this.relationship,
    required this.schedule,
    required this.status,
  });

  final String id;
  final String visitorName;
  final String relationship;
  final DateTime schedule;
  String status;
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
  });

  final String id;
  final String category;
  final String summary;
  String status;
  final DateTime createdAt;
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
  });

  final String id;
  final String senderName;
  final String senderRole;
  final String body;
  final DateTime sentAt;
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
      guardianRemarks: (json['guardian_remarks'] ?? json['guardian_notes']) as String?,
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
