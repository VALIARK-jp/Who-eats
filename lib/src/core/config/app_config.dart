import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Supabase / 認証まわりの環境変数を読む（`WHOEATS_*` 主体、`SUPABASE_*` はフォールバック）。
class AppConfig {
  static String _env(String key) {
    final value = dotenv.env[key];
    return value == null ? '' : value.trim();
  }

  static String get mapPinsApiUrl => _env('WHOEATS_MAP_PINS_API_URL');
  static String get placeDetailApiTemplate =>
      _env('WHOEATS_PLACE_DETAIL_API_TEMPLATE');
  static String get googleMapsWebApiKey =>
      _env('WHOEATS_GOOGLE_MAPS_WEB_API_KEY');
  static String get postedPinPlaceId => _env('WHOEATS_POSTED_PIN_PLACE_ID');
  static String get postedPinPlaceName =>
      _env('WHOEATS_POSTED_PIN_PLACE_NAME');

  /// `WHOEATS_SUPABASE_URL` または `SUPABASE_URL`。
  static String get supabaseUrl {
    final w = _env('WHOEATS_SUPABASE_URL');
    return w.isNotEmpty ? w : _env('SUPABASE_URL');
  }

  /// `WHOEATS_SUPABASE_PUBLISHABLE_KEY` または `SUPABASE_ANON_KEY`。
  static String get supabasePublishableKey {
    final w = _env('WHOEATS_SUPABASE_PUBLISHABLE_KEY');
    return w.isNotEmpty ? w : _env('SUPABASE_ANON_KEY');
  }

  /// ブラウザ起点のログイン URL（任意）。他クライアントと env 名を揃えるため `WHOEATS_PANDA_OAUTH_URL` を使用。
  static String get pandaOAuthUrl => _env('WHOEATS_PANDA_OAUTH_URL');

  /// Who eats 用プロフィール表（`id = auth.users.id`）。未設定時は `whoeats_users`
  ///（`0003_prefix_whoeats_domain_tables.sql` で `users` → `whoeats_users` にリネーム）。
  static String get supabaseProfilesTable {
    final v = _env('WHOEATS_SUPABASE_PROFILES_TABLE');
    return v.isNotEmpty ? v : 'whoeats_users';
  }

  /// ドメイン表の接頭辞（例: `whoeats_`）。空なら非接頭辞（旧ローカル migration 互換）。
  static String get dbTablePrefix => _env('WHOEATS_DB_TABLE_PREFIX');

/// メール確認・PKCE 戻り先（Supabase Auth に登録したリダイレクト URL と一致させる）。
  static String get valiarkAuthRedirectUrl {
    final v = _env('VALIARK_AUTH_REDIRECT_URL');
    return v.isNotEmpty ? v : 'io.valiark.auth://callback';
  }

  /// Matches seeded row in `0002_post_images_bucket_dev_place.sql` when env unset.
  static const String fallbackDevPlaceUuid =
      '00000000-0000-4000-8000-000000000001';

  static String get defaultDevPlaceUuid {
    final v = _env('WHOEATS_DEFAULT_DEV_PLACE_UUID');
    return v.isNotEmpty ? v : fallbackDevPlaceUuid;
  }

  static bool get hasMapApi =>
      mapPinsApiUrl.isNotEmpty && placeDetailApiTemplate.isNotEmpty;
  static bool get hasGooglePlacesApi => googleMapsWebApiKey.isNotEmpty;
  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}
