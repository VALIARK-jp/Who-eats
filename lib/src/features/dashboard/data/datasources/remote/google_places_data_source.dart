import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../models/map_pin_model.dart';
import '../../models/place_detail_model.dart';
import '../../../domain/entities/app_entities.dart';

class GooglePlacesDataSource {
  GooglePlacesDataSource({
    required String apiKey,
    http.Client? client,
  })  : _apiKey = apiKey,
        _client = client ?? http.Client();

  final String _apiKey;
  final http.Client _client;

  static const _defaultLat = 35.6595;
  static const _defaultLng = 139.7005;

  Future<List<MapPinModel>> searchNearbyPlaces({required String keyword}) async {
    return searchNearbyPlacesAround(
      lat: _defaultLat,
      lng: _defaultLng,
      radiusMeters: 2500,
      keyword: keyword,
    );
  }

  Future<List<MapPinModel>> searchNearbyPlacesAround({
    required double lat,
    required double lng,
    required int radiusMeters,
    String? keyword,
  }) async {
    _log(
      'NearbyAround start lat=$lat lng=$lng radius=$radiusMeters keyword="${keyword ?? ''}"',
    );
    final collected = <MapPinModel>[];
    final seen = <String>{};
    String? nextPageToken;

    for (var page = 0; page < 3; page++) {
      final query = <String, String>{
        'location': '$lat,$lng',
        'radius': '$radiusMeters',
        'type': 'restaurant',
        'key': _apiKey,
        'language': 'ja',
      };
      if (keyword != null && keyword.trim().isNotEmpty) {
        query['keyword'] = keyword.trim();
      }
      if (nextPageToken != null) {
        query['pagetoken'] = nextPageToken;
      }
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/nearbysearch/json',
        query,
      );
      final response = await _client.get(uri).timeout(const Duration(seconds: 10));
      _log('NearbyAround page=$page http=${response.statusCode}');
      final decoded = _decodeMap(response);
      final status = (decoded['status'] ?? '').toString();
      _log('NearbyAround page=$page status=$status');
      if (status == 'ZERO_RESULTS') break;
      if (status == 'INVALID_REQUEST' && nextPageToken != null) {
        // next_page_token requires a short wait before becoming valid.
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        continue;
      }
      if (status != 'OK') {
        throw Exception('Google Nearby Search status: $status');
      }
      final items = (decoded['results'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>();
      for (final item in items) {
        final model = _mapNearbyToPinModel(item);
        if (model.id.isEmpty || seen.contains(model.id)) continue;
        seen.add(model.id);
        collected.add(model);
      }
      nextPageToken = (decoded['next_page_token'] ?? '').toString();
      if (nextPageToken.isEmpty) break;
      await Future<void>.delayed(const Duration(milliseconds: 1200));
    }
    _log('NearbyAround results=${collected.length}');
    return collected;
  }

  Future<MapPinModel?> resolveNearestRestaurantPin({
    required double lat,
    required double lng,
  }) async {
    _log('ResolveFromCoord start lat=$lat lng=$lng');
    final uri = Uri.https('maps.googleapis.com', '/maps/api/place/nearbysearch/json', {
      'location': '$lat,$lng',
      'rankby': 'distance',
      'type': 'restaurant',
      'key': _apiKey,
      'language': 'ja',
    });
    final response = await _client.get(uri).timeout(const Duration(seconds: 10));
    _log('ResolveFromCoord http=${response.statusCode}');
    final decoded = _decodeMap(response);
    final status = (decoded['status'] ?? '').toString();
    _log('ResolveFromCoord status=$status');
    if (status == 'ZERO_RESULTS') return null;
    if (status != 'OK') return null;
    final items = (decoded['results'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    if (items.isEmpty) return null;
    _log('ResolveFromCoord resolved placeId=${items.first['place_id']}');
    return _mapNearbyToPinModel(items.first);
  }

  Future<PlaceDetailModel> getPlaceDetail(String placeId) async {
    _log('PlaceDetails start placeId=$placeId');
    final uri = Uri.https('maps.googleapis.com', '/maps/api/place/details/json', {
      'place_id': placeId,
      'fields':
          'place_id,name,formatted_address,formatted_phone_number,opening_hours,rating,reviews,photos,geometry,website,url',
      'key': _apiKey,
      'language': 'ja',
    });
    final response = await _client.get(uri).timeout(const Duration(seconds: 10));
    _log('PlaceDetails http=${response.statusCode}');
    final decoded = _decodeMap(response);
    final status = (decoded['status'] ?? '').toString();
    _log('PlaceDetails status=$status');
    if (status != 'OK') {
      throw Exception('Google Place Details status: $status');
    }
    final result = decoded['result'] as Map<String, dynamic>? ?? {};
    final photos = (result['photos'] as List<dynamic>? ?? []);
    final firstPhoto = photos.isNotEmpty ? photos.first : null;
    final photoReference =
        (firstPhoto is Map ? firstPhoto['photo_reference'] : null)?.toString();
    final photoUrl = photoReference == null
        ? ''
        : buildPhotoUrl(photoReference: photoReference, maxWidth: 1080);

    final lat = (result['geometry']?['location']?['lat'] as num?)?.toDouble();
    final lng = (result['geometry']?['location']?['lng'] as num?)?.toDouble();
    int? travelMinutes;
    if (lat != null && lng != null) {
      travelMinutes = await _getTravelMinutes(destinationLat: lat, destinationLng: lng);
    }

    final reviews = (result['reviews'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .take(5)
        .toList();
    return PlaceDetailModel(
      placeId: (result['place_id'] ?? placeId).toString(),
      placeName: (result['name'] ?? '').toString(),
      rating: (result['rating'] as num?)?.toDouble() ?? 0,
      friendComment: reviews.isEmpty
          ? 'Googleレビューはまだありません'
          : (reviews.first['text'] ?? '').toString(),
      imageUrl: photoUrl,
      posts: reviews
          .asMap()
          .entries
          .map(
            (entry) => PlacePostPreviewModel(
              id: 'rv_${entry.key}',
              userName: (entry.value['author_name'] ?? 'user').toString(),
              comment: (entry.value['text'] ?? '').toString(),
              imageUrl: photoUrl.isEmpty ? null : photoUrl,
            ),
          )
          .toList(),
      address: (result['formatted_address'] ?? '').toString(),
      phoneNumber: (result['formatted_phone_number'] ?? '').toString(),
      openNow: result['opening_hours']?['open_now'] as bool?,
      travelMinutes: travelMinutes,
      latitude: lat,
      longitude: lng,
      websiteUrl: (result['website'] ?? '').toString(),
      googleMapsUrl: (result['url'] ?? '').toString(),
    );
  }

  Future<List<PlaceSuggestion>> autocomplete(
    String query, {
    double? originLat,
    double? originLng,
  }) async {
    _log('Autocomplete start query="$query"');
    if (query.trim().isEmpty) return const [];
    final lat = originLat ?? _defaultLat;
    final lng = originLng ?? _defaultLng;
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      {
        'input': query,
        'types': 'establishment',
        'location': '$lat,$lng',
        'radius': '25000',
        'key': _apiKey,
        'language': 'ja',
      },
    );
    final response = await _client.get(uri).timeout(const Duration(seconds: 10));
    _log('Autocomplete http=${response.statusCode}');
    final decoded = _decodeMap(response);
    final status = (decoded['status'] ?? '').toString();
    _log('Autocomplete status=$status');
    if (status == 'ZERO_RESULTS') return const [];
    if (status != 'OK') return const [];
    final items = (decoded['predictions'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>();
    _log('Autocomplete results=${items.length}');
    return items
        .map(
          (e) => PlaceSuggestion(
            placeId: (e['place_id'] ?? '').toString(),
            description: (e['description'] ?? '').toString(),
          ),
        )
        .toList();
  }

  String buildPhotoUrl({
    required String photoReference,
    int maxWidth = 960,
  }) {
    return Uri.https('maps.googleapis.com', '/maps/api/place/photo', {
      'maxwidth': '$maxWidth',
      'photo_reference': photoReference,
      'key': _apiKey,
    }).toString();
  }

  Future<int?> _getTravelMinutes({
    required double destinationLat,
    required double destinationLng,
  }) async {
    _log('Directions start to=($destinationLat,$destinationLng)');
    final uri = Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
      'origin': '$_defaultLat,$_defaultLng',
      'destination': '$destinationLat,$destinationLng',
      'mode': 'walking',
      'key': _apiKey,
      'language': 'ja',
    });
    final response = await _client.get(uri).timeout(const Duration(seconds: 10));
    _log('Directions http=${response.statusCode}');
    final decoded = _decodeMap(response);
    final status = (decoded['status'] ?? '').toString();
    _log('Directions status=$status');
    if (status != 'OK') return null;
    final routes = (decoded['routes'] as List<dynamic>? ?? []);
    final route = routes.isNotEmpty ? routes.first : null;
    if (route is! Map<String, dynamic>) return null;
    final legs = (route['legs'] as List<dynamic>? ?? []);
    final leg = legs.isNotEmpty ? legs.first : null;
    if (leg is! Map<String, dynamic>) return null;
    final seconds = (leg['duration']?['value'] as num?)?.toInt();
    if (seconds == null) return null;
    _log('Directions minutes=${(seconds / 60).ceil()}');
    return (seconds / 60).ceil();
  }

  Map<String, dynamic> _decodeMap(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Google API failed: ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Google API unexpected response');
    }
    return decoded;
  }

  MapPinModel _mapNearbyToPinModel(Map<String, dynamic> json) {
    final photos = (json['photos'] as List<dynamic>? ?? []);
    final firstPhoto = photos.isNotEmpty ? photos.first : null;
    final photoReference =
        (firstPhoto is Map ? firstPhoto['photo_reference'] : null)?.toString();
    final name = (json['name'] ?? '').toString();
    final lat = (json['geometry']?['location']?['lat'] as num?)?.toDouble();
    final lng = (json['geometry']?['location']?['lng'] as num?)?.toDouble();
    return MapPinModel(
      id: (json['place_id'] ?? '').toString(),
      placeName: name,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      friendComment: '人気カテゴリ: $name',
      imageUrl: photoReference == null
          ? ''
          : buildPhotoUrl(photoReference: photoReference),
      isFriendVisited: false,
      friendAvatars: const [],
      latitude: lat,
      longitude: lng,
    );
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('[GooglePlacesDataSource] $message');
  }
}
