import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../application/auth_service.dart';
import 'email_auth_page.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _auth = AuthService();
  StreamSubscription<AuthState>? _authSub;
  bool _authInFlight = false;
  String? _authInFlightProvider;

  @override
  void initState() {
    super.initState();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn && mounted) {
        _popAfterAuth();
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  void _popAfterAuth() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    });
  }

  void _finishNativeAuth() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
      });
    });
  }

  Future<void> _runAuth(String provider, Future<void> Function() action) async {
    if (_authInFlight) return;
    setState(() {
      _authInFlight = true;
      _authInFlightProvider = provider;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) _showError(_formatError(e));
    } finally {
      if (mounted) {
        setState(() {
          _authInFlight = false;
          _authInFlightProvider = null;
        });
      }
    }
  }

  String _formatError(Object e) => e.toString().replaceFirst('Exception: ', '');

  void _showError(String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('エラー'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.maybePop(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ログイン',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'LINE・Apple・メールのいずれかでログインできます。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSubtle,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            _authButton(
              provider: 'email',
              icon: Icons.email_outlined,
              label: 'メールアドレスでログイン',
              onPressed: () {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const EmailAuthPage(showSignupTab: false),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _authButton(
              provider: 'line',
              icon: Icons.chat,
              label: 'LINEでログイン',
              color: const Color(0xFF00C300),
              foreground: Colors.white,
              onPressed: () => _runAuth('line', () async {
                await _auth.signInWithLine();
                if (mounted) _finishNativeAuth();
              }),
            ),
            if (Theme.of(context).platform == TargetPlatform.iOS) ...[
              const SizedBox(height: 10),
              _authButton(
                provider: 'apple',
                icon: Icons.apple,
                label: 'Appleでログイン',
                color: Colors.black,
                foreground: Colors.white,
                onPressed: () => _runAuth('apple', () async {
                  await _auth.signInWithApple();
                  if (mounted) _finishNativeAuth();
                }),
              ),
            ],
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const SignupPage()),
                );
              },
              child: const Text('新規登録はこちら'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _authButton({
    required String provider,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
    Color? foreground,
  }) {
    final loading = _authInFlight && _authInFlightProvider == provider;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton.icon(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color ?? AppColors.cardElevated,
          foregroundColor: foreground ?? AppColors.textPrimary,
        ),
        icon: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon),
        label: Text(label),
      ),
    );
  }
}
