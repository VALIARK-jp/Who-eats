import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/user_profile_sync.dart';
import 'sign_in_page.dart';

/// Supabase セッションに応じて [child] またはログイン画面を出す。
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.child});

  final Widget child;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription<AuthState> _authSub;
  String? _profileSyncedForUserId;
  bool _bootstrapDone = false;

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;
    _authSub = client.auth.onAuthStateChange.listen(_onAuthState);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrapSession());
    });
  }

  /// 期限切れセッションを抱えたままホームに入らないよう、起動時に一度だけ整理する。
  Future<void> _bootstrapSession() async {
    final auth = Supabase.instance.client.auth;
    final session = auth.currentSession;
    if (session == null) {
      if (mounted) setState(() => _bootstrapDone = true);
      return;
    }
    if (!session.isExpired) {
      _scheduleProfileSync(session.user.id);
      if (mounted) setState(() => _bootstrapDone = true);
      return;
    }
    try {
      await auth.refreshSession();
      final after = auth.currentSession;
      if (after != null && !after.isExpired) {
        _scheduleProfileSync(after.user.id);
      }
    } catch (e, st) {
      debugPrint('AuthGate: refreshSession failed, clearing local session: $e\n$st');
      await auth.signOut(scope: SignOutScope.local);
    }
    if (mounted) setState(() => _bootstrapDone = true);
  }

  void _onAuthState(AuthState data) {
    final session = data.session;
    setState(() {
      if (session == null) {
        _profileSyncedForUserId = null;
      }
    });
    if (session != null) {
      _scheduleProfileSync(session.user.id);
    }
  }

  void _scheduleProfileSync(String userId) {
    if (_profileSyncedForUserId == userId) return;
    syncCurrentUserProfile().then((_) {
      if (!mounted) return;
      if (Supabase.instance.client.auth.currentUser?.id != userId) return;
      setState(() => _profileSyncedForUserId = userId);
    }).catchError((Object e, StackTrace st) {
      debugPrint('AuthGate: user profile sync failed: $e\n$st');
    });
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_bootstrapDone) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null && !session.isExpired) {
      return widget.child;
    }
    return const SignInPage();
  }
}
