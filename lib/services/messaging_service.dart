import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../models/models.dart';

class MessagingService {
  const MessagingService();

  Future<List<Map<String, dynamic>>> listStaffContacts() async {
    final client = SupabaseConfig.clientSafe;
    if (client == null || client.auth.currentUser == null) return const [];
    final rows = await client.rpc('list_messaging_staff');
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<List<ConversationRecord>> listDirectConversations() async {
    final client = SupabaseConfig.clientSafe;
    if (client == null || client.auth.currentUser == null) return const [];
    final rows = await client.rpc('list_my_direct_staff_conversations');
    return (rows as List)
        .map((row) => ConversationRecord.fromRow(
              Map<String, dynamic>.from(row as Map),
            ))
        .toList();
  }

  Future<ConversationRecord> getOrCreateDirectConversation(
      String staffId) async {
    final id = await SupabaseConfig.client.rpc(
        'get_or_create_direct_staff_conversation',
        params: {'p_staff_id': staffId});
    final conversations = await listDirectConversations();
    return conversations.firstWhere((record) => record.id == id);
  }

  static const String _conversationColumns =
      'id, type, tenant_id, guardian_id, last_message_preview, last_message_at, created_at, updated_at, '
      'tenant_profile:profiles!tenant_id(full_name, role), '
      'guardian_profile:profiles!guardian_id(full_name, role)';

  static const String _messageColumns =
      'id, conversation_id, sender_id, sender_role, body, is_read, read_at, created_at, '
      'profiles!sender_id(full_name, role)';

  /// Retrieves or creates the official conversation thread for a tenant with Management.
  Future<ConversationRecord?> getOrCreateTenantConversation({
    required String tenantId,
  }) async {
    final client = SupabaseConfig.clientSafe;
    if (client == null) return null;

    final effectiveTenantId =
        tenantId.isNotEmpty ? tenantId : (client.auth.currentUser?.id ?? '');
    if (effectiveTenantId.isEmpty) return null;

    try {
      // 1. Try to find existing thread
      final existing = await client
          .from('conversations')
          .select(_conversationColumns)
          .eq('type', 'tenant_management')
          .eq('tenant_id', effectiveTenantId)
          .maybeSingle();

      if (existing != null) {
        return ConversationRecord.fromRow(existing, currentRole: 'tenant');
      }

      // 2. Create if not found
      final inserted = await client
          .from('conversations')
          .insert({
            'type': 'tenant_management',
            'tenant_id': effectiveTenantId,
            'last_message_preview': 'Conversation started.',
          })
          .select(_conversationColumns)
          .single();

      return ConversationRecord.fromRow(inserted, currentRole: 'tenant');
    } catch (e) {
      debugPrint('Error in getOrCreateTenantConversation: $e');
      return null;
    }
  }

  /// Ensures initial conversation threads exist for active tenants and internal staff.
  Future<void> ensureInitialConversations() async {
    final client = SupabaseConfig.clientSafe;
    if (client == null) return;

    try {
      // 1. Ensure staff room exists
      await getOrCreateStaffConversation();

      // 2. Query tenants from profiles and ensure each has an official thread
      final tenantProfiles = await client
          .from('profiles')
          .select('id')
          .eq('role', 'tenant')
          .limit(20);

      for (final t in tenantProfiles) {
        final tid = t['id'] as String?;
        if (tid != null && tid.isNotEmpty) {
          await getOrCreateTenantConversation(tenantId: tid);
        }
      }

      // 3. Query guardians from profiles and ensure each has an official thread
      final guardianProfiles = await client
          .from('profiles')
          .select('id')
          .eq('role', 'guardian')
          .limit(20);

      for (final g in guardianProfiles) {
        final gid = g['id'] as String?;
        if (gid != null && gid.isNotEmpty) {
          await getOrCreateGuardianConversation(guardianId: gid);
        }
      }
    } catch (e) {
      debugPrint('ensureInitialConversations info: $e');
    }
  }

  /// Retrieves or creates the official conversation thread for a guardian with Management.
  Future<ConversationRecord?> getOrCreateGuardianConversation({
    required String guardianId,
    String? tenantId,
  }) async {
    final client = SupabaseConfig.clientSafe;
    if (client == null) return null;

    try {
      var query = client
          .from('conversations')
          .select(_conversationColumns)
          .eq('type', 'guardian_management')
          .eq('guardian_id', guardianId);

      if (tenantId != null) {
        query = query.eq('tenant_id', tenantId);
      }

      final existing = await query.maybeSingle();
      if (existing != null) {
        return ConversationRecord.fromRow(existing, currentRole: 'guardian');
      }

      final insertData = <String, dynamic>{
        'type': 'guardian_management',
        'guardian_id': guardianId,
        'last_message_preview': 'Conversation started.',
      };
      if (tenantId != null) {
        insertData['tenant_id'] = tenantId;
      }

      final inserted = await client
          .from('conversations')
          .insert(insertData)
          .select(_conversationColumns)
          .single();

      return ConversationRecord.fromRow(inserted, currentRole: 'guardian');
    } catch (e) {
      debugPrint('Error in getOrCreateGuardianConversation: $e');
      return null;
    }
  }

  /// Retrieves or creates the internal staff conversation between Owner and Caretaker.
  Future<ConversationRecord?> getOrCreateStaffConversation() async {
    final client = SupabaseConfig.clientSafe;
    if (client == null) return null;

    try {
      final existing = await client
          .from('conversations')
          .select(_conversationColumns)
          .eq('type', 'internal_staff')
          .maybeSingle();

      if (existing != null) {
        return ConversationRecord.fromRow(existing, currentRole: 'owner');
      }

      final inserted = await client
          .from('conversations')
          .insert({
            'type': 'internal_staff',
            'last_message_preview': 'Staff Channel initialized.',
          })
          .select(_conversationColumns)
          .single();

      return ConversationRecord.fromRow(inserted, currentRole: 'owner');
    } catch (e) {
      debugPrint('Error in getOrCreateStaffConversation: $e');
      return null;
    }
  }

  Future<ConversationRecord?> fetchConversationById(
    String conversationId, {
    String? currentRole,
  }) async {
    final client = SupabaseConfig.clientSafe;
    if (client == null || conversationId.isEmpty) return null;
    try {
      final row = await client
          .from('conversations')
          .select(_conversationColumns)
          .eq('id', conversationId)
          .maybeSingle();
      if (row == null || row['type'] != 'direct_staff') return null;
      if (row['type'] == 'direct_staff') {
        return (await listDirectConversations())
            .firstWhere((record) => record.id == conversationId);
      }
      return ConversationRecord.fromRow(
        row,
        currentRole: currentRole ?? 'owner',
      );
    } catch (e) {
      debugPrint('Error fetching conversation by ID: $e');
      return null;
    }
  }

  /// Lists all conversations for the Owner / Caretaker management inbox.
  Future<List<ConversationRecord>> fetchConversations({
    String? filterType,
    String? currentRole,
  }) async {
    final direct = await listDirectConversations();
    if (filterType != null && filterType != 'direct_staff') return const [];
    return direct;
  }

  /// Fetches message history for a specific conversation thread.
  Future<List<ChatMessage>> fetchMessages(
    String conversationId, {
    int limit = 100,
  }) async {
    final client = SupabaseConfig.clientSafe;
    if (client == null) return const [];

    try {
      final rows = await client
          .from('messages')
          .select(_messageColumns)
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true)
          .limit(limit);

      return (rows as List<dynamic>)
          .map<ChatMessage>(
              (row) => ChatMessage.fromRow(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching messages: $e');
      return const [];
    }
  }

  Future<ChatMessage?> fetchMessageById(String messageId) async {
    final client = SupabaseConfig.clientSafe;
    if (client == null || messageId.isEmpty) return null;
    try {
      final row = await client
          .from('messages')
          .select(_messageColumns)
          .eq('id', messageId)
          .maybeSingle();
      return row == null ? null : ChatMessage.fromRow(row);
    } catch (e) {
      debugPrint('Error fetching realtime message detail: $e');
      return null;
    }
  }

  /// Sends a new message in a conversation thread.
  Future<ChatMessage?> sendMessage({
    required String conversationId,
    required String body,
    required String senderId,
    required String senderRole,
  }) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;

    final client = SupabaseConfig.clientSafe;
    if (client == null) {
      throw Exception('Database client unavailable');
    }

    final effectiveSenderId =
        senderId.isNotEmpty ? senderId : (client.auth.currentUser?.id ?? '');

    if (effectiveSenderId.isEmpty) {
      throw Exception('Authenticated user ID required to send message');
    }

    final inserted = await client
        .from('messages')
        .insert({
          'conversation_id': conversationId,
          'sender_id': effectiveSenderId,
          'sender_role': senderRole,
          'body': trimmed,
          'is_read': false,
        })
        .select(_messageColumns)
        .single();

    unawaited(_notifyMessage(client, inserted['id'] as String));

    return ChatMessage.fromRow(inserted);
  }

  Future<void> _notifyMessage(
    SupabaseClient client,
    String messageId,
  ) async {
    try {
      final response = await client.functions.invoke(
        'notify-message',
        body: {'message_id': messageId},
      );
      debugPrint('Message notification dispatch: ${response.data}');
    } catch (error) {
      debugPrint('Message saved but push dispatch failed: $error');
    }
  }

  /// Marks all incoming unread messages in a conversation as read.
  Future<DateTime?> markConversationAsRead({
    required String conversationId,
  }) async {
    final client = SupabaseConfig.clientSafe;
    if (client == null) return null;

    try {
      final value = await client.rpc(
        'mark_conversation_messages_read',
        params: {'p_conversation_id': conversationId},
      );
      return value == null ? null : DateTime.parse(value as String).toLocal();
    } catch (e) {
      debugPrint('Error marking conversation as read: $e');
      return null;
    }
  }

  /// Subscribes to live incoming messages for a specific conversation thread.
  RealtimeChannel? subscribeToConversation({
    required String conversationId,
    required void Function(ChatMessage message) onMessageReceived,
    required void Function(ChatMessage message) onMessageUpdated,
  }) {
    final client = SupabaseConfig.clientSafe;
    if (client == null) return null;

    try {
      final channel = client.channel('chat-$conversationId');
      channel
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'conversation_id',
              value: conversationId,
            ),
            callback: (payload) {
              final newRow = payload.newRecord;
              final messageId = newRow['id']?.toString() ?? '';
              if (messageId.isEmpty) return;
              unawaited(fetchMessageById(messageId).then((message) {
                if (message != null) onMessageReceived(message);
              }));
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'conversation_id',
              value: conversationId,
            ),
            callback: (payload) {
              final updatedRow = payload.newRecord;
              final messageId = updatedRow['id']?.toString() ?? '';
              if (messageId.isEmpty) return;
              unawaited(fetchMessageById(messageId).then((message) {
                if (message != null) onMessageUpdated(message);
              }));
            },
          )
          .subscribe();

      return channel;
    } catch (e) {
      debugPrint('Error subscribing to conversation messages: $e');
      return null;
    }
  }

  /// Subscribes to conversation table changes (for live inbox updates).
  RealtimeChannel? subscribeToConversations({
    required void Function() onConversationsUpdated,
  }) {
    final client = SupabaseConfig.clientSafe;
    if (client == null) return null;

    try {
      final channel = client.channel('inbox-conversations');
      channel
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'conversations',
            callback: (_) => onConversationsUpdated(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'messages',
            callback: (_) => onConversationsUpdated(),
          )
          .subscribe();

      return channel;
    } catch (e) {
      debugPrint('Error subscribing to conversations: $e');
      return null;
    }
  }

  /// Safely disposes a realtime channel.
  Future<void> disposeChannel(RealtimeChannel? channel) async {
    if (channel == null) return;
    try {
      final client = SupabaseConfig.clientSafe;
      if (client != null) {
        await client.removeChannel(channel);
      }
    } catch (_) {}
  }
}
