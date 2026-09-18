import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../data/mock_data.dart';
import '../models/models.dart';
import '../services/messaging_service.dart';
import 'session_controller.dart';

class MessagingController extends ChangeNotifier {
  MessagingController._();
  static final MessagingController instance = MessagingController._();

  final MessagingService _service = const MessagingService();

  // Active conversation state (inside a chat room)
  ConversationRecord? _activeConversation;
  List<ChatMessage> _activeMessages = [];
  bool _loadingMessages = false;
  bool _sendingMessage = false;
  String? _messagesError;
  RealtimeChannel? _activeMessageChannel;

  // Management inbox state (Owner / Caretaker)
  List<ConversationRecord> _conversations = [];
  bool _loadingConversations = false;
  bool _conversationsLoadedOnce = false;
  String? _conversationsError;
  String _selectedFilter = 'all'; // 'all', 'tenant', 'guardian', 'staff'
  String _searchQuery = '';
  RealtimeChannel? _inboxChannel;

  // Getters
  ConversationRecord? get activeConversation => _activeConversation;
  List<ChatMessage> get activeMessages => List.unmodifiable(_activeMessages);
  bool get loadingMessages => _loadingMessages;
  bool get sendingMessage => _sendingMessage;
  String? get messagesError => _messagesError;

  List<ConversationRecord> get conversations => List.unmodifiable(_conversations);
  bool get loadingConversations => _loadingConversations;
  String? get conversationsError => _conversationsError;
  String get selectedFilter => _selectedFilter;
  String get searchQuery => _searchQuery;

  int get totalUnreadCount => _conversations.fold<int>(
        0,
        (sum, item) => sum + item.unreadCount,
      );

