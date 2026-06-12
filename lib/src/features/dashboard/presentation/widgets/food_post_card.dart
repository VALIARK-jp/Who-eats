import 'package:flutter/material.dart';

import '../../domain/entities/app_entities.dart';
import '../../../../core/theme/app_theme.dart';
import 'friend_avatar_stack.dart';
import 'post_comment_preview.dart';
import 'friend_avatar.dart';

/// Home (投稿) 用の投稿カード。
class FoodPostCard extends StatelessWidget {
  const FoodPostCard({
    super.key,
    required this.post,
    this.onTap,
    this.currentUserId,
    this.onOpenProfile,
    this.onToggleFavorite,
    this.onTogglePin,
    this.onToggleLike,
    this.onOpenPlace,
  });

  final FeedPost post;
  final VoidCallback? onTap;
  final String? currentUserId;
  final ValueChanged<String>? onOpenProfile;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onTogglePin;
  final VoidCallback? onToggleLike;
  final VoidCallback? onOpenPlace;

  String _timeLabel() {
    final created = post.createdAt;
    if (created == null) return post.placeName;
    final diff = DateTime.now().difference(created.toLocal());
    if (diff.inMinutes < 60) return '${diff.inMinutes.clamp(1, 59)}分前';
    if (diff.inHours < 24) return '${diff.inHours}時間前';
    if (diff.inDays < 7) return '${diff.inDays}日前';
    return '${created.toLocal().month}/${created.toLocal().day}';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Card(
        color: AppColors.blackElevated.withValues(alpha: 0.86),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.border),
        ),
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TopRow(
                post: post,
                currentUserId: currentUserId,
                onOpenProfile: onOpenProfile,
                onToggleFavorite: onToggleFavorite,
                onTogglePin: onTogglePin,
                timeLabel: _timeLabel(),
              ),
              const SizedBox(height: 10),
              _PhotoBlock(post: post),
              const SizedBox(height: 10),
              Text(
                post.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              if (!post.isHomePost && (post.placeGoogleId ?? '').isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: onOpenPlace,
                    icon: const Icon(Icons.map_outlined, size: 16),
                    label: const Text('店舗詳細'),
                  ),
                ),
              const SizedBox(height: 10),
              _ReactionRow(post: post, onToggleLike: onToggleLike),
              if (post.latestComment != null) ...[
                const SizedBox(height: 10),
                PostCommentPreview(
                  comment: post.latestComment!,
                  totalCount: post.comments,
                  showMoreHint: post.comments > 1,
                  onMoreTap: post.comments > 1 ? onTap : null,
                ),
              ] else if (post.comments > 0) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: onTap,
                  child: Text(
                    'コメント${post.comments}件を見る',
                    style: TextStyle(
                      color: AppColors.textSubtle.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
              if (post.companionAvatars.isNotEmpty) ...[
                const SizedBox(height: 10),
                FriendAvatarStack(
                  avatarDisplays: post.companionAvatars,
                  maxVisible: 4,
                  statusDot: false,
                ),
              ] else if (post.friendAvatars.isNotEmpty) ...[
                const SizedBox(height: 10),
                FriendAvatarStack(
                  avatarDisplays: post.friendAvatars,
                  maxVisible: 4,
                  statusDot: false,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TopRow extends StatelessWidget {
  const _TopRow({
    required this.post,
    this.currentUserId,
    this.onOpenProfile,
    this.onToggleFavorite,
    this.onTogglePin,
    required this.timeLabel,
  });

  final FeedPost post;
  final String? currentUserId;
  final ValueChanged<String>? onOpenProfile;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onTogglePin;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    final uid = currentUserId ?? '';
    final isOwn = uid.isNotEmpty && post.userId == uid;

    return Row(
      children: [
        InkWell(
          onTap: onOpenProfile == null ? null : () => onOpenProfile!(post.userId),
          customBorder: const CircleBorder(),
          child: FriendAvatar(
            displayName: post.userName,
            avatarUrl: FriendAvatar.networkUrl(post.userIconUrl),
            radius: 18,
          ),
        ),
        const SizedBox(width: 10),
        if (isOwn && onTogglePin != null)
          IconButton(
            tooltip: post.isPinnedOnMyProfile ? 'ピン留めを外す' : 'プロフィールにピン留め',
            onPressed: onTogglePin,
            icon: Icon(
              post.isPinnedOnMyProfile ? Icons.push_pin : Icons.push_pin_outlined,
              size: 20,
              color: post.isPinnedOnMyProfile
                  ? AppColors.orangeAccent
                  : Colors.white70,
            ),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          )
        else if (!isOwn && onToggleFavorite != null)
          IconButton(
            tooltip: post.isFavoritedByMe ? 'お気に入りを外す' : 'お気に入り',
            onPressed: onToggleFavorite,
            icon: Icon(
              post.isFavoritedByMe ? Icons.bookmark : Icons.bookmark_border,
              size: 20,
              color: post.isFavoritedByMe
                  ? AppColors.orangeAccent
                  : Colors.white70,
            ),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '@${post.userName}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (isOwn) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.orange.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.orangeAccent.withValues(alpha: 0.45),
                        ),
                      ),
                      child: const Text(
                        'My Post',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: AppColors.orangeHighlight,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '$timeLabel · ${post.placeName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSubtle.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
        if (post.isHomePost)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.orangeAccent.withValues(alpha: 0.5)),
            ),
            child: const Text(
              '自炊',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.cardElevated,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.border),
            ),
            child: const Text(
              '外食',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }
}

class _PhotoBlock extends StatelessWidget {
  const _PhotoBlock({required this.post});

  final FeedPost post;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Image.network(
            post.imageUrl,
            cacheWidth: 1200,
            height: 260,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              height: 260,
              width: double.infinity,
              color: AppColors.cardElevated,
              alignment: Alignment.center,
              child: const Icon(Icons.fastfood_outlined),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.35),
                      Colors.black.withValues(alpha: 0.62),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.placeName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (post.rating != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 16, color: AppColors.orangeAccent),
                      const SizedBox(width: 6),
                      Text(
                        post.rating!.toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReactionRow extends StatelessWidget {
  const _ReactionRow({required this.post, this.onToggleLike});

  final FeedPost post;
  final VoidCallback? onToggleLike;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: onToggleLike,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Row(
              children: [
                Icon(
                  post.likedByMe ? Icons.favorite : Icons.favorite_border,
                  size: 18,
                  color: post.likedByMe
                      ? AppColors.orangeAccent
                      : Colors.white.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 6),
                Text(
                  '${post.likes}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 18),
        Icon(Icons.chat_bubble_outline, size: 18, color: Colors.white.withValues(alpha: 0.85)),
        const SizedBox(width: 6),
        Text(
          '${post.comments}',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }
}
