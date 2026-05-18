import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/core/config/app_config.dart';
import 'src/core/web/google_maps_loader.dart'
    if (dart.library.html) 'src/core/web/google_maps_loader_html.dart';
import 'src/app.dart';

bool _isSupabaseOfflineNoise(Object error) {
  final s = error.toString();
  return s.contains('Failed host lookup') && s.contains('supabase');
}

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await dotenv.load(fileName: '.env');

    if (kIsWeb && AppConfig.hasGooglePlacesApi) {
      try {
        await loadGoogleMapsScript(AppConfig.googleMapsWebApiKey);
      } catch (e, st) {
        debugPrint('Google Maps JS load failed: $e\n$st');
      }
    }

    debugPrint('★ Supabaseのキーは設定されている？ : ${AppConfig.hasSupabase}');

    if (AppConfig.hasSupabase) {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabasePublishableKey,
      );
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
