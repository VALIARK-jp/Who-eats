import '../../domain/entities/app_entities.dart';
import '../../domain/repositories/dashboard_repository.dart';
import 'package:flutter/foundation.dart';
import '../datasources/mock_dashboard_data_source.dart';
import '../datasources/remote/google_places_data_source.dart';
import '../datasources/remote/map_api_data_source.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  DashboardRepositoryImpl({
    required MockDashboardDataSource dataSource,
    MapApiDataSource? mapApiDataSource,
    GooglePlacesDataSource? googlePlacesDataSource,
  }) : _dataSource = dataSource,
       _mapApiDataSource = mapApiDataSource,
       _googlePlacesDataSource = googlePlacesDataSource;

  final MockDashboardDataSource _dataSource;
  final MapApiDataSource? _mapApiDataSource;
  final GooglePlacesDataSource? _googlePlacesDataSource;

  @override
  Future<PostDraft> createPostDraft() => _dataSource.createPostDraft();

  @override
  Future<List<FriendCandidate>> getFriendCandidates() =>
      _dataSource.getFriendCandidates();

  @override
  Future<List<FeedPost>> getHomeFeed() => _dataSource.getHomeFeed();

  @override
  Future<List<MapPin>> getMapPins() async {
    _log('getMapPins start');
    if (_googlePlacesDataSource != null) {
      try {
        final googlePins = await _googlePlacesDataSource.searchNearbyPlaces(
          keyword: 'restaurant',
        );
        if (googlePins.isNotEmpty) {
          _log('getMapPins source=google count=${googlePins.length}');
          return googlePins.map((pin) => pin.toEntity()).toList();
        }
      } catch (e) {
        _log('getMapPins google failed: $e');
      }
    }

    if (_mapApiDataSource == null) {
      return _dataSource.getMapPins();
    }

    try {
      final remotePins = await _mapApiDataSource.getMapPins();
      if (remotePins.isNotEmpty) {
        return remotePins.map((pin) => pin.toEntity()).toList();
      }
    } catch (e) {
      _log('getMapPins mapApi failed: $e');
    }

    _log('getMapPins source=mock');
    return _dataSource.getMapPins();
  }

  @override
  Future<List<MapPin>> searchMapPins(String keyword) async {
    _log('searchMapPins keyword=$keyword');
    if (_googlePlacesDataSource != null) {
      try {
        final googlePins = await _googlePlacesDataSource.searchNearbyPlaces(
          keyword: keyword,
        );
        _log('searchMapPins source=google count=${googlePins.length}');
        return googlePins.map((pin) => pin.toEntity()).toList();
      } catch (e) {
        _log('searchMapPins google failed: $e');
      }
    }
    _log('searchMapPins source=mock');
    return _dataSource.searchMapPins(keyword);
  }

  @override
  Future<List<MapPin>> searchMapPinsAround({
    required double lat,
    required double lng,
    required int radiusMeters,
    String? keyword,
  }) async {
    _log(
      'searchMapPinsAround lat=$lat lng=$lng radius=$radiusMeters keyword=${keyword ?? ''}',
    );
    if (_googlePlacesDataSource != null) {
      try {
        final googlePins = await _googlePlacesDataSource.searchNearbyPlacesAround(
          lat: lat,
          lng: lng,
          radiusMeters: radiusMeters,
          keyword: keyword,
        );
        _log('searchMapPinsAround source=google count=${googlePins.length}');
        return googlePins.map((pin) => pin.toEntity()).toList();
      } catch (e) {
        _log('searchMapPinsAround google failed: $e');
      }
    }
    return searchMapPins(keyword ?? 'restaurant');
  }

  @override
  Future<MapPin?> resolvePlacePinFromCoordinate(double lat, double lng) async {
    _log('resolveFromCoord lat=$lat lng=$lng');
    if (_googlePlacesDataSource != null) {
      try {
        final pin = await _googlePlacesDataSource.resolveNearestRestaurantPin(
          lat: lat,
          lng: lng,
        );
        if (pin != null) {
          _log('resolveFromCoord resolved placeId=${pin.id}');
          return pin.toEntity();
        }
        _log('resolveFromCoord no result');
      } catch (e) {
        _log('resolveFromCoord failed: $e');
      }
    }
    return null;
  }

  @override
  Future<PlaceDetail> getPlaceDetail(String placeId) async {
    final isMockPlaceId = placeId.startsWith('m');
    _log('getPlaceDetail placeId=$placeId isMock=$isMockPlaceId');

    if (_googlePlacesDataSource != null) {
      try {
        final googleDetail = await _googlePlacesDataSource.getPlaceDetail(
          placeId,
        );
        _log('getPlaceDetail source=google');
        return googleDetail.toEntity();
      } catch (e) {
        _log('getPlaceDetail google failed: $e');
        if (!isMockPlaceId) rethrow;
      }
    }

    if (_mapApiDataSource == null) {
      if (!isMockPlaceId) {
        throw Exception('Place detail fetch failed for placeId: $placeId');
      }
      return _dataSource.getPlaceDetail(placeId);
    }

    try {
      final remote = await _mapApiDataSource.getPlaceDetail(placeId);
      _log('getPlaceDetail source=mapApi');
      return remote.toEntity();
    } catch (e) {
      _log('getPlaceDetail mapApi failed: $e');
      if (!isMockPlaceId) rethrow;
    }

    _log('getPlaceDetail source=mock');
    return _dataSource.getPlaceDetail(placeId);
  }

  @override
  Future<List<PlaceSuggestion>> autocompletePlaces(String query) async {
    _log('autocomplete query="$query"');
    if (_googlePlacesDataSource != null) {
      try {
        final suggestions = await _googlePlacesDataSource.autocomplete(query);
        if (suggestions.isNotEmpty) return suggestions;
      } catch (e) {
        _log('autocomplete google failed: $e');
      }
    }
    _log('autocomplete source=mock');
    return _dataSource.autocompletePlaces(query);
  }

  @override
  Future<List<AppNotification>> getNotifications() =>
      _dataSource.getNotifications();

  @override
  Future<ProfileOverview> getProfileOverview() =>
      _dataSource.getProfileOverview();

  @override
  Future<RecordSummary> getRecordSummary() => _dataSource.getRecordSummary();

  void _log(String message) {
    if (kDebugMode) debugPrint('[DashboardRepositoryImpl] $message');
  }
}
