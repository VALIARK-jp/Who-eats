import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/user_profile_sync.dart';
import 'email_auth_page.dart';

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

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;
    _authSub = client.auth.onAuthStateChange.listen(_onAuthState);
    final session = client.auth.currentSession;
    if (session != null) {
      _scheduleProfileSync(session.user.id);
    }
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
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      return widget.child;
    }
    return const EmailAuthPage();
  }
}
