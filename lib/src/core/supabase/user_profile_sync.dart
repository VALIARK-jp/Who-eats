import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_tables.dart';

/// 共有 Supabase の [SupabaseTables.profiles] に、現在の auth ユーザー行を用意する。
///
/// name / user_code は自動入力しない。未設定のときは null のままにし、
/// [ProfileSetupPage] でユーザーが手入力する。
Future<void> syncCurrentUserProfile() async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return;

  final table = SupabaseTables.profiles;
  final email = user.email?.trim() ?? '';
  final safeEmail = email.isNotEmpty
      ? email
      : '${user.id}@users.who-eats.placeholder';

  final existing = await client
      .from(table)
      .select('id')
      .eq('id', user.id)
      .maybeSingle();

  if (existing != null) {
    if (email.isNotEmpty) {
      try {
        await client.from(table).update({'email': email}).eq('id', user.id);
      } catch (e, st) {
        debugPrint('syncCurrentUserProfile: email update skipped: $e\n$st');
      }
    }
    return;
  }

  try {
    await client.from(table).insert({
      'id': user.id,
      'email': safeEmail,
    });
  } on PostgrestException catch (e) {
    if (e.code == '23505') {
      return;
    }
    rethrow;
  }
}
