import 'package:supabase_flutter/supabase_flutter.dart';

/// メール＋パスワードでサインインできるユーザーか（LINE / Apple / Google は false）。
bool isEmailPasswordUser(User? user) {
  if (user == null) return false;

  // ネイティブの LINE / Apple ログインは OTP 発行のために内部で 'email' identity を
  // 作成することがあり、実際にはパスワードを持たない。primary provider がこれらの
  // ソーシャルログインの場合は、パスワード変更の対象外として除外する。
  const socialProviders = {'line', 'apple', 'google', 'facebook', 'twitter'};
  final provider = (user.appMetadata['provider'] as String?)?.trim();
  if (provider != null && socialProviders.contains(provider)) {
    return false;
  }

  final identities = user.identities;
  if (identities != null && identities.isNotEmpty) {
    return identities.any((identity) => identity.provider == 'email');
  }

  if (provider == 'email') return true;

  final providers = user.appMetadata['providers'];
  if (providers is List && providers.contains('email')) return true;

  return false;
}
