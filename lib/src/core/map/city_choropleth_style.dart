import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../theme/app_theme.dart';

/// 市ごとの投稿カバレッジ（優先度: mine > friend > other > none）。
enum CityPostCoverage {
  mine,
  friend,
  other,
  none;

  static CityPostCoverage fromFlags({
    required bool hasMine,
    required bool hasFriend,
    required bool hasOther,
  }) {
    if (hasMine) return CityPostCoverage.mine;
    if (hasFriend) return CityPostCoverage.friend;
    if (hasOther) return CityPostCoverage.other;
    return CityPostCoverage.none;
  }
}

class CityChoroplethStyle {
  const CityChoroplethStyle._();

  static const _baseOrange = Color(0xFFFF6B00);
  static const _strokeNone = Color(0xFF64748B);

  static PolygonStyle styleFor(CityPostCoverage coverage) {
    switch (coverage) {
      case CityPostCoverage.mine:
        return const PolygonStyle(
          fillColor: _baseOrange,
          fillOpacity: 0.65,
          strokeColor: _baseOrange,
          strokeWidth: 1.5,
        );
      case CityPostCoverage.friend:
        return const PolygonStyle(
          fillColor: _baseOrange,
          fillOpacity: 0.45,
          strokeColor: AppColors.orangeAccent,
          strokeWidth: 1.5,
        );
      case CityPostCoverage.other:
        return const PolygonStyle(
          fillColor: _baseOrange,
          fillOpacity: 0.22,
          strokeColor: AppColors.orangeHighlight,
          strokeWidth: 1.2,
        );
      case CityPostCoverage.none:
        return const PolygonStyle(
          fillColor: Colors.transparent,
          fillOpacity: 0,
          strokeColor: _strokeNone,
          strokeWidth: 1,
        );
    }
  }

  static String legendLabel(CityPostCoverage coverage) {
    switch (coverage) {
      case CityPostCoverage.mine:
        return '自分が投稿';
      case CityPostCoverage.friend:
        return '友達が投稿';
      case CityPostCoverage.other:
        return '他のユーザーが投稿';
      case CityPostCoverage.none:
        return '未投稿（枠線のみ）';
    }
  }
}

class PolygonStyle {
  const PolygonStyle({
    required this.fillColor,
    required this.fillOpacity,
    required this.strokeColor,
    required this.strokeWidth,
  });

  final Color fillColor;
  final double fillOpacity;
  final Color strokeColor;
  final double strokeWidth;

  Polygon toGooglePolygon({
    required String polygonId,
    required List<LatLng> points,
  }) {
    return Polygon(
      polygonId: PolygonId(polygonId),
      points: points,
      fillColor: fillColor.withValues(alpha: fillOpacity),
      strokeColor: strokeColor,
      strokeWidth: strokeWidth.round(),
      zIndex: 1,
      consumeTapEvents: true,
    );
  }
}
