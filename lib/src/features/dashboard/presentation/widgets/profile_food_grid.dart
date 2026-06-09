import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/app_entities.dart';

class ProfileFoodGrid extends StatelessWidget {
  const ProfileFoodGrid({
    super.key,
    this.urls,
    this.thumbs,
    this.onThumbTap,
    this.crossAxisCount = 3,
  }) : assert(
         urls != null || thumbs != null,
         'Provide urls or thumbs',
       );

  final List<String>? urls;
  final List<ProfilePostThumb>? thumbs;
  final ValueChanged<ProfilePostThumb>? onThumbTap;
  final int crossAxisCount;

  List<ProfilePostThumb> get _items {
    if (thumbs != null) return thumbs!;
    return (urls ?? [])
        .asMap()
        .entries
        .map(
          (e) => ProfilePostThumb(
            postId: 'url-${e.key}',
            imageUrl: e.value,
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'まだありません',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (_, i) {
        final thumb = items[i];
        final image = thumb.imageUrl.isEmpty
            ? Container(
                color: AppColors.cardElevated,
                alignment: Alignment.center,
                child: const Icon(Icons.photo_outlined),
              )
            : Image.network(
                thumb.imageUrl,
                cacheWidth: 420,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: AppColors.cardElevated,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              );

        final cell = ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: image,
        );

        if (onThumbTap == null) return cell;
        return InkWell(
          onTap: () => onThumbTap!(thumb),
          borderRadius: BorderRadius.circular(14),
          child: cell,
        );
      },
    );
  }
}
