import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../dashboard/presentation/pages/app_shell_page.dart';
import '../application/profile_onboarding_store.dart';
import 'password_recovery_page.dart';
import 'profile_setup_page.dart';

/// ログイン後: 初回プロフィール入力 → メインシェル（Panda Talk の AuthGate 同型）。
class AuthShellPage extends StatefulWidget {
  const AuthShellPage({super.key});

  @override
  State<AuthShellPage> createState() => _AuthShellPageState();
}

class _AuthShellPageState extends State<AuthShellPage> {
  bool _prefsLoaded = false;
  bool _profileSetupDone = false;
  bool _passwordRecoveryPending = false;
  int _loadGeneration = 0;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _load();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        _onPasswordRecovery();
      }
      _load();
    });
  }

  void _onPasswordRecovery() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      setState(() => _passwordRecoveryPending = true);
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _profileSetupDone = true;
        _prefsLoaded = true;
      });
      return;
    }

    // ログイン済みは DB で name / user_code を確認するまで AppShell に入れない。
    if (mounted) {
      setState(() {
        _profileSetupDone = false;
        _prefsLoaded = false;
      });
    }

    final done = await ProfileOnboardingStore.resolveSetupComplete(
      userId: user.id,
      email: user.email,
    );
    if (!mounted || generation != _loadGeneration) return;
    setState(() {
      _profileSetupDone = done;
      _prefsLoaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_prefsLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_passwordRecoveryPending) {
      return PasswordRecoveryPage(
        onComplete: () {
          if (mounted) setState(() => _passwordRecoveryPending = false);
        },
      );
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && !_profileSetupDone) {
      return ProfileSetupPage(
        onComplete: _load,
      );
    }

    return const AppShellPage();
  }
}
