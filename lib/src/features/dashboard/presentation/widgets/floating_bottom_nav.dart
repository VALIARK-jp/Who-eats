import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Floating bottom navigation with a center camera CTA.
class FloatingBottomNav extends StatelessWidget {
  const FloatingBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.onCameraPressed,
  });

  /// 0: Home, 1: Friends, 2: Camera (CTA only), 3: Record, 4: Profile
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onCameraPressed;

  @override
  Widget build(BuildContext context) {
    // Keep tap targets large and leave side padding like the spec reference.
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: SizedBox(
          height: 62,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: 62,
                    decoration: BoxDecoration(
                      color: AppColors.black.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: AppColors.border),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _NavItem(
                          icon: Icons.home_outlined,
                          label: 'ホーム',
                          selected: selectedIndex == 0,
                          onTap: () => onTabSelected(0),
                        ),
                        _NavItem(
                          icon: Icons.people_alt_outlined,
                          label: '友達',
                          selected: selectedIndex == 1,
                          onTap: () => onTabSelected(1),
                        ),
                        const SizedBox(width: 58), // center CTA slot
                        _NavItem(
                          icon: Icons.calendar_month_outlined,
                          label: '記録',
                          selected: selectedIndex == 3,
                          onTap: () => onTabSelected(3),
                        ),
                        _NavItem(
                          icon: Icons.person_outline,
                          label: 'プロフィール',
                          selected: selectedIndex == 4,
                          onTap: () => onTabSelected(4),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: -14,
                child: Center(
                  child: _CameraCta(
                    onPressed: onCameraPressed,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.orange : AppColors.white.withValues(alpha: 0.7);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: SizedBox(
        width: 62,
        height: 62,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 25, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraCta extends StatelessWidget {
  const _CameraCta({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 58,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.orange,
              boxShadow: [
                BoxShadow(
                  color: AppColors.orange.withValues(alpha: 0.48),
                  blurRadius: 34,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(Icons.add, color: Colors.black, size: 30),
          ),
        ),
      ),
    );
  }
}

