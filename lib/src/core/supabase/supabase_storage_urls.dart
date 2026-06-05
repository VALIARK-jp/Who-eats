import 'package:supabase_flutter/supabase_flutter.dart';

/// Signed URLs for `post-images` bucket paths.
abstract final class SupabaseStorageUrls {
  static const _bucket = 'post-images';
  static const _ttlSeconds = 60 * 60 * 24 * 7;

  static Future<String?> signedPostImage(
    SupabaseClient client,
    String storagePath,
  ) async {
    if (storagePath.isEmpty) return null;
    if (storagePath.startsWith('http://') ||
        storagePath.startsWith('https://')) {
      return storagePath;
    }
    try {
      return await client.storage
          .from(_bucket)
          .createSignedUrl(storagePath, _ttlSeconds);
    } catch (_) {
      return null;
    }
  }
}
