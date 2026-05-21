import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../dashboard/presentation/pages/app_shell_page.dart';
import '../application/profile_onboarding_store.dart';
import 'profile_setup_page.dart';

/// ログイン後: 初回プロフィール入力 → メインシェル（Panda Talk の AuthGate 同型）。
class AuthShellPage extends StatefulWidget {
  const AuthShellPage({super.key});

  @override
  State<AuthShellPage> createState() => _AuthShellPageState();
}

class _AuthShellPageState extends State<AuthShellPage> {
  bool? _prefsLoaded;
  bool _profileSetupDone = true;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _load();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      _load();
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _profileSetupDone = true;
          _prefsLoaded = true;
        });
      }
      return;
    }
    final done = await ProfileOnboardingStore.resolveSetupComplete(
      userId: user.id,
      email: user.email,
    );
    if (mounted) {
      setState(() {
        _profileSetupDone = done;
        _prefsLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_prefsLoaded != true) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && !_profileSetupDone) {
      return ProfileSetupPage(
        onComplete: () {
          if (mounted) setState(() => _profileSetupDone = true);
        },
      );
    }

    return const AppShellPage();
  }
}
