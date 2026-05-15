import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase セッション終了の単一入口（プロフィール等から呼ぶ）。
Future<void> signOutCurrentUser() => Supabase.instance.client.auth.signOut();
