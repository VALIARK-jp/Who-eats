import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import 'glass_panel.dart';

Future<String?> showReportReasonSheet(
  BuildContext context, {
  required String targetLabel,
}) {
  const reasons = <String>[
    'スパム・宣伝',
    '不適切な内容',
    '個人情報の共有',
    'その他',
  ];

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: GlassPanel(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            borderRadius: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$targetLabel を通報',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Text(
                  '通報理由を選んでください',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                for (final reason in reasons) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(reason),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: AppColors.orangeAccent.withValues(alpha: 0.45),
                        ),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          reason,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('キャンセル'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
