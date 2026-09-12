import '../models/models.dart';

class MockData {
  static const room = Room(
    id: 'room-204',
    number: '204',
    floor: 'Second Floor',
    capacity: 4,
    occupied: 4,
    bedSpace: 'Bed 2',
    roommates: ['Bea Santos', 'Carla Reyes', 'Dianne Flores'],
    utilitySummary: 'Electricity ₱720 • Water ₱180',
  );

  static List<Payment> payments = [
    Payment(
      id: 'p1',
      label: 'August Rent',
      amount: 3500,
      dueDate: DateTime(2026, 8, 15),
      status: 'Due',
      tenantId: 'tenant-anna',
      tenantName: 'Anna Dela Cruz',
      tenantRoom: 'Room 204 • Bed 2',
      category: 'rent',
    ),
    Payment(
      id: 'p2',
      label: 'July Utilities',
      amount: 900,
      dueDate: DateTime(2026, 8, 10),
      status: 'Pending verification',
      reference: 'GCASH-0726-1045',
      paymentMethod: 'GCash',
      tenantId: 'tenant-anna',
      tenantName: 'Anna Dela Cruz',
      tenantRoom: 'Room 204 • Bed 2',
      category: 'utilities',
      paidAt: DateTime(2026, 8, 9, 14, 30),
      receiptPath: 'assets/images/room.jpg',
    ),
    Payment(
      id: 'p4',
      label: 'September Rent Advance',
      amount: 3500,
      dueDate: DateTime(2026, 9, 15),
      status: 'Pending verification',
      reference: 'BDO-0902-8831',
      paymentMethod: 'Bank Transfer',
      tenantId: 'tenant-carla',
      tenantName: 'Carla Reyes',
      tenantRoom: 'Room 204 • Bed 3',
      category: 'rent',
      paidAt: DateTime(2026, 9, 2, 10, 15),
      receiptPath: 'assets/images/dorm_overview.jpg',
    ),
    Payment(
      id: 'p3',
      label: 'July Rent',
      amount: 3500,
      dueDate: DateTime(2026, 7, 15),
      status: 'Verified',
      reference: 'GCASH-0715-0912',
      paymentMethod: 'GCash',
      tenantId: 'tenant-anna',
      tenantName: 'Anna Dela Cruz',
      tenantRoom: 'Room 204 • Bed 2',
      category: 'rent',
      paidAt: DateTime(2026, 7, 14, 16, 20),
      receiptPath: 'assets/images/exterior.jpg',
      reviewedBy: 'staff-1',
      reviewedAt: DateTime(2026, 7, 15, 9, 0),
    ),
  ];

  static List<MaintenanceReport> maintenance = [
    MaintenanceReport(
        id: 'm1',
        category: 'Plumbing',
        description: 'Slow drain in the bathroom shower area.',
        location: 'Room 204 • Bathroom',
        urgency: 'Medium',
        status: 'Ongoing',
        createdAt: DateTime(2026, 8, 6, 9, 30)),
    MaintenanceReport(
        id: 'm2',
        category: 'Electrical',
        description: 'Bedside charger port is not working.',
        location: 'Room 204 • Bed 2',
        urgency: 'Low',
        status: 'Submitted',
        createdAt: DateTime(2026, 8, 7, 18, 10)),
  ];

  static List<GeofenceEvent> gateEvents = [
    GeofenceEvent(
        id: 'g1',
        person: 'Anna Dela Cruz',
        direction: 'IN',
        time: DateTime(2026, 8, 8, 20, 14),
        verification: 'GPS Geofence confirmed',
        status: 'Verified'),
    GeofenceEvent(
        id: 'g2',
        person: 'Bea Santos',
        direction: 'OUT',
        time: DateTime(2026, 8, 8, 19, 52),
        verification: 'GPS Geofence confirmed',
        status: 'Verified'),
    GeofenceEvent(
        id: 'g3',
        person: 'Carla Reyes',
        direction: 'IN',
        time: DateTime(2026, 8, 8, 18, 30),
        verification: 'GPS Geofence confirmed',
        status: 'Verified'),
  ];

