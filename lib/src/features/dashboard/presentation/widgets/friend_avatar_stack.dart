import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import 'friend_avatar.dart';

/// Overlapping avatar stack for "friends who went".
class FriendAvatarStack extends StatelessWidget {
  const FriendAvatarStack({
    super.key,
    required this.avatarDisplays,
    this.maxVisible = 4,
    this.avatarRadius = 18,
    this.showPlusBadge = true,
    this.statusDot = false,
  });

  /// For MVP this can be initials or URLs.
  final List<String> avatarDisplays;
  final int maxVisible;
  final double avatarRadius;
  final bool showPlusBadge;
  final bool statusDot;

  @override
  Widget build(BuildContext context) {
    final visible = avatarDisplays.take(maxVisible).toList(growable: false);
    final hiddenCount = (avatarDisplays.length - visible.length).clamp(0, 9999);

    const overlap = 12.0;
    final width = avatarRadius * 2 + (visible.length - 1).clamp(0, maxVisible - 1) * overlap + (hiddenCount > 0 ? 30 : 0);

    return SizedBox(
      height: avatarRadius * 2,
      width: width,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int i = 0; i < visible.length; i++)
            Positioned(
              left: i * overlap,
              child: FriendAvatar(
                radius: avatarRadius,
                displayName: visible[i],
                avatarUrl: _asUrl(visible[i]),
                showStatusDot: statusDot,
              ),
            ),
          if (showPlusBadge && hiddenCount > 0)
            Positioned(
              left: visible.length * overlap,
              child: Container(
                height: avatarRadius * 2,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppColors.blackElevated.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.border),
                ),
                child: Center(
                  child: Text(
                    '+$hiddenCount',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String? _asUrl(String v) {
    final s = v.trim();
    if (s.isEmpty) return null;
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    return null;
  }
}

