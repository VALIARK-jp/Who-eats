import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../auth_public_info.dart';

/// Created by・制作クレジット・共通アカウント案内・姉妹アプリリンク（Panda Talk 同型）。
class AuthAttributionNoticeBlock extends StatelessWidget {
  const AuthAttributionNoticeBlock({
    super.key,
    this.showCreatedByHeader = true,
  });

  /// `false` にすると「Created by」行だけ省略（メール画面など省スペース用）。
  final bool showCreatedByHeader;

  static const double _bodyFontSize = 12;
  static const double _affiliationFontSize = 14;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showCreatedByHeader) ...[
          Row(
            children: [
              Expanded(child: Container(height: 1, color: AppColors.border)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Created by',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSubtle,
                        fontSize: _bodyFontSize,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              Expanded(child: Container(height: 1, color: AppColors.border)),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Center(
          child: Text(
            authCreatedByAffiliationJa,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontSize: _affiliationFontSize,
                  height: 1.45,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          valiarkUnifiedAccountLeadJa.trim(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: _bodyFontSize,
                height: 1.5,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          valiarkAuthSupplementJa.trim(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: _bodyFontSize,
                height: 1.45,
                color: AppColors.textSubtle,
                fontWeight: FontWeight.w500,
              ),
        ),
        if (authSisterAppLinks.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 0,
            children: [
              Text(
                'その他のアプリ：',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: _bodyFontSize,
                      color: AppColors.textSubtle,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              for (var i = 0; i < authSisterAppLinks.length; i++) ...[
                if (i > 0)
                  Text(
                    '・',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: _bodyFontSize,
                          color: AppColors.textSubtle,
                        ),
                  ),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: AppColors.textPrimary,
                  ),
                  onPressed: () => _openLink(context, authSisterAppLinks[i].uri),
                  child: Text(
                    authSisterAppLinks[i].title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: _bodyFontSize,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.textPrimary.withValues(
                            alpha: 0.4,
                          ),
                        ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _openLink(BuildContext context, Uri uri) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('リンクを開けませんでした')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text('リンクを開けませんでした: $e')),
        );
      }
    }
  }
}
