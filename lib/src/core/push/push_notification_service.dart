import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../supabase/supabase_tables.dart';

class PushSendResult {
  const PushSendResult({
    required this.ok,
    required this.message,
    this.sent = 0,
    this.failed = 0,
    this.raw,
  });

  final bool ok;
  final String message;
  final int sent;
  final int failed;
  final dynamic raw;

  factory PushSendResult.unavailable(String message) {
    return PushSendResult(ok: false, message: message);
  }

  factory PushSendResult.fromResponse(dynamic data) {
    if (data is! Map) {
      return PushSendResult(
        ok: false,
        message: 'サーバー応答を解釈できませんでした',
        raw: data,
      );
    }
    final sent = (data['sent'] as num?)?.toInt() ?? 0;
    final failed = (data['failed'] as num?)?.toInt() ?? 0;
    final reason = (data['reason'] ?? '').toString();
    if (sent > 0) {
      return PushSendResult(
        ok: true,
        message: 'プッシュを $sent 件送信しました',
        sent: sent,
        failed: failed,
        raw: data,
      );
    }
    if (reason == 'no tokens') {
      return PushSendResult(
        ok: false,
        message: 'このアカウントに登録済みの端末トークンがありません',
        sent: sent,
        failed: failed,
        raw: data,
      );
    }
    final error = (data['error'] ?? '').toString();
    if (error.isNotEmpty) {
      return PushSendResult(
        ok: false,
        message: error,
        sent: sent,
        failed: failed,
        raw: data,
      );
    }
    final fcmMessage = _formatFcmErrors(data['errors']);
    if (fcmMessage != null) {
      return PushSendResult(
        ok: false,
        message: fcmMessage,
        sent: sent,
        failed: failed,
        raw: data,
      );
    }
    return PushSendResult(
      ok: false,
      message: '送信できませんでした（sent=$sent, failed=$failed）',
      sent: sent,
      failed: failed,
      raw: data,
    );
  }

  static String? _formatFcmErrors(dynamic errors) {
    if (errors is! List || errors.isEmpty) return null;
    final first = errors.first;
    if (first is! Map) return null;
    final code = (first['code'] ?? '').toString();
    final message = (first['message'] ?? '').toString();
    final projectIdSuffix = AppConfig.firebaseProjectId.isNotEmpty
        ? ' (${AppConfig.firebaseProjectId})'
        : '';
    switch (code) {
      case 'THIRD_PARTY_AUTH_ERROR':
        return 'Firebase に APNs 認証キーが未設定、または無効です。'
            'Firebase Console → プロジェクト設定 → Cloud Messaging で iOS の APNs キーを登録してください。';
      case 'UNREGISTERED':
        return '端末トークンが無効です。アプリを再起動してからもう一度お試しください。';
      case 'SENDER_ID_MISMATCH':
        return 'Firebase プロジェクト設定がアプリと一致していません'
            '（FCM_PROJECT_ID / GoogleService-Info.plist / google-services.json を確認）'
            '$projectIdSuffix。';
      case 'INVALID_ARGUMENT':
        return 'FCM リクエストが不正です: $message';
      case 'PERMISSION_DENIED':
        return 'FCM の権限がありません。Supabase シークレットの '
            'FCM_SERVICE_ACCOUNT_JSON が対象 Firebase プロジェクトのサービスアカウントか、'
            'FCM_PROJECT_ID に余計な空白がないか確認してください。'
            ' ($message)';
      default:
        if (message.contains('Permission denied')) {
          return 'FCM の権限がありません。Firebase Console から対象プロジェクト用の '
              'サービスアカウント鍵を再発行し、FCM_SERVICE_ACCOUNT_JSON を更新してください。';
        }
        if (code.isNotEmpty) return 'FCM エラー ($code): $message';
        if (message.isNotEmpty) return 'FCM エラー: $message';
        return null;
    }
  }
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  static const String _channelId = 'whoeats_notifications';
  static const String _channelName = 'Who eats notifications';
  static const String _channelDescription =
      'Like/comment/friend request/post reminder push notifications';

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _listenersAttached = false;
  Future<void>? _initFuture;

  bool get _supportsPush {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> initialize() {
    _initFuture ??= _initializeImpl();
    return _initFuture!;
  }

  Future<void> _initializeImpl() async {
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
      await _ensureAndroidNotificationChannel();

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
    await initialize();
    if (userId == null) {
      return;
    }
    await _registerCurrentToken();
  }

  Future<PushSendResult> sendEvent({
    required String targetUserId,
    required String eventType,
    String? postId,
    String? commentId,
    String? friendId,
  }) async {
    if (!AppConfig.hasSupabase) {
      return PushSendResult.unavailable('Supabase が未設定です');
    }
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
      final result = PushSendResult.fromResponse(response.data);
      if (kDebugMode) {
        debugPrint(
          '[PushNotificationService] sendEvent response: ${response.data}',
        );
      }
      return result;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[PushNotificationService] sendEvent failed: $e\n$st');
      }
      return PushSendResult.unavailable('送信に失敗しました: $e');
    }
  }

  /// 自分自身へテスト用プッシュを送る。UI は外しているが検証用に残す。
  Future<PushSendResult> sendTestPushToSelf() async {
    if (!_supportsPush) {
      return PushSendResult.unavailable('この端末はプッシュ非対応です');
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return PushSendResult.unavailable('ログインしていません');
    }

    await initialize();
    await _registerCurrentToken();

    final token = await _resolveFcmToken();
    if (token == null || token.isEmpty) {
      return PushSendResult.unavailable(
        'FCM トークンを取得できませんでした。通知許可と実機接続を確認してください',
      );
    }

    return sendEvent(
      targetUserId: user.id,
      eventType: 'test',
    );
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

  Future<void> _ensureAndroidNotificationChannel() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      ),
    );
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
    if (user == null) {
      if (kDebugMode) {
        debugPrint('[PushNotificationService] skip token register: no user');
      }
      return;
    }

    for (var attempt = 0; attempt < 6; attempt++) {
      final token = await _resolveFcmToken();
      if (token != null && token.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('[PushNotificationService] current token: $token');
        }
        await _upsertToken(token);
        return;
      }
      if (kDebugMode) {
        debugPrint(
          '[PushNotificationService] FCM token not ready (attempt ${attempt + 1}/6)',
        );
      }
      await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1)));
    }
    if (kDebugMode) {
      debugPrint('[PushNotificationService] FCM token unavailable after retries');
    }
  }

  Future<String?> _resolveFcmToken() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      for (var attempt = 0; attempt < 8; attempt++) {
        final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        if (apnsToken != null) break;
        if (kDebugMode && attempt == 0) {
          debugPrint('[PushNotificationService] waiting for APNs token...');
        }
        await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
      }
    }
    return FirebaseMessaging.instance.getToken();
  }

  Future<void> _upsertToken(String token) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || token.isEmpty) return;
    try {
      await Supabase.instance.client.rpc(
        'register_device_push_token',
        params: {
          'p_fcm_token': token,
          'p_platform': defaultTargetPlatform.name,
        },
      );
      if (kDebugMode) {
        debugPrint('[PushNotificationService] token registered for ${user.id}');
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[PushNotificationService] token register failed: $e\n$st');
      }
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
        if (kDebugMode) {
          debugPrint('[PushNotificationService] token upsert fallback ok');
        }
      } catch (fallbackError, fallbackSt) {
        if (kDebugMode) {
          debugPrint(
            '[PushNotificationService] token upsert fallback failed: '
            '$fallbackError\n$fallbackSt',
          );
        }
      }
    }
  }
}
