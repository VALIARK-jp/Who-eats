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
    final path = _storagePathFromValue(storagePath);
    if (path == null || path.isEmpty) return null;
    try {
      return await client.storage
          .from(_bucket)
          .createSignedUrl(path, _ttlSeconds);
    } catch (_) {
      return null;
    }
  }

  /// プロフィール `icon_path`（storage path または旧 signed URL）を表示用 URL に。
  static Future<String?> resolveProfileIconUrl(
    SupabaseClient client,
    String iconPath,
  ) async {
    final trimmed = iconPath.trim();
    if (trimmed.isEmpty) return null;

    final path = _storagePathFromValue(trimmed);
    if (path != null && path.isNotEmpty) {
      try {
        return await client.storage
            .from(_bucket)
            .createSignedUrl(path, _ttlSeconds);
      } catch (_) {
        // fall through to legacy URL below
      }
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return null;
  }

  static String? _storagePathFromValue(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return trimmed;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;
    final segments = uri.pathSegments;
    final bucketIdx = segments.indexOf(_bucket);
    if (bucketIdx == -1 || bucketIdx >= segments.length - 1) {
      return null;
    }
    return segments.sublist(bucketIdx + 1).join('/');
  }
}
