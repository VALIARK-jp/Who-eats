import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';

/// 利用規約・プライバシーポリシーへの同意（Panda Talk 同型）。
class TermsConsentFooter extends StatelessWidget {
  const TermsConsentFooter({super.key});

  static const double _bodyFontSize = 12;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Who eats は VALIARK合同会社（以下「当社」）が提供するサービスです。'
          '本サービスをご利用になるには、当社が定める利用規約およびプライバシーポリシーに同意いただく必要があります。'
          'ログインまたは新規登録を完了した時点で、当該規約・ポリシーの内容を理解し、これに同意したものとみなします。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: _bodyFontSize,
                height: 1.45,
                color: AppColors.textSubtle,
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 0,
          children: [
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: AppColors.textPrimary,
              ),
              onPressed: () => _openUrl(
                context,
                AppConfig.termsOfServiceUrl,
                '利用規約',
              ),
              child: Text(
                '利用規約を読む',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.textPrimary.withValues(
                        alpha: 0.35,
                      ),
                    ),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: AppColors.textPrimary,
              ),
              onPressed: () => _openUrl(
                context,
                AppConfig.privacyPolicyUrl,
                'プライバシーポリシー',
              ),
              child: Text(
                'プライバシーポリシーを読む',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.textPrimary.withValues(
                        alpha: 0.35,
                      ),
                    ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _openUrl(BuildContext context, String url, String label) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('$label の掲載準備中です。')),
      );
      return;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) {
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('リンク URL が未設定または不正です。')),
      );
      return;
    }
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('ブラウザを開けませんでした')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text('ブラウザを開けませんでした: $e')),
        );
      }
    }
  }
}
