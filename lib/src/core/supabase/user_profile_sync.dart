import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/application/profile_onboarding_store.dart';

/// 共有 Supabase の `whoeats_users` に、現在の auth ユーザー行を用意する。
///
/// name / user_code は自動入力しない。未設定のときは null のままにし、
/// [ProfileSetupPage] でユーザーが手入力する。
Future<void> syncCurrentUserProfile() async {
  final client = Supabase.instance.client;
  if (client.auth.currentUser == null) return;

  try {
    await client.rpc('ensure_whoeats_user_row');
  } on PostgrestException catch (e, st) {
    if (kDebugMode) {
      debugPrint('syncCurrentUserProfile RPC failed: ${e.message}\n$st');
    }
    throw Exception(_rpcFailureMessage(e, 'ensure_whoeats_user_row'));
  }
}

/// 初回プロフィール入力・設定画面から name / user_code 等を保存する。
///
/// DB 関数 `save_whoeats_profile` で upsert し、返却行で永続化を確認する。
Future<void> saveWhoEatsProfileFields({
  required String userId,
  required String email,
  required String name,
  required String userCode,
  String? bio,
  String? iconPath,
}) async {
  final client = Supabase.instance.client;
  final currentUser = client.auth.currentUser;
  if (currentUser == null || currentUser.id != userId) {
    throw Exception('ログインセッションが無効です');
  }

  final Map<dynamic, dynamic> row;
  try {
    final result = await client.rpc(
      'save_whoeats_profile',
      params: {
        'p_name': name,
        'p_user_code': userCode,
        'p_bio': (bio == null || bio.trim().isEmpty) ? null : bio.trim(),
        'p_icon_path':
            (iconPath != null &&
                iconPath.isNotEmpty &&
                !iconPath.startsWith('http'))
            ? iconPath
            : null,
      },
    );
    if (result is! Map) {
      throw Exception('プロフィールを保存できませんでした');
    }
    row = result;
  } on PostgrestException catch (e) {
    throw Exception(_rpcFailureMessage(e, 'save_whoeats_profile'));
  }

  final savedName = row['name'] as String?;
  final savedCode = row['user_code'] as String?;
  if (ProfileOnboardingStore.needsProfileSetup(
    name: savedName,
    userCode: savedCode,
  )) {
    throw Exception('プロフィールを保存できませんでした');
  }
}

String _rpcFailureMessage(PostgrestException e, String functionName) {
  final msg = e.message.trim();
  if (msg.contains(functionName) ||
      msg.contains('Could not find the function') ||
      e.code == '42883') {
    return 'サーバー側のプロフィール設定が未完了です。しばらくしてから再度お試しください';
  }
  if (msg.isNotEmpty) return msg;
  return 'プロフィールを保存できませんでした';
}
