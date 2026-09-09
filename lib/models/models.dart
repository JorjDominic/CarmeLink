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
  });

  final String id;
  final String number;
  final String floor;
  final int capacity;
  final int occupied;
  final String bedSpace;
  final List<String> roommates;
  final String utilitySummary;
}

class Payment {
  Payment({
    required this.id,
    required this.label,
    required this.amount,
    required this.dueDate,
    required this.status,
    this.reference,
  });

  final String id;
  final String label;
  final double amount;
  final DateTime dueDate;
  String status;
  final String? reference;
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

class GateEvent {
  const GateEvent({
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

class CurfewRequest {
  CurfewRequest({
    required this.id,
    required this.tenantName,
    required this.reason,
    required this.destination,
    required this.expectedReturn,
    required this.guardianStatus,
    required this.ownerStatus,
  });

  final String id;
  final String tenantName;
  final String reason;
  final String destination;
  final DateTime expectedReturn;
  String guardianStatus;
  String ownerStatus;
}

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

class DeviceStatus {
  const DeviceStatus({
    required this.name,
    required this.status,
    required this.detail,
  });

  final String name;
  final String status;
  final String detail;
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
    required this.gateStatus,
    required this.paymentSummary,
  });

  final String id;
  final String name;
  final String room;
  final String bedSpace;
  final String phone;
  final String guardianName;
  final String guardianPhone;
  final String gateStatus;
  final String paymentSummary;
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

class GateReviewRecord {
  GateReviewRecord({
    required this.id,
    required this.event,
    required this.reviewStatus,
    this.note = '',
  });

  final String id;
  final GateEvent event;
  String reviewStatus;
  String note;
}
