import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// geolonia/japanese-admins 準拠の市区町村境界。
class MunicipalityFeature {
  const MunicipalityFeature({
    required this.cityCode,
    required this.name,
    required this.prefectureCode,
    required this.prefectureName,
    required this.rings,
  });

  final String cityCode;
  final String name;
  final String prefectureCode;
  final String prefectureName;

  /// 外環リング（lng, lat の配列）。Polygon / MultiPolygon の外環のみ。
  final List<List<List<double>>> rings;
}

class MunicipalityIndex {
  MunicipalityIndex(this.prefectures);

  final Map<String, _PrefectureIndex> prefectures;

  factory MunicipalityIndex.fromJson(Map<String, dynamic> json) {
    final raw = json['prefectures'] as Map<String, dynamic>? ?? {};
    final map = <String, _PrefectureIndex>{};
    for (final entry in raw.entries) {
      final pref = entry.value as Map<String, dynamic>;
      final municipalities = <_MunicipalityRef>[];
      for (final m in (pref['municipalities'] as List<dynamic>? ?? [])) {
        final row = m as Map<String, dynamic>;
        municipalities.add(
          _MunicipalityRef(
            cityCode: row['city_code'] as String,
            name: row['name'] as String,
          ),
        );
      }
      map[entry.key.padLeft(2, '0')] = _PrefectureIndex(
        prefectureName: pref['prefecture'] as String? ?? '',
        municipalities: municipalities,
      );
    }
    return MunicipalityIndex(map);
  }
}

class _PrefectureIndex {
  const _PrefectureIndex({
    required this.prefectureName,
    required this.municipalities,
  });

  final String prefectureName;
  final List<_MunicipalityRef> municipalities;
}

class _MunicipalityRef {
  const _MunicipalityRef({required this.cityCode, required this.name});

  final String cityCode;
  final String name;
}

class JapanMunicipalityGeoLoader {
  JapanMunicipalityGeoLoader({http.Client? client}) : _client = client ?? http.Client();

  static const _cdn = 'https://geolonia.github.io/japanese-admins';
  static const _indexAsset = 'assets/map/municipality-index.json';

  final http.Client _client;
  MunicipalityIndex? _indexCache;
  final Map<String, List<MunicipalityFeature>> _prefectureCache = {};

  Future<MunicipalityIndex> loadIndex() async {
    if (_indexCache != null) return _indexCache!;
    final raw = await rootBundle.loadString(_indexAsset);
    _indexCache = MunicipalityIndex.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
    return _indexCache!;
  }

  Future<List<MunicipalityFeature>> loadPrefectureFeatures(
    String prefectureCode,
  ) async {
    final code = prefectureCode.padLeft(2, '0');
    final cached = _prefectureCache[code];
    if (cached != null) return cached;

    final index = await loadIndex();
    final pref = index.prefectures[code];
    if (pref == null || pref.municipalities.isEmpty) {
      return const [];
    }

    final features = <MunicipalityFeature>[];
    const batchSize = 12;
    for (var i = 0; i < pref.municipalities.length; i += batchSize) {
      final chunk = pref.municipalities.skip(i).take(batchSize);
      final loaded = await Future.wait(
        chunk.map((m) => _fetchFeature(code, pref.prefectureName, m)),
      );
      features.addAll(loaded.whereType<MunicipalityFeature>());
    }

    _prefectureCache[code] = features;
    return features;
  }

  Future<MunicipalityFeature?> _fetchFeature(
    String prefectureCode,
    String prefectureName,
    _MunicipalityRef municipality,
  ) async {
    try {
      final res = await _client.get(
        Uri.parse('$_cdn/$prefectureCode/${municipality.cityCode}.json'),
      );
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body);
      final geometry = _readGeometry(json);
      if (geometry == null) return null;
      return MunicipalityFeature(
        cityCode: municipality.cityCode,
        name: municipality.name,
        prefectureCode: prefectureCode,
        prefectureName: prefectureName,
        rings: geometry,
      );
    } catch (_) {
      return null;
    }
  }

  List<List<List<double>>>? _readGeometry(Object? json) {
    Map<String, dynamic>? feature;
    if (json is Map<String, dynamic>) {
      if (json['type'] == 'FeatureCollection') {
        final features = json['features'] as List<dynamic>?;
        if (features != null && features.isNotEmpty) {
          feature = features.first as Map<String, dynamic>;
        }
      } else if (json['type'] == 'Feature') {
        feature = json;
      } else if (json['geometry'] is Map<String, dynamic>) {
        feature = {'geometry': json['geometry']};
      }
    }
    final geometry = feature?['geometry'] as Map<String, dynamic>?;
    if (geometry == null) return null;
    return _ringsFromGeometry(geometry);
  }

  List<List<List<double>>>? _ringsFromGeometry(Map<String, dynamic> geometry) {
    final type = geometry['type'] as String?;
    final coords = geometry['coordinates'];
    if (type == 'Polygon' && coords is List) {
      final ring = _ringFromRaw(coords.first);
      return ring == null ? null : [ring];
    }
    if (type == 'MultiPolygon' && coords is List) {
      final rings = <List<List<double>>>[];
      for (final poly in coords) {
        if (poly is! List || poly.isEmpty) continue;
        final ring = _ringFromRaw(poly.first);
        if (ring != null) rings.add(ring);
      }
      return rings.isEmpty ? null : rings;
    }
    return null;
  }

  List<List<double>>? _ringFromRaw(Object? raw) {
    if (raw is! List || raw.length < 3) return null;
    final ring = <List<double>>[];
    for (final point in raw) {
      if (point is! List || point.length < 2) continue;
      final lng = (point[0] as num).toDouble();
      final lat = (point[1] as num).toDouble();
      ring.add([lng, lat]);
    }
    return ring.length < 3 ? null : ring;
  }
}

/// Ray casting（外環のみ）。
bool pointInRings(double lat, double lng, List<List<List<double>>> rings) {
  for (final ring in rings) {
    if (_pointInRing(lat, lng, ring)) return true;
  }
  return false;
}

bool _pointInRing(double lat, double lng, List<List<double>> ring) {
  var inside = false;
  for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    final xi = ring[i][0];
    final yi = ring[i][1];
    final xj = ring[j][0];
    final yj = ring[j][1];
    final intersects = ((yi > lat) != (yj > lat)) &&
        (lng < (xj - xi) * (lat - yi) / (yj - yi + 0.0) + xi);
    if (intersects) inside = !inside;
  }
  return inside;
}

List<List<({double lat, double lng})>> ringsToLatLngPaths(
  List<List<List<double>>> rings,
) {
  return rings
      .map(
        (ring) => ring
            .map((p) => (lat: p[1], lng: p[0]))
            .toList(growable: false),
      )
      .toList(growable: false);
}
