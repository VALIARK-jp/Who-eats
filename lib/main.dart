import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_line_sdk/flutter_line_sdk.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app.dart';
import 'src/core/config/app_config.dart';
import 'src/core/config/firebase_options.dart';
import 'src/core/push/push_notification_service.dart';
import 'src/core/web/google_maps_loader.dart';
import 'src/features/auth/valiark_auth_config.dart';

bool _isSupabaseOfflineNoise(Object error) {
  final s = error.toString();
  return s.contains('Failed host lookup') && s.contains('supabase');
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // The background isolate can run with native Firebase config if .env is unavailable.
    }
    final firebaseOptions = firebaseOptionsFromConfig();
    if (firebaseOptions != null) {
      await Firebase.initializeApp(options: firebaseOptions);
      return;
    }
    await Firebase.initializeApp();
  } catch (e, st) {
    debugPrint('Firebase background init failed: $e\n$st');
  }
}

/// Loads [`.env`] then starts the app. Values resolve as **`--dart-define` → `.env`** ([AppConfig]).
Future<void> main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await dotenv.load(fileName: '.env');

      final supportsPush =
          !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS);

      if (supportsPush) {
        FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler,
        );
        try {
          final firebaseOptions = firebaseOptionsFromConfig();
          if (firebaseOptions != null) {
            await Firebase.initializeApp(options: firebaseOptions);
          } else {
            await Firebase.initializeApp();
          }
        } catch (e, st) {
          debugPrint('Firebase init skipped or failed: $e\n$st');
        }
      }

      if (kIsWeb && AppConfig.hasGooglePlacesApi) {
        try {
          await loadGoogleMapsScript(AppConfig.googleMapsWebApiKey);
        } catch (e, st) {
          debugPrint('Google Maps JS load failed: $e\n$st');
        }
      }

      debugPrint('★ Supabaseのキーは設定されている？ : ${AppConfig.hasSupabase}');

      if (AppConfig.hasSupabase) {
        try {
          await Supabase.initialize(
            url: AppConfig.supabaseUrl,
            anonKey: AppConfig.supabaseAnonKey,
            authOptions: const FlutterAuthClientOptions(
              authFlowType: AuthFlowType.pkce,
              // ValiarkDeeplinkHandler のみが getSessionFromUrl する（Panda Talk 同型）。
              detectSessionInUri: false,
            ),
          );
        } catch (e, st) {
          debugPrint('Supabase init skipped or failed: $e\n$st');
        }
        if (!kIsWeb) {
          try {
            await LineSDK.instance.setup(valiarkLineChannelId);
          } catch (e, st) {
            debugPrint('LineSDK setup failed: $e\n$st');
          }
        }
      }
      if (supportsPush) {
        unawaited(PushNotificationService.instance.initialize());
      }
      runApp(const WhoEatsApp());
    },
    (Object error, StackTrace stack) {
      if (_isSupabaseOfflineNoise(error)) {
        debugPrint(
          'Supabase unreachable (DNS/offline). Retry when network is available.\n'
          '$error',
        );
        return;
      }
      FlutterError.dumpErrorToConsole(
        FlutterErrorDetails(exception: error, stack: stack),
      );
    },
  );
}
