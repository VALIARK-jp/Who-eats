import 'package:shared_preferences/shared_preferences.dart';

const _kProfileSetupPrefix = 'whoeats_profile_setup_done_v1_';
const _kPendingEmailSignup = 'whoeats_pending_profile_setup_email_v1';

class ProfileOnboardingStore {
  static String _key(String userId) => '$_kProfileSetupPrefix$userId';

  static Future<bool> isCompleted(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(userId)) ?? false;
  }

  static Future<void> setCompleted(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(userId), true);
  }

  static Future<void> requireSetup(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(userId));
  }

  static Future<void> markPendingEmailSignup(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPendingEmailSignup, email.trim().toLowerCase());
  }

  static Future<void> applyPendingEmailSignup({
    required String userId,
    String? email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getString(_kPendingEmailSignup);
    if (pending == null) return;
    if (email != null && email.trim().toLowerCase() != pending) return;
    await requireSetup(userId);
    await prefs.remove(_kPendingEmailSignup);
  }
}
