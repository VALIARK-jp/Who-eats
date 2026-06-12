import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_tables.dart';
import '../../../core/supabase/user_profile_sync.dart';

const _kProfileSetupPrefix = 'whoeats_profile_setup_done_v1_';
const _kAuthMetadataCompleteKey = 'profileSetupComplete';

class ProfileOnboardingStore {
  static String _key(String userId) => '$_kProfileSetupPrefix$userId';

  static Future<void> setCompleted(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(userId), true);
    await _markCompleteInAuthMetadata();
  }

  static Future<void> requireSetup(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(userId));
  }

  /// アカウント削除後に端末キャッシュを消す。
  static Future<void> clearForUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(userId));
  }

  /// name / user_code が未設定なら初回入力が必要（表示用の「ユーザー」は含めない）。
  static bool needsProfileSetup({String? name, String? userCode}) {
    final normalizedName = name?.trim() ?? '';
    final normalizedCode = userCode?.trim() ?? '';
    if (normalizedName.isEmpty || normalizedName == 'User') {
      return true;
    }
    return normalizedCode.isEmpty;
  }

  /// DB の name / user_code を正とする。端末キャッシュや auth metadata だけでは完了扱いにしない。
  static Future<bool> resolveSetupComplete({
    required String userId,
    String? email,
  }) async {
    try {
      await syncCurrentUserProfile();
      final row = await Supabase.instance.client
          .from(SupabaseTables.profiles)
          .select('name, user_code')
          .eq('id', userId)
          .maybeSingle();

      if (row != null &&
          !needsProfileSetup(
            name: row['name'] as String?,
            userCode: row['user_code'] as String?,
          )) {
        await setCompleted(userId);
        return true;
      }

      await requireSetup(userId);
      return false;
    } catch (_) {
      await requireSetup(userId);
      return false;
    }
  }

  static Future<void> _markCompleteInAuthMetadata() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final metadata = user.userMetadata;
    final value = metadata?[_kAuthMetadataCompleteKey];
    if (value == true || value == 'true') return;
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {_kAuthMetadataCompleteKey: true}),
      );
    } catch (_) {
      // prefs / DB があれば次回まで問題ない
    }
  }
}
