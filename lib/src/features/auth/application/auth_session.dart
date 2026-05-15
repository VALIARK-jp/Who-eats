import 'package:supabase_flutter/supabase_flutter.dart';

/// サーバーへ通知する通常ログアウト。
Future<void> signOutCurrentUser() => Supabase.instance.client.auth.signOut();

/// 端末に保存されたセッションだけ消す（ネットワーク不要）。OAuth 失敗や DNS 不調の切り戻し用。
Future<void> clearLocalAuthSession() =>
    Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
