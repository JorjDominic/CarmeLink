import 'package:flutter_test/flutter_test.dart';
import 'package:carmelitas_dormitory_system/models/models.dart';

void main() {
  group('ChatMessage Model', () {
    final now = DateTime(2026, 9, 19, 10, 30);

    test('instantiates with default values and isMine works', () {
      final msg = ChatMessage(
        id: 'msg-1',
        senderName: 'Anna Dela Cruz',
        senderRole: 'tenant',
        body: 'Hello Caretaker',
        sentAt: now,
        senderId: 'user-anna',
        conversationId: 'conv-123',
      );

      expect(msg.id, 'msg-1');
      expect(msg.conversationId, 'conv-123');
      expect(msg.senderId, 'user-anna');
      expect(msg.isMine('user-anna'), isTrue);
      expect(msg.isMine('user-other'), isFalse);
      expect(msg.isMine(null), isFalse);
    });

    test('ChatMessage.fromRow parses Supabase row and profile join', () {
      final row = {
        'id': 'msg-supabase-1',
        'conversation_id': 'conv-999',
        'sender_id': 'user-123',
        'body': 'Good morning, is the water tank fixed?',
        'is_read': false,
        'created_at': '2026-09-19T10:30:00.000Z',
        'profiles': {
          'full_name': 'Anna Dela Cruz',
          'role': 'tenant',
        },
      };

      final msg = ChatMessage.fromRow(row);

      expect(msg.id, 'msg-supabase-1');
      expect(msg.conversationId, 'conv-999');
      expect(msg.senderId, 'user-123');
      expect(msg.senderName, 'Anna Dela Cruz');
      expect(msg.senderRole, 'tenant');
      expect(msg.body, 'Good morning, is the water tank fixed?');
      expect(msg.isRead, isFalse);
    });

    test('toInsertRow produces valid insert payload', () {
      final msg = ChatMessage(
        id: 'temp-id',
        conversationId: 'conv-abc',
        senderId: 'user-xyz',
        senderName: 'Caretaker',
        senderRole: 'caretaker',
        body: 'Maintenance completed.',
        sentAt: now,
      );

      final insertMap = msg.toInsertRow();
      expect(insertMap['conversation_id'], 'conv-abc');
      expect(insertMap['sender_id'], 'user-xyz');
      expect(insertMap['sender_role'], 'caretaker');
      expect(insertMap['body'], 'Maintenance completed.');
      expect(insertMap['is_read'], isFalse);
    });
  });

  group('ConversationRecord Model', () {
    test('parses tenant_management conversation for Owner perspective', () {
      final row = {
        'id': 'conv-tenant-1',
        'type': 'tenant_management',
        'tenant_id': 'tenant-uuid',
        'guardian_id': null,
        'last_message_preview': 'Hello from Anna',
        'last_message_at': '2026-09-19T11:00:00.000Z',
        'unread_count': 2,
        'created_at': '2026-09-19T08:00:00.000Z',
        'updated_at': '2026-09-19T11:00:00.000Z',
        'tenant_profile': {
          'full_name': 'Anna Dela Cruz',
          'role': 'tenant',
          'assignment': {
            'room_number': '204',
            'bed_space': 'Bed 2',
          },
        },
      };

      final conv = ConversationRecord.fromRow(row, currentRole: 'owner');

      expect(conv.id, 'conv-tenant-1');
      expect(conv.isTenantManagement, isTrue);
      expect(conv.title, 'Anna Dela Cruz');
      expect(conv.subtitle, 'Room 204 (Bed 2)');
      expect(conv.lastMessagePreview, 'Hello from Anna');
      expect(conv.unreadCount, 2);
    });

    test('contextualizes title for Tenant perspective', () {
      final row = {
        'id': 'conv-tenant-1',
        'type': 'tenant_management',
        'tenant_id': 'tenant-uuid',
        'guardian_id': null,
        'last_message_preview': 'Maintenance on the way',
        'last_message_at': '2026-09-19T11:00:00.000Z',
        'unread_count': 0,
        'created_at': '2026-09-19T08:00:00.000Z',
        'updated_at': '2026-09-19T11:00:00.000Z',
        'tenant_profile': {
          'full_name': 'Anna Dela Cruz',
        },
      };

      final conv = ConversationRecord.fromRow(row, currentRole: 'tenant');

      expect(conv.title, 'Dormitory Management');
      expect(conv.subtitle, 'Owner & Caretaker');
    });

    test('parses guardian_management conversation', () {
      final row = {
        'id': 'conv-guardian-1',
        'type': 'guardian_management',
        'tenant_id': 'tenant-uuid',
        'guardian_id': 'guardian-uuid',
        'last_message_preview': 'Thank you for the update',
        'last_message_at': '2026-09-19T11:00:00.000Z',
        'unread_count': 1,
        'created_at': '2026-09-19T08:00:00.000Z',
        'updated_at': '2026-09-19T11:00:00.000Z',
        'guardian_profile': {
          'full_name': 'Maria Dela Cruz',
        },
        'tenant_profile': {
          'full_name': 'Anna Dela Cruz',
        },
      };

      final conv = ConversationRecord.fromRow(row, currentRole: 'owner');

      expect(conv.isGuardianManagement, isTrue);
      expect(conv.title, 'Maria Dela Cruz');
      expect(conv.subtitle, 'Guardian of Anna Dela Cruz');
    });

    test('parses internal_staff conversation', () {
      final row = {
        'id': 'conv-staff-1',
        'type': 'internal_staff',
        'tenant_id': null,
        'guardian_id': null,
        'last_message_preview': 'Please check 2nd floor extinguisher',
        'last_message_at': '2026-09-19T12:00:00.000Z',
        'unread_count': 0,
        'created_at': '2026-09-19T08:00:00.000Z',
        'updated_at': '2026-09-19T12:00:00.000Z',
      };

      final conv = ConversationRecord.fromRow(row, currentRole: 'caretaker');

      expect(conv.isInternalStaff, isTrue);
      expect(conv.title, 'Staff Channel');
      expect(conv.subtitle, 'Owner & Caretaker Coordination');
    });
  });
}

