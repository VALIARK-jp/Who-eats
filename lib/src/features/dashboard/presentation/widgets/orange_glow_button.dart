import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Orange neon/glow pill button.
class OrangeGlowButton extends StatelessWidget {
  const OrangeGlowButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.isEnabled = true,
    this.borderRadius = 999,
    this.width,
    this.height,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final bool isEnabled;
  final double borderRadius;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isEnabled ? onPressed : null;
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: effectiveOnPressed,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.orange,
              borderRadius: BorderRadius.circular(borderRadius),
              boxShadow: isEnabled
                  ? [
                      BoxShadow(
                        color: AppColors.orangeAccent.withValues(alpha: 0.35),
                        blurRadius: 22,
                        spreadRadius: 1,
                      ),
                    ]
                  : [],
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: child,
          ),
        ),
      ),
    );
  }
}