  static List<VisitorRequest> visitors = [
    VisitorRequest(
        id: 'v1',
        visitorName: 'Maria Dela Cruz',
        relationship: 'Mother',
        schedule: DateTime(2026, 8, 10, 14),
        status: 'Approved'),
  ];

  static final announcements = [
    Announcement(
        id: 'a1',
        title: 'Scheduled water interruption',
        body:
            'Water service may be interrupted from 1:00 PM to 3:00 PM on Sunday. Please store enough water beforehand.',
        createdAt: DateTime(2026, 8, 8, 10),
        audience: 'All tenants'),
    Announcement(
        id: 'a2',
        title: 'Room inspection reminder',
        body:
            'Routine room inspection is scheduled for Monday morning. Keep walkways and emergency access clear.',
        createdAt: DateTime(2026, 8, 7, 15),
        audience: 'All tenants'),
  ];

  static List<ConcernReport> concerns = [
    ConcernReport(
        id: 'r1',
        category: 'Safety concern',
        summary:
            'Repeated blocking of the second-floor corridor near the stairs.',
        status: 'Under review',
        createdAt: DateTime(2026, 8, 6)),
  ];

  static List<ChatMessage> tenantMessages = [
    ChatMessage(
      id: 'tm1',
      senderName: 'Caretaker',
      senderRole: 'ownerCaretaker',
      body: 'Your maintenance request has been received.',
      sentAt: DateTime(2026, 8, 8, 10, 15),
    ),
    ChatMessage(
      id: 'tm2',
      senderName: 'Anna Dela Cruz',
      senderRole: 'tenant',
      body: 'Thank you. Please let me know when it will be checked.',
      sentAt: DateTime(2026, 8, 8, 10, 18),
    ),
  ];

  static List<ChatMessage> guardianMessages = [
    ChatMessage(
      id: 'gm1',
      senderName: 'Caretaker',
      senderRole: 'ownerCaretaker',
      body: 'Good afternoon. Anna is currently inside the dormitory.',
      sentAt: DateTime(2026, 8, 8, 20, 16),
    ),
    ChatMessage(
      id: 'gm2',
      senderName: 'Maria Dela Cruz',
      senderRole: 'guardian',
      body: 'Thank you for the update.',
      sentAt: DateTime(2026, 8, 8, 20, 18),
    ),
  ];

  static List<TenantDirectoryEntry> tenantDirectory = const [
    TenantDirectoryEntry(
      id: 't1',
      name: 'Anna Dela Cruz',
      room: '204',
      bedSpace: 'Bed 2',
      phone: '+63 917 000 0003',
      guardianName: 'Maria Dela Cruz',
      guardianPhone: '+63 917 000 0002',
      gateStatus: 'IN',
      paymentSummary: '₱4,400 outstanding',
    ),
    TenantDirectoryEntry(
      id: 't2',
      name: 'Bea Santos',
      room: '204',
      bedSpace: 'Bed 1',
      phone: '+63 917 000 0040',
      guardianName: 'Josefina Santos',
      guardianPhone: '+63 917 000 0044',
      gateStatus: 'OUT',
      paymentSummary: 'Verified',
    ),
    TenantDirectoryEntry(
      id: 't3',
      name: 'Carla Reyes',
      room: '204',
      bedSpace: 'Bed 3',
      phone: '+63 917 000 0066',
      guardianName: 'Elena Reyes',
      guardianPhone: '+63 917 000 0091',
      gateStatus: 'IN',
      paymentSummary: '₱900 pending',
    ),
    TenantDirectoryEntry(
      id: 't4',
      name: 'Dianne Flores',
      room: '204',
      bedSpace: 'Bed 4',
      phone: '+63 917 000 0112',
      guardianName: 'Liza Flores',
      guardianPhone: '+63 917 000 0113',
      gateStatus: 'IN',
      paymentSummary: 'Verified',
    ),
    TenantDirectoryEntry(
      id: 't5',
      name: 'Ella Garcia',
      room: '105',
      bedSpace: 'Bed 1',
      phone: '+63 917 000 0134',
      guardianName: 'Grace Garcia',
      guardianPhone: '+63 917 000 0135',
      gateStatus: 'OUT',
      paymentSummary: '₱3,500 due',
    ),
    TenantDirectoryEntry(
      id: 't6',
      name: 'Faith Mendoza',
      room: '103',
      bedSpace: 'Bed 2',
      phone: '+63 917 000 0145',
      guardianName: 'Helen Mendoza',
      guardianPhone: '+63 917 000 0146',
      gateStatus: 'IN',
      paymentSummary: 'Verified',
    ),
  ];

