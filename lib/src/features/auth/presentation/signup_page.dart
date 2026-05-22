import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../application/auth_service.dart';
import '../widgets/auth_attribution_notice_block.dart';
import '../widgets/terms_consent_footer.dart';
import 'email_auth_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _auth = AuthService();
  StreamSubscription<AuthState>? _authSub;
  bool _authInFlight = false;

  @override
  void initState() {
    super.initState();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn && mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  void _finishNativeAuth() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
      });
    });
  }

  Future<void> _runNative(Future<void> Function() action) async {
    if (_authInFlight) return;
    setState(() => _authInFlight = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _authInFlight = false);
    }
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
              '新規登録',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'アカウントを作成して、投稿・友達・記録などすべての機能を使えます。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSubtle,
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _authInFlight
                    ? null
                    : () {
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                const EmailAuthPage(showLoginTab: false),
                          ),
                        );
                      },
                icon: const Icon(Icons.email_outlined),
                label: const Text('メールで新規登録'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00C300),
                ),
                onPressed: _authInFlight
                    ? null
                    : () => _runNative(() async {
                          await _auth.signInWithLine(
                            flow: NativeAuthFlow.signup,
                          );
                          if (mounted) _finishNativeAuth();
                        }),
                icon: const Icon(Icons.chat),
                label: const Text('LINEで新規登録'),
              ),
            ),
            if (Theme.of(context).platform == TargetPlatform.iOS) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _authInFlight
                      ? null
                      : () => _runNative(() async {
                            await _auth.signInWithApple(
                              flow: NativeAuthFlow.signup,
                            );
                            if (mounted) _finishNativeAuth();
                          }),
                  icon: const Icon(Icons.apple),
                  label: const Text('Appleで新規登録'),
                ),
              ),
            ],
            const SizedBox(height: 32),
            const AuthAttributionNoticeBlock(),
            const SizedBox(height: 16),
            const TermsConsentFooter(),
          ],
        ),
      ),
    );
  }
}
