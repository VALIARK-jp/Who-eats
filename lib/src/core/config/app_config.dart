import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../features/auth/valiark_auth_config.dart';

/// 環境値の優先順位: **`--dart-define` → ルートの `.env`**（Panda Talk と同じ運用）。
///
/// `WHOEATS_*` を主体とし、Supabase は `SUPABASE_URL` / `SUPABASE_ANON_KEY` もフォールバック。
class AppConfig {
  static String _env(String key) {
    final value = dotenv.env[key];
    return value == null ? '' : value.trim();
  }

  static String _pick(String fromDefine, String fromFile) =>
      fromDefine.isNotEmpty ? fromDefine : fromFile;

  static String get mapPinsApiUrl => _pick(
    const String.fromEnvironment('WHOEATS_MAP_PINS_API_URL', defaultValue: ''),
    _env('WHOEATS_MAP_PINS_API_URL'),
  );

  static String get placeDetailApiTemplate => _pick(
    const String.fromEnvironment(
      'WHOEATS_PLACE_DETAIL_API_TEMPLATE',
      defaultValue: '',
    ),
    _env('WHOEATS_PLACE_DETAIL_API_TEMPLATE'),
  );

  static String get googleMapsWebApiKey => _pick(
    const String.fromEnvironment('WHOEATS_GOOGLE_MAPS_WEB_API_KEY', defaultValue: ''),
    _env('WHOEATS_GOOGLE_MAPS_WEB_API_KEY'),
  );

  static String get postedPinPlaceId => _pick(
    const String.fromEnvironment('WHOEATS_POSTED_PIN_PLACE_ID', defaultValue: ''),
    _env('WHOEATS_POSTED_PIN_PLACE_ID'),
  );

  static String get postedPinPlaceName => _pick(
    const String.fromEnvironment('WHOEATS_POSTED_PIN_PLACE_NAME', defaultValue: ''),
    _env('WHOEATS_POSTED_PIN_PLACE_NAME'),
  );

  /// `WHOEATS_SUPABASE_URL`（dart-define / .env）または `SUPABASE_*`。
  static String get supabaseUrl {
    final wD = const String.fromEnvironment('WHOEATS_SUPABASE_URL', defaultValue: '');
    if (wD.isNotEmpty) return wD;
    final sD = const String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    if (sD.isNotEmpty) return sD;
    final w = _env('WHOEATS_SUPABASE_URL');
    if (w.isNotEmpty) return w;
    return _env('SUPABASE_URL');
  }

  /// Supabase **anon JWT**（公開）キー。Panda Talk の
  /// `PANDA_TALK_SUPABASE_ANON_KEY` と同じ役割。
  ///
  /// `line-auth-native` / `apple-auth-native` は `verify_jwt` 既定の
  /// Edge Function なので、`sb_publishable_...` 形式ではなく JWT 形式の
  /// anon key が必要。
  static String get supabaseAnonKey {
    final anonD = const String.fromEnvironment(
      'WHOEATS_SUPABASE_ANON_KEY',
      defaultValue: '',
    );
    if (anonD.isNotEmpty) return anonD;
    final sD = const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
    if (sD.isNotEmpty) return sD;
    final a = _env('WHOEATS_SUPABASE_ANON_KEY');
    if (a.isNotEmpty) return a;
    return _env('SUPABASE_ANON_KEY');
  }

  static String get pandaOAuthUrl => _pick(
    const String.fromEnvironment('WHOEATS_PANDA_OAUTH_URL', defaultValue: ''),
    _env('WHOEATS_PANDA_OAUTH_URL'),
  );

  /// Who eats 用プロフィール表。未設定時は `whoeats_users`。
  static String get supabaseProfilesTable {
    final v = _pick(
      const String.fromEnvironment(
        'WHOEATS_SUPABASE_PROFILES_TABLE',
        defaultValue: '',
      ),
      _env('WHOEATS_SUPABASE_PROFILES_TABLE'),
    );
    return v.isNotEmpty ? v : 'whoeats_users';
  }

  /// ドメイン表の接頭辞（例: `whoeats_`）。空なら非接頭辞。
  static String get dbTablePrefix => _pick(
    const String.fromEnvironment('WHOEATS_DB_TABLE_PREFIX', defaultValue: ''),
    _env('WHOEATS_DB_TABLE_PREFIX'),
  );

  /// メール確認・PKCE 戻り先（Supabase Dashboard の Redirect URLs と一致）。
  static String get authRedirectUrl {
    final d = const String.fromEnvironment(
      whoeatsAuthRedirectEnvKey,
      defaultValue: '',
    );
    if (d.isNotEmpty) return d;
    final w = _env(whoeatsAuthRedirectEnvKey);
    if (w.isNotEmpty) return w;
    final legacyD = const String.fromEnvironment(
      legacyValiarkAuthRedirectEnvKey,
      defaultValue: '',
    );
    if (legacyD.isNotEmpty) return legacyD;
    final legacy = _env(legacyValiarkAuthRedirectEnvKey);
    if (legacy.isNotEmpty) return legacy;
    return whoeatsAuthRedirectUrl;
  }

  /// 後方互換。新規は [authRedirectUrl] / `WHOEATS_AUTH_REDIRECT_URL` を使う。
  static String get valiarkAuthRedirectUrl => authRedirectUrl;

  static String get supabaseFunctionsUrl =>
      supabaseUrl.replaceFirst('.supabase.co', '.functions.supabase.co');

  static const String fallbackDevPlaceUuid =
      '00000000-0000-4000-8000-000000000001';

  static String get defaultDevPlaceUuid {
    final v = _pick(
      const String.fromEnvironment(
        'WHOEATS_DEFAULT_DEV_PLACE_UUID',
        defaultValue: '',
      ),
      _env('WHOEATS_DEFAULT_DEV_PLACE_UUID'),
    );
    return v.isNotEmpty ? v : fallbackDevPlaceUuid;
  }

  static bool get hasMapApi =>
      mapPinsApiUrl.isNotEmpty && placeDetailApiTemplate.isNotEmpty;
  static bool get hasGooglePlacesApi => googleMapsWebApiKey.isNotEmpty;
  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
