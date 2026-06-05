import 'package:flutter/material.dart';

import '../../domain/entities/app_entities.dart';
import '../../../../core/theme/app_theme.dart';

/// 投稿直下に常時表示するコメントプレビュー（2件以上は1件＋続きあり表示）。
class PostCommentPreview extends StatelessWidget {
  const PostCommentPreview({
    super.key,
    required this.comment,
    required this.totalCount,
    this.onMoreTap,
    this.onDelete,
    this.showMoreHint = true,
  });

  final PostComment comment;
  final int totalCount;
  final VoidCallback? onMoreTap;
  final VoidCallback? onDelete;
  final bool showMoreHint;

  int get _hiddenCount => (totalCount - 1).clamp(0, 1 << 30);

  bool get _isSingle => totalCount <= 1;

  @override
  Widget build(BuildContext context) {
    final showContinuation = showMoreHint && totalCount > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: RichText(
                maxLines: _isSingle ? null : 3,
                overflow: _isSingle ? TextOverflow.visible : TextOverflow.ellipsis,
                text: TextSpan(
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.35,
                  ),
                  children: [
                    TextSpan(
                      text: '${comment.userName} ',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    TextSpan(
                      text: comment.body,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 16),
                color: Colors.white54,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: onDelete,
              ),
          ],
        ),
        if (showContinuation) ...[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: onMoreTap,
            behavior: HitTestBehavior.opaque,
            child: Text(
              '他$_hiddenCount件のコメント',
              style: TextStyle(
                color: AppColors.textSubtle.withValues(alpha: 0.85),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
