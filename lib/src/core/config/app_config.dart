import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../features/auth/valiark_auth_config.dart';

/// Web では [String.fromEnvironment] は const 文脈でのみ使えるため、ここでまとめる。
abstract final class _DartDefines {
  static const mapPinsApiUrl = String.fromEnvironment(
    'WHOEATS_MAP_PINS_API_URL',
    defaultValue: '',
  );
  static const placeDetailApiTemplate = String.fromEnvironment(
    'WHOEATS_PLACE_DETAIL_API_TEMPLATE',
    defaultValue: '',
  );
  static const googleMapsWebApiKey = String.fromEnvironment(
    'WHOEATS_GOOGLE_MAPS_WEB_API_KEY',
    defaultValue: '',
  );
  static const postedPinPlaceId = String.fromEnvironment(
    'WHOEATS_POSTED_PIN_PLACE_ID',
    defaultValue: '',
  );
  static const postedPinPlaceName = String.fromEnvironment(
    'WHOEATS_POSTED_PIN_PLACE_NAME',
    defaultValue: '',
  );
  static const whoeatsSupabaseUrl = String.fromEnvironment(
    'WHOEATS_SUPABASE_URL',
    defaultValue: '',
  );
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const whoeatsSupabaseAnonKey = String.fromEnvironment(
    'WHOEATS_SUPABASE_ANON_KEY',
    defaultValue: '',
  );
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );
  static const pandaOAuthUrl = String.fromEnvironment(
    'WHOEATS_PANDA_OAUTH_URL',
    defaultValue: '',
  );
  static const supabaseProfilesTable = String.fromEnvironment(
    'WHOEATS_SUPABASE_PROFILES_TABLE',
    defaultValue: '',
  );
  static const dbTablePrefix = String.fromEnvironment(
    'WHOEATS_DB_TABLE_PREFIX',
    defaultValue: '',
  );
  static const authRedirectUrl = String.fromEnvironment(
    whoeatsAuthRedirectEnvKey,
    defaultValue: '',
  );
  static const legacyAuthRedirectUrl = String.fromEnvironment(
    legacyValiarkAuthRedirectEnvKey,
    defaultValue: '',
  );
  static const defaultDevPlaceUuid = String.fromEnvironment(
    'WHOEATS_DEFAULT_DEV_PLACE_UUID',
    defaultValue: '',
  );
  static const termsOfServiceUrl = String.fromEnvironment(
    'WHOEATS_TERMS_URL',
    defaultValue: '',
  );
  static const privacyPolicyUrl = String.fromEnvironment(
    'WHOEATS_PRIVACY_URL',
    defaultValue: '',
  );
}

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

  static String get mapPinsApiUrl =>
      _pick(_DartDefines.mapPinsApiUrl, _env('WHOEATS_MAP_PINS_API_URL'));

  static String get placeDetailApiTemplate => _pick(
        _DartDefines.placeDetailApiTemplate,
        _env('WHOEATS_PLACE_DETAIL_API_TEMPLATE'),
      );

  static String get googleMapsWebApiKey => _pick(
        _DartDefines.googleMapsWebApiKey,
        _env('WHOEATS_GOOGLE_MAPS_WEB_API_KEY'),
      );

  static String get postedPinPlaceId =>
      _pick(_DartDefines.postedPinPlaceId, _env('WHOEATS_POSTED_PIN_PLACE_ID'));

  static String get postedPinPlaceName => _pick(
        _DartDefines.postedPinPlaceName,
        _env('WHOEATS_POSTED_PIN_PLACE_NAME'),
      );

  /// `WHOEATS_SUPABASE_URL`（dart-define / .env）または `SUPABASE_*`。
  static String get supabaseUrl {
    if (_DartDefines.whoeatsSupabaseUrl.isNotEmpty) {
      return _DartDefines.whoeatsSupabaseUrl;
    }
    if (_DartDefines.supabaseUrl.isNotEmpty) return _DartDefines.supabaseUrl;
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
    if (_DartDefines.whoeatsSupabaseAnonKey.isNotEmpty) {
      return _DartDefines.whoeatsSupabaseAnonKey;
    }
    if (_DartDefines.supabaseAnonKey.isNotEmpty) {
      return _DartDefines.supabaseAnonKey;
    }
    final a = _env('WHOEATS_SUPABASE_ANON_KEY');
    if (a.isNotEmpty) return a;
    return _env('SUPABASE_ANON_KEY');
  }

  static String get pandaOAuthUrl =>
      _pick(_DartDefines.pandaOAuthUrl, _env('WHOEATS_PANDA_OAUTH_URL'));

  /// Who eats 用プロフィール表。未設定時は `whoeats_users`。
  static String get supabaseProfilesTable {
    final v = _pick(
      _DartDefines.supabaseProfilesTable,
      _env('WHOEATS_SUPABASE_PROFILES_TABLE'),
    );
    return v.isNotEmpty ? v : 'whoeats_users';
  }

  /// ドメイン表の接頭辞（例: `whoeats_`）。未設定時は migration 0003 の既定 `whoeats_`。
  static String get dbTablePrefix {
    final v = _pick(_DartDefines.dbTablePrefix, _env('WHOEATS_DB_TABLE_PREFIX'));
    return v.isNotEmpty ? v : 'whoeats_';
  }

  /// メール確認・PKCE 戻り先（Supabase Dashboard の Redirect URLs と一致）。
  static String get authRedirectUrl {
    if (_DartDefines.authRedirectUrl.isNotEmpty) {
      return _DartDefines.authRedirectUrl;
    }
    final w = _env(whoeatsAuthRedirectEnvKey);
    if (w.isNotEmpty) return w;
    if (_DartDefines.legacyAuthRedirectUrl.isNotEmpty) {
      return _DartDefines.legacyAuthRedirectUrl;
    }
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
      _DartDefines.defaultDevPlaceUuid,
      _env('WHOEATS_DEFAULT_DEV_PLACE_UUID'),
    );
    return v.isNotEmpty ? v : fallbackDevPlaceUuid;
  }

  static bool get hasMapApi =>
      mapPinsApiUrl.isNotEmpty && placeDetailApiTemplate.isNotEmpty;
  static bool get hasGooglePlacesApi => googleMapsWebApiKey.isNotEmpty;
  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// 利用規約（HTTPS）。空のときはタップで準備中メッセージ。
  static String get termsOfServiceUrl =>
      _pick(_DartDefines.termsOfServiceUrl, _env('WHOEATS_TERMS_URL'));

  /// プライバシーポリシー（HTTPS）。
  static String get privacyPolicyUrl =>
      _pick(_DartDefines.privacyPolicyUrl, _env('WHOEATS_PRIVACY_URL'));
}
