import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../supabase/supabase_tables.dart';

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  static const String _channelId = 'whoeats_notifications';
  static const String _channelName = 'Who eats notifications';
  static const String _channelDescription =
      'Like/comment/friend request push notifications';

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _listenersAttached = false;

  bool get _supportsPush {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> initialize() async {
    if (_initialized || !_supportsPush) return;
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      );
      await _localNotifications.initialize(settings: initSettings);

      final permission = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      if (kDebugMode) {
        debugPrint(
          '[PushNotificationService] permission=${permission.authorizationStatus}',
        );
      }

      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );

      await _attachListeners();
      await _registerCurrentToken();
      _initialized = true;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[PushNotificationService] initialize skipped: $e\n$st');
      }
    }
  }

  Future<void> onAuthChanged(String? userId) async {
    if (!_supportsPush) return;
    if (userId == null) {
      return;
    }
    await _registerCurrentToken();
  }

  Future<void> sendEvent({
    required String targetUserId,
    required String eventType,
    String? postId,
    String? commentId,
    String? friendId,
  }) async {
    if (!AppConfig.hasSupabase) return;
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'send-push',
        body: <String, dynamic>{
          'target_user_id': targetUserId,
          'event_type': eventType,
          if (postId != null && postId.isNotEmpty) 'post_id': postId,
          if (commentId != null && commentId.isNotEmpty)
            'comment_id': commentId,
          if (friendId != null && friendId.isNotEmpty) 'friend_id': friendId,
        },
      );
      if (kDebugMode) {
        debugPrint(
          '[PushNotificationService] sendEvent response: ${response.data}',
        );
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[PushNotificationService] sendEvent failed: $e\n$st');
      }
    }
  }

  Future<void> _attachListeners() async {
    if (_listenersAttached) return;
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      if (kDebugMode) {
        debugPrint('[PushNotificationService] opened: ${message.data}');
      }
    });
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null && kDebugMode) {
      debugPrint('[PushNotificationService] initial: ${initialMessage.data}');
    }
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      if (kDebugMode) {
        debugPrint('[PushNotificationService] token refreshed: $token');
      }
      unawaited(_upsertToken(token));
    });
    _listenersAttached = true;
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title ?? 'Who eats',
      body: notification.body ?? '',
      notificationDetails: details,
      payload: message.data.isEmpty ? null : message.data.toString(),
    );
  }

  Future<void> _registerCurrentToken() async {
    if (!_supportsPush) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;
    if (kDebugMode) {
      debugPrint('[PushNotificationService] current token: $token');
    }
    await _upsertToken(token);
  }

  Future<void> _upsertToken(String token) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || token.isEmpty) return;
    try {
      await Supabase.instance.client
          .from(SupabaseTables.devicePushTokens)
          .upsert({
            'user_id': user.id,
            'fcm_token': token,
            'platform': defaultTargetPlatform.name,
            'last_seen_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }, onConflict: 'fcm_token');
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[PushNotificationService] token upsert failed: $e\n$st');
      }
    }
  }
}
