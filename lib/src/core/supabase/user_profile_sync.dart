import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Ensures a row exists in [public.users] for the current auth user.
///
/// RLS allows insert when `auth.uid() = id`. [user_code] must match
/// `^@[A-Za-z0-9_]+$` and be unique; we derive a stable code from the auth UUID.
Future<void> syncCurrentUserProfile() async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return;

  final existing =
      await client.from('users').select('id').eq('id', user.id).maybeSingle();
  if (existing != null) {
    final email = user.email?.trim() ?? '';
    if (email.isNotEmpty) {
      try {
        await client.from('users').update({'email': email}).eq('id', user.id);
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

  final metaName = user.userMetadata?['name'];
  final name = (metaName is String && metaName.trim().isNotEmpty)
      ? metaName.trim()
      : (email.contains('@') ? email.split('@').first : 'User');

  final userCode = defaultUserCodeFromAuthId(user.id);

  try {
    await client.from('users').insert({
      'id': user.id,
      'user_code': userCode,
      'name': name,
      'email': safeEmail,
    });
  } on PostgrestException catch (e) {
    // Parallel listeners or retry: row may already exist.
    if (e.code == '23505') {
      return;
    }
    rethrow;
  }
}

/// Deterministic, unique-enough handle: `@` + 32 hex chars from UUID (no hyphens).
String defaultUserCodeFromAuthId(String authUserId) {
  final hex = authUserId.replaceAll('-', '');
  return '@$hex';
}
