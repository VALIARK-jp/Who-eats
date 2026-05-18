import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_line_sdk/flutter_line_sdk.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app.dart';
import 'src/core/config/app_config.dart';
import 'src/features/auth/valiark_auth_config.dart';

bool _isSupabaseOfflineNoise(Object error) {
  final s = error.toString();
  return s.contains('Failed host lookup') && s.contains('supabase');
}

/// Loads [`.env`] then starts the app. Values resolve as **`--dart-define` → `.env`** ([AppConfig]).
Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await dotenv.load(fileName: '.env');
    if (AppConfig.hasSupabase) {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          // ValiarkDeeplinkHandler のみが getSessionFromUrl する（Panda Talk 同型）。
          detectSessionInUri: false,
        ),
      );
      await LineSDK.instance.setup(valiarkLineChannelId);
    }
    runApp(const WhoEatsApp());
  }, (Object error, StackTrace stack) {
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
  });
}
