import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../application/auth_session.dart';
import 'email_auth_page.dart';

/// Panda SSO 導線つきのログイン入口（メールログインは下段）。
class SignInPage extends StatelessWidget {
  const SignInPage({super.key});

  Future<void> _openPandaOAuth(BuildContext context) async {
    final raw = AppConfig.pandaOAuthUrl;
    if (raw.isEmpty) return;
    final uri = Uri.tryParse(raw);
    if (uri == null) {
      _toast(context, 'WHOEATS_PANDA_OAUTH_URL の形式が不正です');
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      _toast(context, 'ブラウザを開けませんでした');
    }
  }

  void _toast(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final pandaUrl = AppConfig.pandaOAuthUrl;
    return Scaffold(
      appBar: AppBar(title: const Text('Who eats')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Text(
              'ログイン',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              'Panda 側と OAuth を揃えた場合は、まずブラウザで Panda から認証し、このアプリに戻ってください。'
              'トークンが古いままだとホームだけ開いて失敗することがあります。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: 20),
            if (pandaUrl.isNotEmpty)
              FilledButton.tonal(
                onPressed: () => _openPandaOAuth(context),
                child: const Text('Panda（ブラウザ）でログイン'),
              )
            else
              Text(
                'Panda 連携: `.env` に WHOEATS_PANDA_OAUTH_URL を入れると上にボタンが出ます。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white54,
                    ),
              ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                await clearLocalAuthSession();
                if (context.mounted) {
                  _toast(context, '端末に保存したセッションを消しました。下から再ログインしてください。');
                }
              },
              child: const Text('保存セッションをクリア（オフライン可）'),
            ),
            const SizedBox(height: 28),
            Text(
              'メールでログイン',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            const EmailAuthForm(),
          ],
        ),
      ),
    );
  }
}
