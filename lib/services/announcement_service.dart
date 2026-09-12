import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';

class AnnouncementRecord {
  const AnnouncementRecord({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.title,
    required this.body,
    required this.category,
    required this.audience,
    required this.isPinned,
    required this.fcmSent,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AnnouncementRecord.fromRow(Map<String, dynamic> row) {
    final author = row['profiles'] as Map<String, dynamic>?;
    return AnnouncementRecord(
      id: row['id'] as String,
      authorId: row['author_id'] as String,
      authorName: author?['full_name'] as String? ?? 'Dormitory Staff',
      title: row['title'] as String,
      body: row['body'] as String,
      category: row['category'] as String? ?? 'general',
      audience: row['audience'] as String? ?? 'all',
      isPinned: row['is_pinned'] as bool? ?? false,
      fcmSent: row['fcm_sent'] as bool? ?? false,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  final String id;
  final String authorId;
  final String authorName;
  final String title;
  final String body;
  final String category;
  final String audience;
  final bool isPinned;
  final bool fcmSent;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class AnnouncementService {
  const AnnouncementService();

  static final Map<String, List<AnnouncementRecord>> _cache = {};
  static final Map<String, DateTime> _lastFetch = {};

  static List<AnnouncementRecord>? cachedAnnouncements(
          [String? audienceFilter]) =>
      _cache[audienceFilter ?? 'all'];

  static void invalidateCache() {
    _cache.clear();
    _lastFetch.clear();
  }

  SupabaseClient get _client => SupabaseConfig.client;

  Future<List<AnnouncementRecord>> listAnnouncements({
    bool forceRefresh = false,
    String? audienceFilter,
  }) async {
    final key = audienceFilter ?? 'all';
    final cached = _cache[key];
    final lastFetch = _lastFetch[key];

    if (!forceRefresh &&
        cached != null &&
        lastFetch != null &&
        DateTime.now().difference(lastFetch) < const Duration(seconds: 30)) {
      return cached;
    }

    var query = _client.from('announcements').select(
        'id, author_id, title, body, category, audience, is_pinned, fcm_sent, created_at, updated_at, profiles!author_id(full_name)');

    if (audienceFilter != null && audienceFilter != 'all') {
      query = query.or('audience.eq.all,audience.eq.$audienceFilter');
    }

    final rows = await query
        .order('is_pinned', ascending: false)
        .order('created_at', ascending: false);

    final list = (rows as List)
        .map((row) => AnnouncementRecord.fromRow(row as Map<String, dynamic>))
        .toList();

    _cache[key] = list;
    _lastFetch[key] = DateTime.now();
    return list;
  }

  Future<void> createAnnouncement({
    required String title,
    required String body,
    required String category,
    required String audience,
    bool isPinned = false,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Authentication required');

    final payload = {
      'author_id': userId,
      'title': title.trim(),
      'body': body.trim(),
      'category': category.trim().toLowerCase(),
      'audience': audience.trim().toLowerCase(),
      'is_pinned': isPinned,
      'fcm_sent': false,
    };

    final inserted = await _client
        .from('announcements')
        .insert(payload)
        .select(
            'id, author_id, title, body, category, audience, is_pinned, fcm_sent, created_at, updated_at')
        .single();

    invalidateCache();

    // FCM Notification Hook: Ready for Firebase Cloud Messaging integration
    await _dispatchFCMNotificationIfConfigured(inserted);
  }

  Future<void> updateAnnouncement({
    required String id,
    required String title,
    required String body,
    required String category,
    required String audience,
    required bool isPinned,
  }) async {
    invalidateCache();
    await _client.from('announcements').update({
      'title': title.trim(),
      'body': body.trim(),
      'category': category.trim().toLowerCase(),
      'audience': audience.trim().toLowerCase(),
      'is_pinned': isPinned,
    }).eq('id', id);
  }

  Future<void> togglePin(String id, bool isPinned) async {
    invalidateCache();
    await _client.from('announcements').update({
      'is_pinned': isPinned,
    }).eq('id', id);
  }

  Future<void> deleteAnnouncement(String id) async {
    invalidateCache();
    await _client.from('announcements').delete().eq('id', id);
  }

  /// Extensible FCM Notification Hook
  ///
  /// When Firebase Cloud Messaging (FCM) is enabled:
  /// 1. Broadcasts to FCM topic (e.g. `topics/announcements_all`, `topics/announcements_tenants`)
  /// 2. Or invokes a Supabase Edge Function to dispatch push notifications to device tokens
  /// 3. Marks `fcm_sent = true` once delivered
  Future<void> _dispatchFCMNotificationIfConfigured(
      Map<String, dynamic> record) async {
    try {
      // Integration point for FCM:
      // final audience = record['audience'];
      // final title = record['title'];
      // final body = record['body'];
      // e.g. await FirebaseMessagingService.sendTopicNotification(topic: audience, title: title, body: body);
    } catch (_) {
      // Silently ignore notification dispatch errors so database record remains intact
    }
  }
}
