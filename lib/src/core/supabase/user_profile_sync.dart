import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_tables.dart';

/// 共有 Supabase の [SupabaseTables.profiles] に、現在の auth ユーザー行を用意する。
///
/// Valiark 運用: デフォルトは `whoeats_users`（`id = auth.users.id`）。`0001_init` の
/// `user_code` / `name` / `email` / `icon_path` など。`WHOEATS_SUPABASE_PROFILES_TABLE` で別表に切替可。
Future<void> syncCurrentUserProfile({
  String? displayName,
  String? iconUrl,
}) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return;

  final table = SupabaseTables.profiles;

  final existing = await client
      .from(table)
      .select('id')
      .eq('id', user.id)
      .maybeSingle();
  if (existing != null) {
    final email = user.email?.trim() ?? '';
    if (email.isNotEmpty) {
      try {
        await client.from(table).update({'email': email}).eq('id', user.id);
      } catch (e, st) {
        debugPrint('syncCurrentUserProfile: email update skipped: $e\n$st');
      }
    }
    return;
  }

  final email = user.email?.trim() ?? '';
  final safeEmail = email.isNotEmpty
      ? email
      : '${user.id}@users.who-eats.placeholder';

  final seedName = displayName?.trim();
  final name = seedName != null && seedName.isNotEmpty
      ? seedName
      : (email.contains('@') ? email.split('@').first : 'User');

  final userCode = defaultUserCodeFromAuthId(user.id);

  try {
    await client.from(table).insert({
      'id': user.id,
      'user_code': userCode,
      'name': name,
      'email': safeEmail,
      if (iconUrl != null && iconUrl.trim().isNotEmpty)
        'icon_path': iconUrl.trim(),
    });
  } on PostgrestException catch (e) {
    if (e.code == '23505') {
      return;
    }
    rethrow;
  }
}

/// `users_user_code_format_check`: ^@[A-Za-z0-9_]+$（暫定 @w + UUID hex）
String defaultUserCodeFromAuthId(String authUserId) {
  final hex = authUserId.replaceAll('-', '');
  final tail = hex.length >= 29 ? hex.substring(0, 29) : hex.padRight(29, '0');
  return '@w$tail';
}
