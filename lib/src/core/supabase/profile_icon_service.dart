import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_tables.dart';

class ProfileIconService {
  ProfileIconService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _bucket = 'post-images';

  Future<String> uploadAndSaveProfileIcon(File file) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('Not signed in');
    }

    final ext = _guessExt(file.path);
    final path = '$uid/profile_icon_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final contentType = ext == 'png'
        ? 'image/png'
        : ext == 'webp'
        ? 'image/webp'
        : 'image/jpeg';

    await _client.storage.from(_bucket).upload(
      path,
      file,
      fileOptions: FileOptions(contentType: contentType, upsert: true),
    );

    final signed = await _client.storage
        .from(_bucket)
        .createSignedUrl(path, 60 * 60 * 24 * 365);

    await _client
        .from(SupabaseTables.profiles)
        .update({'icon_path': signed})
        .eq('id', uid);
    return signed;
  }

  String _guessExt(String p) {
    final lower = p.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    return 'jpg';
  }
}
