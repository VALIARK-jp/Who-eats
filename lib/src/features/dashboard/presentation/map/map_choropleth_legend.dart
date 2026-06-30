import 'package:flutter/material.dart';

import '../../../../core/map/city_choropleth_style.dart';
import '../../../../core/theme/app_theme.dart';

class MapChoroplethLegend extends StatelessWidget {
  const MapChoroplethLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.blackElevated.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '投稿エリア',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          for (final coverage in CityPostCoverage.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _LegendRow(coverage: coverage),
            ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.coverage});

  final CityPostCoverage coverage;

  @override
  Widget build(BuildContext context) {
    final style = CityChoroplethStyle.styleFor(coverage);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: style.fillOpacity > 0
                ? style.fillColor.withValues(alpha: style.fillOpacity)
                : Colors.transparent,
            border: Border.all(color: style.strokeColor, width: 1.2),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          CityChoroplethStyle.legendLabel(coverage),
          style: TextStyle(
            fontSize: 10,
            color: Colors.white.withValues(alpha: 0.82),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
