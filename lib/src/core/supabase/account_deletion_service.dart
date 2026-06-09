import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_tables.dart';

/// Permanently deletes the signed-in user's auth identity and app data.
class AccountDeletionService {
  AccountDeletionService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _postImagesBucket = 'post-images';

  Future<void> deleteCurrentAccount() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('Not signed in');
    }

    await _deleteUserStorageBestEffort(uid);

    await _client.rpc('delete_own_account');

    try {
      await _client.auth.signOut(scope: SignOutScope.local);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[AccountDeletionService] signOut after delete: $e\n$st');
      }
    }
  }

  Future<void> _deleteUserStorageBestEffort(String uid) async {
    final paths = <String>{};

    try {
      final profile = await _client
          .from(SupabaseTables.profiles)
          .select('icon_path')
          .eq('id', uid)
          .maybeSingle();
      final iconPath = (profile?['icon_path'] ?? '').toString().trim();
      if (iconPath.isNotEmpty &&
          !iconPath.startsWith('http://') &&
          !iconPath.startsWith('https://')) {
        paths.add(iconPath);
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[AccountDeletionService] profile icon lookup: $e\n$st');
      }
    }

    try {
      final tImages = SupabaseTables.postImages;
      final rows = await _client
          .from(SupabaseTables.posts)
          .select('$tImages(storage_path)')
          .eq('user_id', uid);
      for (final raw in (rows as List<dynamic>)) {
        final row = raw as Map<String, dynamic>;
        final images = row[tImages];
        if (images is List) {
          for (final image in images) {
            if (image is Map<String, dynamic>) {
              final path = (image['storage_path'] ?? '').toString().trim();
              if (path.isNotEmpty) paths.add(path);
            }
          }
        } else if (images is Map<String, dynamic>) {
          final path = (images['storage_path'] ?? '').toString().trim();
          if (path.isNotEmpty) paths.add(path);
        }
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[AccountDeletionService] post image lookup: $e\n$st');
      }
    }

    if (paths.isEmpty) return;

    try {
      await _client.storage.from(_postImagesBucket).remove(paths.toList());
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[AccountDeletionService] storage remove: $e\n$st');
      }
    }
  }
}