  List<ConversationRecord> get filteredConversations {
    return _conversations.where((conv) {
      // 1. Filter by category
      if (_selectedFilter == 'tenant' && !conv.isTenantManagement) {
        return false;
      }
      if (_selectedFilter == 'guardian' && !conv.isGuardianManagement) {
        return false;
      }
      if (_selectedFilter == 'staff' && !conv.isInternalStaff) {
        return false;
      }

      // 2. Filter by search query
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesTitle = conv.title.toLowerCase().contains(q);
        final matchesSubtitle = conv.subtitle.toLowerCase().contains(q);
        final matchesRoom = (conv.roomNumber ?? '').toLowerCase().contains(q);
        final matchesPreview =
            (conv.lastMessagePreview ?? '').toLowerCase().contains(q);
        return matchesTitle || matchesSubtitle || matchesRoom || matchesPreview;
      }

      return true;
    }).toList();
  }

  void setFilter(String filter) {
    if (_selectedFilter != filter) {
      _selectedFilter = filter;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Opens or loads the official conversation for the authenticated Tenant.
  Future<void> loadTenantConversation(String tenantId) async {
    _loadingMessages = true;
    _messagesError = null;
    notifyListeners();

    try {
      final effectiveUid = tenantId.isNotEmpty
          ? tenantId
          : (SupabaseConfig.clientSafe?.auth.currentUser?.id ??
              SessionController.instance.currentUser?.id ??
              '');

      if (effectiveUid.isEmpty) {
        _useMockTenantMessages();
        return;
      }

      final conv =
          await _service.getOrCreateTenantConversation(tenantId: effectiveUid);
      if (conv != null) {
        _activeConversation = conv;
        await _fetchMessagesForActiveConversation();
      } else {
        _useMockTenantMessages();
      }
    } catch (e) {
      debugPrint('Error loading tenant conversation: $e');
      _useMockTenantMessages();
    } finally {
      _loadingMessages = false;
      notifyListeners();
    }
  }

  /// Opens or loads the official conversation for the authenticated Guardian.
  Future<void> loadGuardianConversation({
    required String guardianId,
    String? tenantId,
  }) async {
    _loadingMessages = true;
    _messagesError = null;
    notifyListeners();

    try {
      final effectiveGid = guardianId.isNotEmpty
          ? guardianId
          : (SupabaseConfig.clientSafe?.auth.currentUser?.id ??
              SessionController.instance.currentUser?.id ??
              '');

      if (effectiveGid.isEmpty) {
        _useMockGuardianMessages();
        return;
      }

      final conv = await _service.getOrCreateGuardianConversation(
        guardianId: effectiveGid,
        tenantId: tenantId,
      );
      if (conv != null) {
        _activeConversation = conv;
        await _fetchMessagesForActiveConversation();
      } else {
        _useMockGuardianMessages();
      }
    } catch (e) {
      debugPrint('Error loading guardian conversation: $e');
      _useMockGuardianMessages();
    } finally {
      _loadingMessages = false;
      notifyListeners();
    }
  }

  /// Opens an existing conversation from the Owner/Caretaker inbox.
  Future<void> openConversation(ConversationRecord conversation) async {
    _activeConversation = conversation;
    _loadingMessages = true;
    _messagesError = null;
    notifyListeners();

    try {
      await _fetchMessagesForActiveConversation();
    } catch (e) {
      debugPrint('Error opening conversation: $e');
      _messagesError = 'Failed to load messages';
    } finally {
      _loadingMessages = false;
      notifyListeners();
    }
  }

  /// Loads inbox conversations for Owner and Caretaker.
  Future<void> loadConversations({bool force = false}) async {
    if (_loadingConversations && !force) return;
    if (_conversationsLoadedOnce && !force) return;

    _loadingConversations = true;
    _conversationsError = null;
    notifyListeners();

    try {
      final currentRole =
          SessionController.instance.currentUser?.role.name ?? 'owner';
      final list = await _service.fetchConversations(currentRole: currentRole);

      if (list.isNotEmpty) {
        _conversations = list;
        _conversationsLoadedOnce = true;
      } else if (SupabaseConfig.clientSafe != null &&
          SupabaseConfig.clientSafe!.auth.currentUser != null) {
        _conversations = list;
        _conversationsLoadedOnce = true;
      } else {
        _useMockConversations();
      }

      _subscribeToInboxChanges();
    } catch (e) {
      debugPrint('Error loading conversations: $e');
      _conversationsError = 'Unable to fetch conversations';
      if (_conversations.isEmpty) {
        _useMockConversations();
      }
    } finally {
      _loadingConversations = false;
      notifyListeners();
    }
  }

  /// Sends a new message in the currently active conversation.
  Future<bool> sendMessage(String body) async {
    final text = body.trim();
    if (text.isEmpty) return false;

    _sendingMessage = true;
    notifyListeners();

    final client = SupabaseConfig.clientSafe;
    final authUid = client?.auth.currentUser?.id;
    final user = SessionController.instance.currentUser;
    final senderId = (authUid != null && authUid.isNotEmpty)
        ? authUid
        : (user?.id ?? '');
    final senderName = user?.name ?? 'Me';
    final senderRole = user?.role.name ?? 'tenant';
    final conv = _activeConversation;

    if (conv == null) {
      _sendingMessage = false;
      notifyListeners();
      return false;
    }

    // Offline / Mock conversation fallback
    if (conv.id.startsWith('mock-') || conv.id.startsWith('oc')) {
      _appendLocalMessage(
        text,
        senderId.isNotEmpty ? senderId : 'mock-user',
        senderName,
        senderRole,
        conv.id,
      );
      _sendingMessage = false;
      notifyListeners();
      return true;
    }

    try {
      final newMsg = await _service.sendMessage(
        conversationId: conv.id,
        body: text,
        senderId: senderId,
        senderRole: senderRole,
      );

      if (newMsg != null) {
        // If not already received via realtime stream
        if (!_activeMessages.any((m) => m.id == newMsg.id)) {
          _activeMessages.add(newMsg);
        }
      }
      _sendingMessage = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Send message database error: $e');
      _messagesError = 'Failed to send message: $e';
      _sendingMessage = false;
      notifyListeners();
      return false;
    }
  }

  void _appendLocalMessage(
    String body,
    String senderId,
    String senderName,
    String senderRole,
    String conversationId,
  ) {
    final localMsg = ChatMessage(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      senderRole: senderRole,
      body: body,
      sentAt: DateTime.now(),
    );
    _activeMessages.add(localMsg);

    // Keep mock data synchronized for mock views
    if (senderRole == 'tenant') {
      MockData.tenantMessages.add(localMsg);
    } else if (senderRole == 'guardian') {
      MockData.guardianMessages.add(localMsg);
    }
  }

  Future<void> _fetchMessagesForActiveConversation() async {
    final conv = _activeConversation;
    if (conv == null) return;

    if (conv.id.startsWith('mock-')) {
      if (conv.isTenantManagement) {
        _activeMessages = List.from(MockData.tenantMessages);
      } else if (conv.isGuardianManagement) {
        _activeMessages = List.from(MockData.guardianMessages);
      } else {
        _activeMessages = [];
      }
      return;
    }

    // 1. Fetch remote messages
    final messages = await _service.fetchMessages(conv.id);
    _activeMessages = messages;

    // 2. Mark unread as read
    final currentUid = SupabaseConfig.clientSafe?.auth.currentUser?.id ??
        SessionController.instance.currentUser?.id;
    if (currentUid != null && currentUid.isNotEmpty) {
      _service.markConversationAsRead(
        conversationId: conv.id,
        currentUserId: currentUid,
      );
    }

    // 3. Subscribe to live incoming messages
    _subscribeToActiveConversation(conv.id);
  }

  void _subscribeToActiveConversation(String conversationId) {
    _disposeActiveChannel();
    _activeMessageChannel = _service.subscribeToConversation(
      conversationId: conversationId,
      onMessageReceived: (incoming) {
        if (!_activeMessages.any((m) => m.id == incoming.id)) {
          _activeMessages.add(incoming);
          notifyListeners();
        }
      },
    );
  }

  void _subscribeToInboxChanges() {
    _inboxChannel ??= _service.subscribeToConversations(
      onConversationsUpdated: () {
        loadConversations(force: true);
      },
    );
  }

  void _useMockTenantMessages() {
    _activeConversation = ConversationRecord(
      id: 'mock-tenant-conv',
      type: 'tenant_management',
      title: 'Dormitory Management',
      subtitle: 'Owner & Caretaker',
      createdAt: DateTime(2026, 8, 8),
      updatedAt: DateTime.now(),
    );
    _activeMessages = List.from(MockData.tenantMessages);
  }

  void _useMockGuardianMessages() {
    _activeConversation = ConversationRecord(
      id: 'mock-guardian-conv',
      type: 'guardian_management',
      title: 'Dormitory Management',
      subtitle: 'Regarding Anna Dela Cruz',
      createdAt: DateTime(2026, 8, 8),
      updatedAt: DateTime.now(),
    );
    _activeMessages = List.from(MockData.guardianMessages);
  }

  void _useMockConversations() {
    _conversations = MockData.ownerConversations.map((oc) {
      return ConversationRecord(
        id: oc.id,
        type: oc.personRole.toLowerCase() == 'guardian'
            ? 'guardian_management'
            : 'tenant_management',
        title: oc.personName,
        subtitle: oc.personRole,
        participantName: oc.personName,
        participantRole: oc.personRole,
        lastMessagePreview: oc.messages.isNotEmpty ? oc.messages.last.body : '',
        lastMessageAt: oc.messages.isNotEmpty ? oc.messages.last.sentAt : null,
        unreadCount: 0,
        createdAt: DateTime(2026, 8, 8),
        updatedAt: DateTime.now(),
      );
    }).toList();
  }

  void _disposeActiveChannel() {
    if (_activeMessageChannel != null) {
      _service.disposeChannel(_activeMessageChannel);
      _activeMessageChannel = null;
    }
  }

  void closeActiveConversation() {
    _disposeActiveChannel();
    _activeConversation = null;
    _activeMessages = [];
    notifyListeners();
  }

  void clear() {
    _disposeActiveChannel();
    if (_inboxChannel != null) {
      _service.disposeChannel(_inboxChannel);
      _inboxChannel = null;
    }
    _activeConversation = null;
    _activeMessages = [];
    _conversations = [];
    _conversationsLoadedOnce = false;
    _selectedFilter = 'all';
    _searchQuery = '';
    notifyListeners();
  }
}

