import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../dashboard/presentation/controllers/app_shell_controller.dart';

String _userFacingAuthErrorMessage(Object error) {
  final s = error.toString();
  if (s.contains('Failed host lookup') ||
      s.contains('SocketException') ||
      s.contains('nodename nor servname') ||
      s.contains('Connection refused') ||
      s.contains('Network is unreachable')) {
    final host = AppConfig.supabaseUrl;
    return 'サーバーに届きませんでした。端末のネットワークを確認し、'
        'プロジェクトの .env にある WHOEATS_SUPABASE_URL（または SUPABASE_URL）が '
        'Supabase ダッシュボードの URL と一致しているか確認してください。'
        '${host.isNotEmpty ? '\n（現在: $host）' : ''}';
  }
  return '通信に失敗しました。しばらくしてからもう一度お試しください。';
}

/// メール＋パスワードのフォーム（親が [Scaffold] / [ScaffoldMessenger] を用意すること）。
class EmailAuthForm extends StatefulWidget {
  const EmailAuthForm({super.key});

  @override
  State<EmailAuthForm> createState() => _EmailAuthFormState();
}

class _EmailAuthFormState extends State<EmailAuthForm> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _afterAuthSuccess() async {
    if (!mounted) return;
    try {
      final shell = context.read<AppShellController>();
      await shell.initialize();
    } catch (_) {}
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _showMessage('メールアドレスとパスワードを入力してください');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      await _afterAuthSuccess();
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (e) {
      _showMessage(_userFacingAuthErrorMessage(e));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _showMessage('メールアドレスとパスワードを入力してください');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: AppConfig.valiarkAuthRedirectUrl,
      );
      _showMessage('登録しました。確認メールが必要な場合は受信箱を確認してください。');
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (e) {
      _showMessage(_userFacingAuthErrorMessage(e));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'メールアドレス'),
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(labelText: 'パスワード'),
            obscureText: true,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _isLoading ? null : _signIn,
                  child: const Text('ログイン'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading ? null : _signUp,
                  child: const Text('新規登録'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 単体のメールログイン画面（デバッグ用・シンプル構成）。
class EmailAuthPage extends StatelessWidget {
  const EmailAuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Who eats ログイン')),
      body: const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: EmailAuthForm(),
        ),
      ),
    );
  }
}