  static List<DormRoomStatus> roomStatuses = [
    DormRoomStatus(
        roomNumber: '101',
        floor: 'Ground Floor',
        capacity: 4,
        occupied: 4,
        status: 'Full'),
    DormRoomStatus(
        roomNumber: '102',
        floor: 'Ground Floor',
        capacity: 4,
        occupied: 3,
        status: 'Available'),
    DormRoomStatus(
        roomNumber: '103',
        floor: 'Ground Floor',
        capacity: 4,
        occupied: 2,
        status: 'Available'),
    DormRoomStatus(
        roomNumber: '104',
        floor: 'Ground Floor',
        capacity: 4,
        occupied: 4,
        status: 'Full'),
    DormRoomStatus(
        roomNumber: '105',
        floor: 'Ground Floor',
        capacity: 4,
        occupied: 1,
        status: 'Available'),
    DormRoomStatus(
        roomNumber: '201',
        floor: 'Second Floor',
        capacity: 4,
        occupied: 4,
        status: 'Full'),
    DormRoomStatus(
        roomNumber: '202',
        floor: 'Second Floor',
        capacity: 4,
        occupied: 3,
        status: 'Available'),
    DormRoomStatus(
        roomNumber: '203',
        floor: 'Second Floor',
        capacity: 4,
        occupied: 2,
        status: 'Available'),
    DormRoomStatus(
        roomNumber: '204',
        floor: 'Second Floor',
        capacity: 4,
        occupied: 4,
        status: 'Full'),
    DormRoomStatus(
        roomNumber: '205',
        floor: 'Second Floor',
        capacity: 4,
        occupied: 2,
        status: 'Available'),
  ];

  static List<OwnerConversation> ownerConversations = [
    OwnerConversation(
      id: 'oc1',
      personName: 'Anna Dela Cruz',
      personRole: 'Tenant',
      messages: [
        ChatMessage(
          id: 'oc1m1',
          senderName: 'Anna Dela Cruz',
          senderRole: 'tenant',
          body: 'Thank you. Please let me know when it will be checked.',
          sentAt: DateTime(2026, 8, 8, 10, 18),
        ),
        ChatMessage(
          id: 'oc1m2',
          senderName: 'Caretaker',
          senderRole: 'ownerCaretaker',
          body: 'The plumbing report is now assigned for inspection.',
          sentAt: DateTime(2026, 8, 8, 10, 25),
        ),
      ],
    ),
    OwnerConversation(
      id: 'oc2',
      personName: 'Maria Dela Cruz',
      personRole: 'Guardian',
      messages: [
        ChatMessage(
          id: 'oc2m1',
          senderName: 'Maria Dela Cruz',
          senderRole: 'guardian',
          body: 'Thank you for the gate update.',
          sentAt: DateTime(2026, 8, 8, 20, 18),
        ),
      ],
    ),
    OwnerConversation(
      id: 'oc3',
      personName: 'Bea Santos',
      personRole: 'Tenant',
      messages: [
        ChatMessage(
          id: 'oc3m1',
          senderName: 'Bea Santos',
          senderRole: 'tenant',
          body: 'I uploaded my utility payment proof.',
          sentAt: DateTime(2026, 8, 8, 15, 30),
        ),
      ],
    ),
  ];

  static final notifications = [
    AppNotification(
        title: 'Payment reminder',
        body: 'August rent is due on August 15.',
        time: DateTime(2026, 8, 8, 9),
        type: 'Payment'),
    AppNotification(
        title: 'Maintenance update',
        body: 'Your plumbing report is now marked Ongoing.',
        time: DateTime(2026, 8, 8, 11, 20),
        type: 'Maintenance'),
    AppNotification(
        title: 'Geofence arrival',
        body:
            'Anna Dela Cruz arrived at Carmelita\'s Dormitory (GPS verified).',
        time: DateTime(2026, 8, 8, 20, 14),
        type: 'Geofence'),
  ];
}
