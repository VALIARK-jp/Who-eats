import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class ProfileFoodGrid extends StatelessWidget {
  const ProfileFoodGrid({
    super.key,
    required this.urls,
    this.crossAxisCount = 3,
  });

  final List<String> urls;
  final int crossAxisCount;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: urls.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (_, i) => ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: urls.isEmpty || urls[i].isEmpty
            ? Container(
                color: AppColors.cardElevated,
                alignment: Alignment.center,
                child: const Icon(Icons.photo_outlined),
              )
            : Image.network(
                urls[i],
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: AppColors.cardElevated,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
      ),
    );
  }
}

