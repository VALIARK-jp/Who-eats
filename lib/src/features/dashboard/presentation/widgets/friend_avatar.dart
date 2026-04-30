import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// A small circular avatar with an optional orange status dot.
class FriendAvatar extends StatelessWidget {
  const FriendAvatar({
    super.key,
    required this.displayName,
    this.avatarUrl,
    this.showStatusDot = false,
    this.radius = 22,
  });

  final String displayName;
  final String? avatarUrl;
  final bool showStatusDot;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    final bool hasNetwork = avatarUrl != null &&
        avatarUrl!.isNotEmpty &&
        (avatarUrl!.startsWith('http://') || avatarUrl!.startsWith('https://'));

    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: radius,
            backgroundColor: AppColors.blackElevated,
            backgroundImage: hasNetwork ? NetworkImage(avatarUrl!) : null,
            child: hasNetwork ? null : Text(initial, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          if (showStatusDot)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.orange,
                  border: Border.all(color: AppColors.black, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

