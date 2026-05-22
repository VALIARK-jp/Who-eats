import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_tables.dart';
import '../../../core/supabase/user_profile_sync.dart';

const _kProfileSetupPrefix = 'whoeats_profile_setup_done_v1_';
const _kPendingEmailSignup = 'whoeats_pending_profile_setup_email_v1';
const _kAuthMetadataCompleteKey = 'profileSetupComplete';

final _userCodePattern = RegExp(r'^@[A-Za-z0-9_]+$');

class ProfileOnboardingStore {
  static String _key(String userId) => '$_kProfileSetupPrefix$userId';

  static Future<bool> isCompleted(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_key(userId)) ?? false) return true;

    final user = Supabase.instance.client.auth.currentUser;
    if (user?.id != userId) return false;
    if (_metadataSaysComplete(user!.userMetadata)) {
      await setCompleted(userId);
      return true;
    }
    return false;
  }

  static Future<void> setCompleted(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(userId), true);
    await _markCompleteInAuthMetadata();
  }

  static Future<void> requireSetup(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(userId));
  }

  static Future<void> markPendingEmailSignup(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPendingEmailSignup, email.trim().toLowerCase());
  }

  /// 確認メールから初回ログインしたときだけ [requireSetup] を有効化する。
  static Future<void> applyPendingEmailSignup({
    required String userId,
    String? email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getString(_kPendingEmailSignup);
    if (pending == null) return;

    final normalizedEmail = email?.trim().toLowerCase();
    if (normalizedEmail == null || normalizedEmail != pending) {
      await prefs.remove(_kPendingEmailSignup);
      return;
    }

    await prefs.remove(_kPendingEmailSignup);
    if (await isCompleted(userId)) return;
    await requireSetup(userId);
  }

  /// 表示名・ユーザーコードがユーザー入力済みか（再ログイン時の分岐用）。
  static bool isProfileFieldsComplete({
    required String name,
    required String userCode,
  }) {
    final normalizedName = name.trim();
    final normalizedCode = userCode.trim();
    if (normalizedName.isEmpty || normalizedName == 'User') {
      return false;
    }
    if (normalizedCode.isEmpty || !_userCodePattern.hasMatch(normalizedCode)) {
      return false;
    }
    return true;
  }

  /// 端末キャッシュ → DB（name / user_code）→ メール確認待ち pending の順で判定。
  static Future<bool> resolveSetupComplete({
    required String userId,
    String? email,
  }) async {
    if (await isCompleted(userId)) return true;

    try {
      await syncCurrentUserProfile();
      final row = await Supabase.instance.client
          .from(SupabaseTables.profiles)
          .select('name, user_code')
          .eq('id', userId)
          .maybeSingle();
      if (row != null &&
          isProfileFieldsComplete(
            name: row['name'] as String? ?? '',
            userCode: row['user_code'] as String? ?? '',
          )) {
        await setCompleted(userId);
        return true;
      }
    } catch (_) {}

    await applyPendingEmailSignup(userId: userId, email: email);
    return isCompleted(userId);
  }

  static bool _metadataSaysComplete(Map<String, dynamic>? metadata) {
    final value = metadata?[_kAuthMetadataCompleteKey];
    return value == true || value == 'true';
  }

  static Future<void> _markCompleteInAuthMetadata() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    if (_metadataSaysComplete(user.userMetadata)) return;
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {_kAuthMetadataCompleteKey: true}),
      );
    } catch (_) {
      // prefs / DB があれば次回まで問題ない
    }
  }
}
