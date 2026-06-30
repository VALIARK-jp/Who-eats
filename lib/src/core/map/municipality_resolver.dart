import 'dart:math' as math;

import 'japan_municipality_geo.dart';
import 'prefecture_bounds.dart';

class ResolvedMunicipality {
  const ResolvedMunicipality({
    required this.prefectureCode,
    required this.prefectureName,
    required this.cityCode,
    required this.cityName,
  });

  final String prefectureCode;
  final String prefectureName;
  final String cityCode;
  final String cityName;
}

/// lat/lng から市区町村コードを解決（geolonia 境界 + point-in-polygon）。
class MunicipalityResolver {
  MunicipalityResolver({JapanMunicipalityGeoLoader? loader})
    : _loader = loader ?? JapanMunicipalityGeoLoader();

  final JapanMunicipalityGeoLoader _loader;

  Future<ResolvedMunicipality?> resolve({
    required double latitude,
    required double longitude,
    String? prefectureCodeHint,
  }) async {
    final candidates = prefectureCodeHint != null
        ? [prefectureCodeHint.padLeft(2, '0')]
        : PrefectureBounds.prefectureCodesFor(latitude, longitude);
    if (candidates.isEmpty) return null;

    for (final prefCode in candidates) {
      final features = await _loader.loadPrefectureFeatures(prefCode);
      for (final feature in features) {
        if (pointInRings(latitude, longitude, feature.rings)) {
          return ResolvedMunicipality(
            prefectureCode: feature.prefectureCode,
            prefectureName: feature.prefectureName,
            cityCode: feature.cityCode,
            cityName: _displayCityName(feature.name),
          );
        }
      }

      final nearest = _nearestFeature(latitude, longitude, features);
      if (nearest != null) {
        return ResolvedMunicipality(
          prefectureCode: nearest.prefectureCode,
          prefectureName: nearest.prefectureName,
          cityCode: nearest.cityCode,
          cityName: _displayCityName(nearest.name),
        );
      }
    }
    return null;
  }

  MunicipalityFeature? _nearestFeature(
    double latitude,
    double longitude,
    List<MunicipalityFeature> features, {
    double maxDistanceMeters = 2500,
  }) {
    MunicipalityFeature? best;
    var bestDistance = double.infinity;
    for (final feature in features) {
      for (final ring in feature.rings) {
        if (ring.isEmpty) continue;
        var lat = 0.0;
        var lng = 0.0;
        for (final point in ring) {
          lng += point[0];
          lat += point[1];
        }
        lat /= ring.length;
        lng /= ring.length;
        final distance = _distanceMeters(latitude, longitude, lat, lng);
        if (distance < bestDistance) {
          bestDistance = distance;
          best = feature;
        }
      }
    }
    if (best == null || bestDistance > maxDistanceMeters) return null;
    return best;
  }

  double _distanceMeters(double lat1, double lng1, double lat2, double lng2) {
    final dx = (lat1 - lat2) * 111000;
    final dy = (lng1 - lng2) * 91000;
    return math.sqrt(dx * dx + dy * dy);
  }

  String _displayCityName(String raw) {
    // インデックスは「東京都渋谷区」形式のことがある。
    final parts = raw.split('県');
    if (parts.length > 1) return parts.last;
    final prefParts = raw.split('府');
    if (prefParts.length > 1) return prefParts.last;
    final tokyoParts = raw.split('都');
    if (tokyoParts.length > 1) return tokyoParts.last;
    final hokkaidoParts = raw.split('道');
    if (hokkaidoParts.length > 1) return hokkaidoParts.last;
    return raw;
  }
}
