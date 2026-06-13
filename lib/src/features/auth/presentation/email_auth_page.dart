import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../dashboard/presentation/controllers/app_shell_controller.dart';
import '../application/auth_service.dart';
import '../widgets/auth_attribution_notice_block.dart';
import '../widgets/terms_consent_footer.dart';

/// メール＋パスワード（[AuthService] / [AppConfig.authRedirectUrl] 経由）。
class EmailAuthPage extends StatefulWidget {
  const EmailAuthPage({
    super.key,
    this.initialTab = 0,
    this.showSignupTab = true,
    this.showLoginTab = true,
  });

  final int initialTab;
  final bool showSignupTab;
  final bool showLoginTab;

  @override
  State<EmailAuthPage> createState() => _EmailAuthPageState();
}

class _EmailAuthPageState extends State<EmailAuthPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  StreamSubscription<AuthState>? _authSub;
  final _auth = AuthService();

  final _loginFormKey = GlobalKey<FormState>();
  final _signupFormKey = GlobalKey<FormState>();
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _signupEmailController = TextEditingController();
  final _signupPasswordController = TextEditingController();
  final _signupConfirmPasswordController = TextEditingController();
  final _displayNameController = TextEditingController();

  bool _isLoading = false;
  bool _showLoginPassword = false;
  bool _showSignupPassword = false;
  bool _showConfirmPassword = false;
  String? _signupError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn && mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _authSub?.cancel();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _signupEmailController.dispose();
    _signupPasswordController.dispose();
    _signupConfirmPasswordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showTabs = widget.showSignupTab && widget.showLoginTab;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          showTabs
              ? 'メール認証'
              : (widget.showLoginTab ? 'ログイン' : '新規登録'),
        ),
        bottom: showTabs
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'ログイン'),
                  Tab(text: '新規登録'),
                ],
              )
            : null,
      ),
      body: showTabs
          ? TabBarView(
              controller: _tabController,
              children: [_buildLoginForm(), _buildSignupForm()],
            )
          : (widget.showLoginTab ? _buildLoginForm() : _buildSignupForm()),
    );
  }

  Widget _buildLoginForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _loginFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _loginEmailController,
              decoration: const InputDecoration(labelText: 'メールアドレス'),
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.isEmpty) return 'メールアドレスを入力してください';
                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
                  return '正しいメールアドレスを入力してください';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _loginPasswordController,
              decoration: InputDecoration(
                labelText: 'パスワード',
                suffixIcon: IconButton(
                  icon: Icon(
                    _showLoginPassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () =>
                      setState(() => _showLoginPassword = !_showLoginPassword),
                ),
              ),
              obscureText: !_showLoginPassword,
              validator: (v) =>
                  v == null || v.isEmpty ? 'パスワードを入力してください' : null,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _isLoading ? null : _signIn,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('ログイン'),
            ),
            TextButton(
              onPressed: _resetPassword,
              child: const Text('パスワードを忘れた場合'),
            ),
            const SizedBox(height: 24),
            const TermsConsentFooter(),
            const SizedBox(height: 16),
            const AuthAttributionNoticeBlock(showCreatedByHeader: false),
          ],
        ),
      ),
    );
  }

  Widget _buildSignupForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _signupFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _displayNameController,
              decoration: const InputDecoration(labelText: '表示名'),
              validator: (v) =>
                  v == null || v.isEmpty ? '表示名を入力してください' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _signupEmailController,
              decoration: const InputDecoration(labelText: 'メールアドレス'),
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.isEmpty) return 'メールアドレスを入力してください';
                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
                  return '正しいメールアドレスを入力してください';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _signupPasswordController,
              decoration: InputDecoration(
                labelText: 'パスワード',
                suffixIcon: IconButton(
                  icon: Icon(
                    _showSignupPassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () => setState(
                    () => _showSignupPassword = !_showSignupPassword,
                  ),
                ),
              ),
              obscureText: !_showSignupPassword,
              validator: (v) {
                if (v == null || v.isEmpty) return 'パスワードを入力してください';
                if (v.length < 6) return 'パスワードは6文字以上で入力してください';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _signupConfirmPasswordController,
              decoration: InputDecoration(
                labelText: 'パスワード確認',
                suffixIcon: IconButton(
                  icon: Icon(
                    _showConfirmPassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () => setState(
                    () => _showConfirmPassword = !_showConfirmPassword,
                  ),
                ),
              ),
              obscureText: !_showConfirmPassword,
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'パスワード確認を入力してください';
                }
                if (v != _signupPasswordController.text) {
                  return 'パスワードが一致しません';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _isLoading ? null : _signUp,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('新規登録'),
            ),
            if (_signupError != null) ...[
              const SizedBox(height: 12),
              Text(
                _signupError!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            const TermsConsentFooter(),
            const SizedBox(height: 16),
            const AuthAttributionNoticeBlock(showCreatedByHeader: false),
          ],
        ),
      ),
    );
  }

  Future<void> _afterAuthSuccess() async {
    if (!mounted) return;
    try {
      await context.read<AppShellController>().initialize();
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _signIn() async {
    if (!_loginFormKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await _auth.signInWithEmail(
        email: _loginEmailController.text.trim(),
        password: _loginPasswordController.text,
      );
      await _afterAuthSuccess();
    } catch (e) {
      if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signUp() async {
    if (!_signupFormKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _signupError = null;
    });
    try {
      final response = await _auth.signUpWithEmail(
        email: _signupEmailController.text.trim(),
        password: _signupPasswordController.text,
        displayName: _displayNameController.text.trim(),
      );
      if (!mounted) return;
      if (response.session != null) {
        await _afterAuthSuccess();
        return;
      }
      final sentTo = _signupEmailController.text.trim();
      if (!mounted) return;
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => _EmailSentPage(email: sentTo),
        ),
      );
    } on EmailAlreadyRegisteredException {
      if (mounted) {
        _showExistingAccountDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _signupError = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _loginEmailController.text.trim();
    if (email.isEmpty) {
      _showError('メールアドレスを入力してください');
      return;
    }
    try {
      await _auth.resetPassword(email);
      _showSuccess('パスワードリセット用のメールを送信しました');
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showExistingAccountDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('すでにアカウントがあります'),
        content: const Text(
          'このメールアドレスは登録済みです。「ログイン」から同じメールとパスワードで続けてください。',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('閉じる')),
        ],
      ),
    );
  }

  void _showError(String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('エラー'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  void _showSuccess(String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('送信しました'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }
}

class _EmailSentPage extends StatefulWidget {
  const _EmailSentPage({required this.email});

  final String email;

  @override
  State<_EmailSentPage> createState() => _EmailSentPageState();
}

class _EmailSentPageState extends State<_EmailSentPage> {
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn && mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (Supabase.instance.client.auth.currentSession != null) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('確認メールを送信しました')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${widget.email} 宛に確認メールを送りました。'),
            const SizedBox(height: 12),
            const Text(
              'メール内のリンクをタップすると Who eats に戻り、プロフィール設定へ進みます。\n'
              '同じ端末のメールアプリから開いてください。',
            ),
            const Spacer(),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('閉じる'),
            ),
          ],
        ),
      ),
    );
  }
}
