import '../config/app_config.dart';

/// valiark-dev 共有 DB: プロフィール行は `whoeats_users`（`WHOEATS_SUPABASE_PROFILES_TABLE` で上書き可）。
abstract final class SupabaseTables {
  static String get profiles => AppConfig.supabaseProfilesTable;

  static String get posts => _prefixed('posts');
  static String get places => _prefixed('places');
  static String get postImages => _prefixed('post_images');

  static String _prefixed(String base) {
    final p = AppConfig.dbTablePrefix;
    if (p.isEmpty) return base;
    return '$p$base';
  }
}
