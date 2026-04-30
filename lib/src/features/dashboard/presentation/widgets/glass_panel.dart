import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// A lightweight glass-like panel used across the UI.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 20,
    this.alpha = 0.9,
    this.border = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final double alpha;
  final bool border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.cardElevated.withValues(alpha: alpha),
        borderRadius: BorderRadius.circular(borderRadius),
        border: border ? Border.all(color: AppColors.border) : null,
      ),
      child: child,
    );
  }
}

