import 'package:flutter/material.dart';

import '../../domain/entities/app_entities.dart';
import '../../../../core/theme/app_theme.dart';
import 'friend_avatar_stack.dart';

/// Home (投稿) 用の投稿カード。
///
/// MVPでは rating / 投稿時間などが entity に無いので、UI用のプレースホルダで表現します。
class FoodPostCard extends StatelessWidget {
  const FoodPostCard({
    super.key,
    required this.post,
    this.onTap,
    this.currentUserId,
    this.onToggleFavorite,
    this.onTogglePin,
  });

  final FeedPost post;
  final VoidCallback? onTap;
  final String? currentUserId;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onTogglePin;

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
                onToggleFavorite: onToggleFavorite,
                onTogglePin: onTogglePin,
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
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.storefront_outlined, size: 16),
                  label: const Text('店舗詳細'),
                ),
              ),
              const SizedBox(height: 10),
              _ReactionRow(post: post),
              const SizedBox(height: 10),
              FriendAvatarStack(
                avatarDisplays: post.friendAvatars,
                maxVisible: 4,
                statusDot: false,
              ),
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
    this.onToggleFavorite,
    this.onTogglePin,
  });

  final FeedPost post;
  final String? currentUserId;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onTogglePin;

  @override
  Widget build(BuildContext context) {
    final uid = currentUserId ?? '';
    final isOwn = uid.isNotEmpty && post.userId == uid;
    final hasNetwork = post.userIconUrl != null &&
        post.userIconUrl!.isNotEmpty &&
        (post.userIconUrl!.startsWith('http://') ||
            post.userIconUrl!.startsWith('https://'));

    final initial = post.userName.isNotEmpty ? post.userName[0].toUpperCase() : '?';

    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.blackElevated,
          backgroundImage: hasNetwork ? NetworkImage(post.userIconUrl!) : null,
          child: hasNetwork ? null : Text(initial, style: const TextStyle(fontWeight: FontWeight.w800)),
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
              Text(
                '@${post.userName}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '24時間以内 · ${post.placeName}',
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
        IconButton(
          icon: const Icon(Icons.more_vert),
          color: Colors.white.withValues(alpha: 0.7),
          onPressed: () {},
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
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
    const rating = 4.5; // プレースホルダ

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          // Image
          Image.network(
            post.imageUrl,
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
          // Bottom gradient for readability
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
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, size: 16, color: AppColors.orangeAccent),
                    const SizedBox(width: 6),
                    Text(
                      rating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReactionRow extends StatelessWidget {
  const _ReactionRow({required this.post});

  final FeedPost post;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.favorite_border, size: 18, color: Colors.white.withValues(alpha: 0.85)),
        const SizedBox(width: 6),
        Text(
          '${post.likes}',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.white.withValues(alpha: 0.9),
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
