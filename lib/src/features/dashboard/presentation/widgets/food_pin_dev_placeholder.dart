import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Flutter Web（`flutter run -d chrome`）向けの簡易マップピン。
///
/// 本番の 3D（WebView + Three.js）は iOS/Android のみ。[FoodPin3DViewer] から利用。
class FoodPinDevPlaceholder extends StatelessWidget {
  const FoodPinDevPlaceholder({
    super.key,
    this.width,
    this.height,
    this.isPostedPin = false,
    this.initialIconAsset,
    this.initialIconUrl,
  });

  final double? width;
  final double? height;
  final bool isPostedPin;
  final String? initialIconAsset;
  final String? initialIconUrl;

  @override
  Widget build(BuildContext context) {
    final pinColor =
        isPostedPin ? AppColors.orangeHighlight : AppColors.orange;

    Widget headIcon;
    final iconUrl = initialIconUrl?.trim();
    final iconAsset = initialIconAsset?.trim();
    if (iconUrl != null && iconUrl.isNotEmpty) {
      headIcon = Image.network(
        iconUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _defaultHeadIcon(),
      );
    } else if (iconAsset != null && iconAsset.isNotEmpty) {
      headIcon = Image.asset(
        iconAsset,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _defaultHeadIcon(),
      );
    } else {
      headIcon = _defaultHeadIcon();
    }

    return SizedBox(
      width: width,
      height: height ?? 300,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: pinColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isPostedPin ? Colors.white : Colors.white70,
                  width: isPostedPin ? 3 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: pinColor.withValues(alpha: 0.5),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipOval(child: headIcon),
            ),
            CustomPaint(
              size: const Size(24, 14),
              painter: _PinTailPainter(color: pinColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _defaultHeadIcon() {
    return Icon(
      isPostedPin ? Icons.star : Icons.restaurant,
      color: Colors.white,
      size: 26,
    );
  }
}

class _PinTailPainter extends CustomPainter {
  _PinTailPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.5, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PinTailPainter oldDelegate) =>
      oldDelegate.color != color;
}
