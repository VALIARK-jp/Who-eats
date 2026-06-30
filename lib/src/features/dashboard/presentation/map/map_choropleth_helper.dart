import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/map/city_choropleth_style.dart';
import '../../../../core/map/japan_municipality_geo.dart';
import '../../domain/entities/app_entities.dart';

class MapChoroplethHelper {
  MapChoroplethHelper({JapanMunicipalityGeoLoader? geoLoader})
    : _geoLoader = geoLoader ?? JapanMunicipalityGeoLoader();

  final JapanMunicipalityGeoLoader _geoLoader;

  String? _loadedPrefectureCodesKey;
  List<MunicipalityFeature> _features = const [];
  Map<String, CityChoroplethMetric> _metricsByCity = const {};
  bool _loading = false;
  int _requestSeq = 0;

  bool get isLoading => _loading;

  Future<void> refresh({
    required List<String> prefectureCodes,
    required Future<Map<String, CityChoroplethMetric>> Function(
      List<String> prefectureCodes,
    )
    loadMetrics,
  }) async {
    if (prefectureCodes.isEmpty) {
      clear();
      return;
    }

    final sortedCodes = [...prefectureCodes]..sort();
    final codesKey = sortedCodes.join(',');

    final seq = ++_requestSeq;
    _loading = true;
    try {
      if (_loadedPrefectureCodesKey != codesKey || _features.isEmpty) {
        final loaded = await Future.wait(
          sortedCodes.map(_geoLoader.loadPrefectureFeatures),
        );
        if (seq != _requestSeq) return;
        _features = [
          for (final features in loaded) ...features,
        ];
        _loadedPrefectureCodesKey = codesKey;
      }

      final metrics = await loadMetrics(sortedCodes);
      if (seq != _requestSeq) return;
      _metricsByCity = metrics;
      if (kDebugMode) {
        debugPrint(
          '[MapChoroplethHelper] prefs=${sortedCodes.length} '
          'features=${_features.length} metrics=${_metricsByCity.length}',
        );
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[MapChoroplethHelper] refresh failed: $e\n$st');
      }
      if (seq == _requestSeq) {
        _loadedPrefectureCodesKey = null;
        _features = const [];
        _metricsByCity = const {};
      }
    } finally {
      if (seq == _requestSeq) {
        _loading = false;
      }
    }
  }

  void clear() {
    _requestSeq++;
    _loading = false;
    _loadedPrefectureCodesKey = null;
    _features = const [];
    _metricsByCity = const {};
  }

  Set<Polygon> buildPolygons() {
    if (_features.isEmpty) return const {};

    final polygons = <Polygon>{};
    var painted = 0;
    for (final feature in _features) {
      final metric = _metricForCity(feature.cityCode);
      final coverage = metric == null
          ? CityPostCoverage.none
          : CityPostCoverage.fromFlags(
              hasMine: metric.hasMine,
              hasFriend: metric.hasFriend,
              hasOther: metric.hasOther,
            );
      if (coverage != CityPostCoverage.none) painted++;
      final style = CityChoroplethStyle.styleFor(coverage);
      final paths = ringsToLatLngPaths(feature.rings);
      for (var i = 0; i < paths.length; i++) {
        final points = paths[i].map((p) => LatLng(p.lat, p.lng)).toList();
        polygons.add(
          style.toGooglePolygon(
            polygonId: '${feature.cityCode}_$i',
            points: points,
          ),
        );
      }
    }
    if (kDebugMode) {
      debugPrint(
        '[MapChoroplethHelper] polygons=${polygons.length} painted=$painted',
      );
    }
    return polygons;
  }

  /// DB メトリクスに加え、画面上の投稿ピン位置から市カバレッジを補完する。
  void mergeMetricsFromMapPins(List<MapPin> pins) {
    if (_features.isEmpty || pins.isEmpty) return;

    for (final pin in pins) {
      if (!pin.hasPostedActivity) continue;
      final lat = pin.latitude;
      final lng = pin.longitude;
      if (lat == null || lng == null) continue;

      final feature = _featureForPoint(lat, lng);
      if (feature == null) continue;

      var hasMine = false;
      var hasFriend = false;
      var hasOther = false;
      for (final visitor in pin.visitors) {
        if (visitor.isMe) {
          hasMine = true;
        } else if (visitor.isFriend) {
          hasFriend = true;
        } else {
          hasOther = true;
        }
      }
      if (!hasMine && !hasFriend && !hasOther) {
        hasOther = true;
      }

      final existing = _metricForCity(feature.cityCode);
      _metricsByCity[feature.cityCode] = CityChoroplethMetric(
        cityCode: feature.cityCode,
        cityName: existing?.cityName ?? feature.name,
        hasMine: existing?.hasMine == true || hasMine,
        hasFriend: existing?.hasFriend == true || hasFriend,
        hasOther: existing?.hasOther == true || hasOther,
      );
    }
  }

  CityChoroplethMetric? _metricForCity(String cityCode) {
    return _metricsByCity[cityCode] ??
        _metricsByCity[cityCode.padLeft(5, '0')];
  }

  MunicipalityFeature? _featureForPoint(double lat, double lng) {
    for (final feature in _features) {
      if (pointInRings(lat, lng, feature.rings)) return feature;
    }
    return null;
  }
}
