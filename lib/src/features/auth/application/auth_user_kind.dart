import 'package:supabase_flutter/supabase_flutter.dart';

/// メール＋パスワードでサインインできるユーザーか（LINE / Apple のみは false）。
bool isEmailPasswordUser(User? user) {
  if (user == null) return false;

  final identities = user.identities;
  if (identities != null && identities.isNotEmpty) {
    return identities.any((identity) => identity.provider == 'email');
  }

  final provider = user.appMetadata['provider'];
  if (provider == 'email') return true;

  final providers = user.appMetadata['providers'];
  if (providers is List && providers.contains('email')) return true;

  return false;
}
