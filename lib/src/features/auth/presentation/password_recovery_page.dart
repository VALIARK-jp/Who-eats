import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../application/auth_service.dart';

/// リセットメールのリンクから戻ったあと、新パスワードを設定する画面。
class PasswordRecoveryPage extends StatefulWidget {
  const PasswordRecoveryPage({super.key, this.onComplete});

  final VoidCallback? onComplete;

  @override
  State<PasswordRecoveryPage> createState() => _PasswordRecoveryPageState();
}

class _PasswordRecoveryPageState extends State<PasswordRecoveryPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _auth = AuthService();

  bool _isSaving = false;
  bool _showPassword = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await _auth.updatePassword(_passwordController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('パスワードを変更しました')),
      );
      widget.onComplete?.call();
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

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
      appBar: AppBar(title: const Text('新しいパスワード')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              '新しいパスワードを入力してください。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSubtle,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: '新しいパスワード',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                      ),
                    ),
                    obscureText: !_showPassword,
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'パスワードを入力してください';
                      }
                      if (v.length < 6) {
                        return 'パスワードは6文字以上で入力してください';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmController,
                    decoration: InputDecoration(
                      labelText: '新しいパスワード（確認）',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showConfirm
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () =>
                            setState(() => _showConfirm = !_showConfirm),
                      ),
                    ),
                    obscureText: !_showConfirm,
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'パスワード確認を入力してください';
                      }
                      if (v != _passwordController.text) {
                        return 'パスワードが一致しません';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('パスワードを保存'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
