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

  static String? networkUrl(String? raw) {
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return null;
  }

  /// [token] は表示名の頭文字、または signed URL。
  static ({String displayName, String? avatarUrl}) fromToken(String token) {
    final url = networkUrl(token);
    if (url != null) {
      return (displayName: '?', avatarUrl: url);
    }
    final trimmed = token.trim();
    return (
      displayName: trimmed.isNotEmpty ? trimmed : '?',
      avatarUrl: null,
    );
  }

  static ({String displayName, String? avatarUrl}) fromUser({
    required String name,
    String? avatarUrl,
  }) {
    final url = networkUrl(avatarUrl);
    final trimmedName = name.trim();
    final initial = trimmedName.isNotEmpty
        ? trimmedName.characters.first.toUpperCase()
        : '?';
    return (displayName: initial, avatarUrl: url);
  }

  @override
  Widget build(BuildContext context) {
    final resolved = fromUser(name: displayName, avatarUrl: avatarUrl);
    final initial = resolved.displayName;
    final network = resolved.avatarUrl;

    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: radius,
            backgroundColor: AppColors.blackElevated,
            backgroundImage: network != null ? NetworkImage(network) : null,
            child: network != null
                ? null
                : Text(initial, style: const TextStyle(fontWeight: FontWeight.w800)),
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

