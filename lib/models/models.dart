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
