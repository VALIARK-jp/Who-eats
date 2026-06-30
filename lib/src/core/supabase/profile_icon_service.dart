import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_tables.dart';

class ProfileIconService {
  ProfileIconService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _bucket = 'post-images';

  /// Storage のみアップロード（初回プロフィール保存前は DB 更新しない）。
  Future<String> uploadProfileIcon(File file) async {
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
    return path;
  }

  /// 既存プロフィール行がある前提で icon_path を更新する。
  Future<String> uploadAndSaveProfileIcon(File file) async {
    final path = await uploadProfileIcon(file);
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('Not signed in');
    }

    await _client
        .from(SupabaseTables.profiles)
        .update({'icon_path': path})
        .eq('id', uid);
    return path;
  }

  String _guessExt(String p) {
    final lower = p.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    return 'jpg';
  }
}
