import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/config/supabase_config.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  static const _channel = AndroidNotificationChannel(
    'carmelink_updates',
    'CarmeLink updates',
    description: 'Account, safety, payment, and dormitory updates.',
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  final StreamController<Map<String, dynamic>> _openedController =
      StreamController<Map<String, dynamic>>.broadcast();

  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<String>? _tokenSubscription;
  Map<String, dynamic>? _pendingOpen;
  bool _initialized = false;
  bool _available = false;

  Stream<Map<String, dynamic>> get openedNotifications =>
      _openedController.stream;
  bool get isAvailable => _available;

  bool get _isMobileFirebase =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    if (!_isMobileFirebase) return;

    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler,
      );

      const settings = InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_carmelink'),
        iOS: DarwinInitializationSettings(),
      );
      await _local.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload == null || payload.isEmpty) return;
          try {
            _publishOpen(Map<String, dynamic>.from(jsonDecode(payload) as Map));
          } catch (_) {}
        },
      );

      final android = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(_channel);

      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );

      _foregroundSubscription = FirebaseMessaging.onMessage.listen(
        _showForegroundMessage,
      );
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => _publishOpen(message.data),
      );
      _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
        _registerTokenForCurrentUser,
        onError: (Object error) =>
            debugPrint('FCM token refresh failed: $error'),
      );

      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _pendingOpen = initial.data;
      _available = true;
    } catch (error) {
      debugPrint('Push notification initialization unavailable: $error');
    }
  }

  Future<bool> registerForUser(String userId) async {
    if (!_available || userId.isEmpty) return false;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return false;
      }

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        String? apnsToken;
        for (var attempt = 0; attempt < 5 && apnsToken == null; attempt++) {
          apnsToken = await FirebaseMessaging.instance.getAPNSToken();
          if (apnsToken == null) {
            await Future<void>.delayed(const Duration(milliseconds: 500));
          }
        }
        if (apnsToken == null) return false;
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return false;
      await _registerToken(userId, token);
      flushPendingOpen();
      return true;
    } catch (error) {
      debugPrint('Unable to register for push notifications: $error');
      return false;
    }
  }

  Future<void> _registerTokenForCurrentUser(String token) async {
    final userId = SupabaseConfig.clientSafe?.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return;
    try {
      await _registerToken(userId, token);
    } catch (error) {
      debugPrint('Unable to refresh push token: $error');
    }
  }

  Future<void> _registerToken(String userId, String token) async {
    final client = SupabaseConfig.clientSafe;
    if (client == null) return;
    await client.from('push_device_tokens').upsert(
      {
        'user_id': userId,
        'fcm_token': token,
        'platform':
            defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
        'revoked_at': null,
      },
      onConflict: 'fcm_token',
    );
  }

  Future<void> revokeCurrentToken() async {
    if (!_available) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      final client = SupabaseConfig.clientSafe;
      if (token != null && client != null) {
        await client.from('push_device_tokens').update({
          'revoked_at': DateTime.now().toUtc().toIso8601String()
        }).eq('fcm_token', token);
      }
      await FirebaseMessaging.instance.deleteToken();
    } catch (error) {
      debugPrint('Unable to revoke push token: $error');
    }
  }

  Future<void> _showForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await _local.show(
      id: message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title: notification.title ?? 'CarmeLink',
      body: notification.body ?? 'You have a new update.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'carmelink_updates',
          'CarmeLink updates',
          channelDescription:
              'Account, safety, payment, and dormitory updates.',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_stat_carmelink',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void flushPendingOpen() {
    final data = _pendingOpen;
    if (data == null) return;
    _pendingOpen = null;
    _publishOpen(data);
  }

  void _publishOpen(Map<String, dynamic> data) {
    if (SupabaseConfig.clientSafe?.auth.currentUser == null) {
      _pendingOpen = data;
      return;
    }
    _openedController.add(Map<String, dynamic>.from(data));
  }

  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _tokenSubscription?.cancel();
    await _openedController.close();
  }
}
