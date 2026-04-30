import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class SegmentedTabItem<T> {
  const SegmentedTabItem({
    required this.value,
    required this.label,
  });

  final T value;
  final String label;
}

/// A small wrapper around `SegmentedButton` tuned for the Who eats UI.
class SegmentedTab<T> extends StatelessWidget {
  const SegmentedTab({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
  });

  final List<SegmentedTabItem<T>> items;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SegmentedButton<T>(
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          backgroundColor: AppColors.blackElevated.withValues(alpha: 0.85),
          selectedBackgroundColor:
              AppColors.orangeAccent.withValues(alpha: 0.18),
          foregroundColor: AppColors.white,
          selectedForegroundColor: AppColors.orangeHighlight,
          side: BorderSide(color: AppColors.border2),
        ),
        segments: items
            .map(
              (i) => ButtonSegment(
                value: i.value,
                label: Text(i.label),
              ),
            )
            .toList(),
        selected: {selected},
        onSelectionChanged: (values) => onChanged(values.first),
      ),
    );
  }
}

