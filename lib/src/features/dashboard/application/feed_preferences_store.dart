import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/app_entities.dart';

/// ホームタイムラインのデフォルト表示範囲（端末ローカル、ユーザーごと）。
class FeedPreferencesStore {
  static String _key(String userId) =>
      'whoeats_default_feed_timeline_scope_v1_$userId';

  static Future<FeedTimelineScope> loadDefaultScope(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return FeedTimelineScopeX.fromStorage(prefs.getString(_key(userId)));
  }

  static Future<void> saveDefaultScope(
    String userId,
    FeedTimelineScope scope,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(userId), scope.storageValue);
  }
}
