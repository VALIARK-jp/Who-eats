import '../../domain/entities/app_entities.dart';
import '../../domain/repositories/dashboard_repository.dart';
import 'package:flutter/foundation.dart';
import '../datasources/mock_dashboard_data_source.dart';
import '../datasources/remote/google_places_data_source.dart';
import '../datasources/remote/map_api_data_source.dart';
import '../datasources/supabase_map_pins_data_source.dart';
import '../datasources/supabase_social_data_source.dart';
import '../../../../core/config/app_config.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  DashboardRepositoryImpl({
    required MockDashboardDataSource dataSource,
    MapApiDataSource? mapApiDataSource,
    GooglePlacesDataSource? googlePlacesDataSource,
    SupabaseMapPinsDataSource? supabaseMapPinsDataSource,
    SupabaseSocialDataSource? supabaseSocialDataSource,
  }) : _dataSource = dataSource,
       _mapApiDataSource = mapApiDataSource,
       _googlePlacesDataSource = googlePlacesDataSource,
       _supabaseMapPins =
           supabaseMapPinsDataSource ?? SupabaseMapPinsDataSource(),
       _social = supabaseSocialDataSource ?? SupabaseSocialDataSource();

  final MockDashboardDataSource _dataSource;
  final MapApiDataSource? _mapApiDataSource;
  final GooglePlacesDataSource? _googlePlacesDataSource;
  final SupabaseMapPinsDataSource _supabaseMapPins;
  final SupabaseSocialDataSource _social;

  static const _defaultMapLat = 35.6595;
  static const _defaultMapLng = 139.7005;
  static const _initialMapRadiusMeters = 6000;

  bool get _useSupabase => AppConfig.hasSupabase;

  @override
  Future<PostDraft> createPostDraft() async {
    if (_useSupabase) {
      return const PostDraft(
        photoUrl: '',
        placeName: '',
        note: '',
        withWho: '',
      );
    }
    return _dataSource.createPostDraft();
  }

  @override
  Future<List<FriendCandidate>> getFriends() async {
    if (!_useSupabase) return _dataSource.getFriendCandidates();
    return _social.fetchFriends();
  }

  @override
  Future<List<FriendCandidate>> getFriendRecommendations() async {
    if (!_useSupabase) return const [];
    return _social.fetchFriendRecommendations();
  }

  @override
  Future<bool> followUser(String targetUserId) async {
    if (!_useSupabase) return false;
    return _social.followUser(targetUserId);
  }

  @override
  Future<void> unfollowUser(String targetUserId) async {
    if (!_useSupabase) return;
    await _social.unfollowUser(targetUserId);
  }

  @override
  Future<bool> togglePostLike(String postId) async {
    if (!_useSupabase) return false;
    return _social.togglePostLike(postId);
  }

  @override
  Future<List<PostComment>> getPostComments(String postId) async {
    if (!_useSupabase) return const [];
    return _social.fetchPostComments(postId);
  }

  @override
  Future<PostComment> createPostComment(String postId, String body) async {
    if (!_useSupabase) {
      throw StateError('comments require Supabase');
    }
    return _social.createPostComment(postId, body);
  }

  @override
  Future<void> deletePostComment(String commentId) async {
    if (!_useSupabase) return;
    await _social.deletePostComment(commentId);
  }

  @override
  Future<List<FriendCandidate>> searchUsersByCode(String query) async {
    if (!_useSupabase) return _dataSource.searchUsersByCode(query);
    return _social.searchUsersByCode(query);
  }

  @override
  Future<void> softDeletePost(String postId) async {
    if (!_useSupabase) return;
    await _social.softDeletePost(postId);
  }

  @override
  Future<void> updatePostCaption(String postId, String caption) async {
    if (!_useSupabase) return;
    await _social.updatePostCaption(postId, caption);
  }

  @override
  Future<List<RecordDayEntry>> getPostsForDay(DateTime dayLocal) async {
    if (!_useSupabase) return const [];
    return _social.fetchPostsForDay(dayLocal);
  }

  @override
  Future<FeedPost?> getFeedPostById(String postId) async {
    if (!_useSupabase) return null;
    return _social.fetchFeedPostById(postId);
  }

  @override
  Future<UserPublicProfile?> getUserPublicProfile(String userId) async {
    if (!_useSupabase) return null;
    return _social.fetchUserPublicProfile(userId);
  }

  @override
  Future<void> blockUser(String userId) async {
    if (!_useSupabase) return;
    await _social.blockUser(userId);
  }

  @override
  Future<void> unblockUser(String userId) async {
    if (!_useSupabase) return;
    await _social.unblockUser(userId);
  }

  @override
  Future<List<PendingMealTag>> getPendingMealTags() async {
    if (!_useSupabase) return const [];
    return _social.listPendingMealTags();
  }

  @override
  Future<List<FriendCandidate>> getIncomingFriendRequests() async {
    if (!_useSupabase) return const [];
    return _social.fetchIncomingFriendRequests();
  }

  @override
  Future<List<FriendCandidate>> getOutgoingPendingFollows() async {
    if (!_useSupabase) return const [];
    return _social.fetchOutgoingPendingFollows();
  }

  @override
  Future<List<FeedPost>> getHomeFeed({
    FeedTimelineScope scope = FeedTimelineScope.all,
  }) async {
    if (_useSupabase) return _social.fetchHomeFeed(scope: scope);
    return _dataSource.getHomeFeed();
  }

  @override
  Future<List<MapPin>> getMapPins({
    double? centerLat,
    double? centerLng,
  }) async {
    _log('getMapPins start');
    if (!_useSupabase) return _dataSource.getMapPins();

    final lat = centerLat ?? _defaultMapLat;
    final lng = centerLng ?? _defaultMapLng;
    final friendIds = await _social.fetchMutualFriendIds();
    final dbPins = await _supabaseMapPins.fetchPostedPinsAround(
      lat: lat,
      lng: lng,
      radiusMeters: _initialMapRadiusMeters,
      mutualFriendIds: friendIds,
    );
    if (dbPins.isNotEmpty) {
      _log('getMapPins source=supabase count=${dbPins.length}');
    }

    if (_googlePlacesDataSource != null) {
      try {
        final googlePins = await _googlePlacesDataSource
            .searchNearbyPlacesAround(
              lat: lat,
              lng: lng,
              radiusMeters: _initialMapRadiusMeters,
              keyword: 'restaurant',
            );
        if (googlePins.isNotEmpty) {
          final postedPlaceIds = dbPins.map((e) => e.id).toSet();
          _log('getMapPins source=google+db count=${googlePins.length}');
          return _mergeMapPinsPreferDb(
            dbPins: dbPins,
            googlePins: googlePins
                .map(
                  (pin) => pin.toEntity().copyWith(
                    isFriendVisited:
                        pin.toEntity().isFriendVisited ||
                        postedPlaceIds.contains(pin.id),
                  ),
                )
                .toList(),
          );
        }
      } catch (e) {
        _log('getMapPins google failed: $e');
      }
    }

    if (dbPins.isNotEmpty) return dbPins;

    if (_mapApiDataSource != null) {
      try {
        final remotePins = await _mapApiDataSource.getMapPins();
        if (remotePins.isNotEmpty) {
          _log('getMapPins source=mapApi count=${remotePins.length}');
          return remotePins.map((pin) => pin.toEntity()).toList();
        }
      } catch (e) {
        _log('getMapPins mapApi failed: $e');
      }
    }

    _log('getMapPins source=empty');
    return const [];
  }

  @override
  Future<List<MapPin>> searchMapPins(String keyword) async {
    _log('searchMapPins keyword=$keyword');
    if (!_useSupabase) return _dataSource.searchMapPins(keyword);
    final friendIds = await _social.fetchMutualFriendIds();
    final dbPins = await _supabaseMapPins.fetchPostedPinsAround(
      lat: _defaultMapLat,
      lng: _defaultMapLng,
      radiusMeters: 12000,
      keyword: keyword,
      mutualFriendIds: friendIds,
    );

    if (_googlePlacesDataSource != null) {
      try {
        final googlePins = await _googlePlacesDataSource.searchNearbyPlaces(
          keyword: keyword,
        );
        final postedPlaceIds = dbPins.map((e) => e.id).toSet();
        _log('searchMapPins source=google count=${googlePins.length}');
        return _mergeMapPinsPreferDb(
          dbPins: dbPins,
          googlePins: googlePins
              .map(
                (pin) => pin.toEntity().copyWith(
                  isFriendVisited:
                      pin.toEntity().isFriendVisited ||
                      postedPlaceIds.contains(pin.id),
                ),
              )
              .toList(),
        );
      } catch (e) {
        _log('searchMapPins google failed: $e');
      }
    }
    if (dbPins.isNotEmpty) return dbPins;
    _log('searchMapPins source=empty');
    return const [];
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
    if (!_useSupabase) {
      return _dataSource.searchMapPins(keyword ?? 'restaurant');
    }
    final friendIds = await _social.fetchMutualFriendIds();
    final dbPins = await _supabaseMapPins.fetchPostedPinsAround(
      lat: lat,
      lng: lng,
      radiusMeters: radiusMeters,
      keyword: keyword,
      mutualFriendIds: friendIds,
    );

    if (_googlePlacesDataSource != null) {
      try {
        final googlePins = await _googlePlacesDataSource
            .searchNearbyPlacesAround(
              lat: lat,
              lng: lng,
              radiusMeters: radiusMeters,
              keyword: keyword,
            );
        final postedPlaceIds = dbPins.map((e) => e.id).toSet();
        _log('searchMapPinsAround source=google count=${googlePins.length}');
        return _mergeMapPinsPreferDb(
          dbPins: dbPins,
          googlePins: googlePins
              .map(
                (pin) => pin.toEntity().copyWith(
                  isFriendVisited:
                      pin.toEntity().isFriendVisited ||
                      postedPlaceIds.contains(pin.id),
                ),
              )
              .toList(),
        );
      } catch (e) {
        _log('searchMapPinsAround google failed: $e');
      }
    }
    if (dbPins.isNotEmpty) return dbPins;
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

    final dbPosts = _useSupabase
        ? await _supabaseMapPins.fetchVisiblePlacePosts(placeGoogleId: placeId)
        : const <PlacePostPreview>[];

    if (_googlePlacesDataSource != null) {
      try {
        final googleDetail = await _googlePlacesDataSource.getPlaceDetail(
          placeId,
        );
        _log('getPlaceDetail source=google posts=${dbPosts.length}');
        final entity = googleDetail.toEntity();
        return PlaceDetail(
          placeId: entity.placeId,
          placeName: entity.placeName,
          rating: entity.rating,
          friendComment: entity.friendComment,
          imageUrl: entity.imageUrl,
          posts: dbPosts,
          address: entity.address,
          phoneNumber: entity.phoneNumber,
          openNow: entity.openNow,
          travelMinutes: entity.travelMinutes,
          latitude: entity.latitude,
          longitude: entity.longitude,
          websiteUrl: entity.websiteUrl,
          googleMapsUrl: entity.googleMapsUrl,
        );
      } catch (e) {
        _log('getPlaceDetail google failed: $e');
        if (!isMockPlaceId) {
          final fromDb = await _supabaseMapPins.fetchPlaceDetailShell(
            placeGoogleId: placeId,
          );
          if (fromDb != null) {
            _log('getPlaceDetail source=supabase');
            return fromDb;
          }
          rethrow;
        }
      }
    }

    if (_useSupabase) {
      final fromDb = await _supabaseMapPins.fetchPlaceDetailShell(
        placeGoogleId: placeId,
      );
      if (fromDb != null) {
        _log('getPlaceDetail source=supabase');
        return fromDb;
      }
    }

    if (_mapApiDataSource != null) {
      try {
        final remote = await _mapApiDataSource.getPlaceDetail(placeId);
        _log('getPlaceDetail source=mapApi');
        final entity = remote.toEntity();
        return PlaceDetail(
          placeId: entity.placeId,
          placeName: entity.placeName,
          rating: entity.rating,
          friendComment: entity.friendComment,
          imageUrl: entity.imageUrl,
          posts: dbPosts,
          address: entity.address,
          phoneNumber: entity.phoneNumber,
          openNow: entity.openNow,
          travelMinutes: entity.travelMinutes,
          latitude: entity.latitude,
          longitude: entity.longitude,
          websiteUrl: entity.websiteUrl,
          googleMapsUrl: entity.googleMapsUrl,
        );
      } catch (e) {
        _log('getPlaceDetail mapApi failed: $e');
        if (!isMockPlaceId) rethrow;
      }
    }

    if (isMockPlaceId && !_useSupabase) {
      _log('getPlaceDetail source=mock legacy id');
      return _dataSource.getPlaceDetail(placeId);
    }

    throw Exception('Place detail not found for placeId: $placeId');
  }

  @override
  Future<List<PlaceSuggestion>> autocompletePlaces(
    String query, {
    double? biasLat,
    double? biasLng,
  }) async {
    _log('autocomplete query="$query" biasLat=$biasLat biasLng=$biasLng');
    if (_googlePlacesDataSource != null) {
      try {
        final suggestions = await _googlePlacesDataSource.autocomplete(
          query,
          originLat: biasLat,
          originLng: biasLng,
        );
        if (suggestions.isNotEmpty) return suggestions;
      } catch (e) {
        _log('autocomplete google failed: $e');
      }
    }
    if (_useSupabase) {
      _log('autocomplete source=empty');
      return const [];
    }
    _log('autocomplete source=mock');
    return _dataSource.autocompletePlaces(
      query,
      biasLat: biasLat,
      biasLng: biasLng,
    );
  }

  @override
  Future<List<AppNotification>> getNotifications() async {
    if (!_useSupabase) return _dataSource.getNotifications();
    return _social.fetchNotifications();
  }

  @override
  Future<void> markAllNotificationsRead() async {
    if (!_useSupabase) return;
    await _social.markAllNotificationsRead();
  }

  @override
  Future<ProfileOverview> getProfileOverview() async {
    if (_useSupabase) return _social.fetchProfileOverview();
    return _dataSource.getProfileOverview();
  }

  @override
  Future<List<FeedPost>> getFavoritePosts() async {
    if (!_useSupabase) return const [];
    return _social.fetchFavoritePosts();
  }

  @override
  Future<void> setProfilePostPinned(String postId, bool pin) async {
    if (!_useSupabase) return;
    await _social.setProfilePostPinned(postId, pin);
  }

  @override
  Future<bool> togglePostFavorite(String postId) async {
    if (!_useSupabase) return false;
    return _social.togglePostFavorite(postId);
  }

  @override
  Future<RecordSummary> getRecordSummary() async {
    if (!_useSupabase) return _dataSource.getRecordSummary();
    return _social.fetchRecordSummary();
  }

  @override
  Future<List<ProfilePostThumb>> getProfilePostThumbs({
    required bool pinnedOnly,
  }) async {
    if (!_useSupabase) {
      final profile = await _dataSource.getProfileOverview();
      return pinnedOnly ? profile.pinnedPosts : profile.recentPosts;
    }
    return _social.fetchProfilePostThumbs(pinnedOnly: pinnedOnly);
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('[DashboardRepositoryImpl] $message');
  }

  List<MapPin> _mergeMapPinsPreferDb({
    required List<MapPin> dbPins,
    required List<MapPin> googlePins,
  }) {
    final merged = <String, MapPin>{};
    for (final pin in dbPins) {
      merged[pin.id] = pin.copyWith(isFriendVisited: true);
    }
    for (final pin in googlePins) {
      merged.putIfAbsent(pin.id, () => pin);
    }
    return merged.values.toList();
  }
}
