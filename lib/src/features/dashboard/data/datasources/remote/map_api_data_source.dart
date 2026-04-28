import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/map_pin_model.dart';
import '../../models/place_detail_model.dart';

class MapApiDataSource {
  MapApiDataSource({
    required String pinsEndpoint,
    required String placeDetailEndpointTemplate,
    http.Client? client,
  }) : _pinsEndpoint = pinsEndpoint,
       _placeDetailEndpointTemplate = placeDetailEndpointTemplate,
       _client = client ?? http.Client();

  final String _pinsEndpoint;
  final String _placeDetailEndpointTemplate;
  final http.Client _client;

  Future<List<MapPinModel>> getMapPins() async {
    final response = await _client
        .get(Uri.parse(_pinsEndpoint))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Map API failed: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    final List<dynamic> items;
    if (decoded is List<dynamic>) {
      items = decoded;
    } else if (decoded is Map<String, dynamic> && decoded['data'] is List) {
      items = decoded['data'] as List<dynamic>;
    } else {
      throw Exception('Unexpected map API response format');
    }

    return items
        .whereType<Map<String, dynamic>>()
        .map(MapPinModel.fromJson)
        .toList();
  }

  Future<PlaceDetailModel> getPlaceDetail(String placeId) async {
    final endpoint = _placeDetailEndpointTemplate.replaceAll(
      '{placeId}',
      placeId,
    );
    final response = await _client
        .get(Uri.parse(endpoint))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Place detail API failed: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      if (decoded['data'] is Map<String, dynamic>) {
        return PlaceDetailModel.fromJson(
          decoded['data'] as Map<String, dynamic>,
        );
      }
      return PlaceDetailModel.fromJson(decoded);
    }
    throw Exception('Unexpected place detail response format');
  }
}
