import '../config/app_config.dart';

/// valiark-dev 共有 DB: プロフィール行は `whoeats_users`（`WHOEATS_SUPABASE_PROFILES_TABLE` で上書き可）。
abstract final class SupabaseTables {
  static String get profiles => AppConfig.supabaseProfilesTable;

  /// 投稿作者の embed（`post_reactions` 経由の many-to-many と区別する）。
  static String get postAuthorEmbed => '$profiles!posts_user_fk';

  static String get posts => _prefixed('posts');
  static String get places => _prefixed('places');
  static String get postImages => _prefixed('post_images');
  static String get follows => _prefixed('follows');
  static String get postReactions => _prefixed('post_reactions');
  static String get postComments => _prefixed('post_comments');
  static String get profilePins => _prefixed('profile_pins');
  static String get postFavorites => _prefixed('post_favorites');
  static String get postCompanions => _prefixed('post_companions');
  static String get blocks => _prefixed('blocks');
  static String get reports => _prefixed('reports');
  static String get devicePushTokens => _prefixed('device_push_tokens');
  static String get notifications => _prefixed('notifications');

  static String _prefixed(String base) {
    final p = AppConfig.dbTablePrefix;
    if (p.isEmpty) return base;
    return '$p$base';
  }
}
