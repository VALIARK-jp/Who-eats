import '../../domain/entities/app_entities.dart';
import '../../domain/repositories/dashboard_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../datasources/mock_dashboard_data_source.dart';
import '../datasources/remote/google_places_data_source.dart';
import '../datasources/remote/map_api_data_source.dart';
import '../datasources/supabase_map_pins_data_source.dart';
import '../../../../core/supabase/supabase_tables.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  DashboardRepositoryImpl({
    required MockDashboardDataSource dataSource,
    MapApiDataSource? mapApiDataSource,
    GooglePlacesDataSource? googlePlacesDataSource,
    SupabaseMapPinsDataSource? supabaseMapPinsDataSource,
  }) : _dataSource = dataSource,
       _mapApiDataSource = mapApiDataSource,
       _googlePlacesDataSource = googlePlacesDataSource,
       _supabaseMapPins =
           supabaseMapPinsDataSource ?? SupabaseMapPinsDataSource();

  final MockDashboardDataSource _dataSource;
  final MapApiDataSource? _mapApiDataSource;
  final GooglePlacesDataSource? _googlePlacesDataSource;
  final SupabaseMapPinsDataSource _supabaseMapPins;
  SupabaseClient get _supabase => Supabase.instance.client;

  static const _defaultMapLat = 35.6595;
  static const _defaultMapLng = 139.7005;
  static const _initialMapRadiusMeters = 6000;

  bool get _hasAuthUser => _supabase.auth.currentUser != null;

  @override
  Future<PostDraft> createPostDraft() => _dataSource.createPostDraft();

  @override
  Future<List<FriendCandidate>> getFriendCandidates() =>
      _dataSource.getFriendCandidates();

  @override
  Future<List<FeedPost>> getHomeFeed() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid != null) {
      try {
        // RLS (`posts_select_visible`) applies visibility + block rules.
        return await _getHomeFeedFromSupabase();
      } catch (e) {
        _log('getHomeFeed supabase failed: $e');
        return _dataSource.getHomeFeed();
      }
    }
    return _dataSource.getHomeFeed();
  }

  @override
  Future<List<MapPin>> getMapPins({
    double? centerLat,
    double? centerLng,
  }) async {
    _log('getMapPins start');
    if (!_hasAuthUser) return const [];

    final lat = centerLat ?? _defaultMapLat;
    final lng = centerLng ?? _defaultMapLng;
    final dbPins = await _supabaseMapPins.fetchPostedPinsAround(
      lat: lat,
      lng: lng,
      radiusMeters: _initialMapRadiusMeters,
    );
    if (dbPins.isNotEmpty) {
      _log('getMapPins source=supabase count=${dbPins.length}');
    }

    if (_googlePlacesDataSource != null) {
      try {
        final googlePins = await _googlePlacesDataSource.searchNearbyPlaces(
          keyword: 'restaurant',
        );
        if (googlePins.isNotEmpty) {
          final postedPlaceIds = dbPins.map((e) => e.id).toSet();
          _log('getMapPins source=google count=${googlePins.length}');
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
    if (!_hasAuthUser) return const [];
    final dbPins = await _supabaseMapPins.fetchPostedPinsAround(
      lat: _defaultMapLat,
      lng: _defaultMapLng,
      radiusMeters: 12000,
      keyword: keyword,
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
    if (!_hasAuthUser) return const [];
    final dbPins = await _supabaseMapPins.fetchPostedPinsAround(
      lat: lat,
      lng: lng,
      radiusMeters: radiusMeters,
      keyword: keyword,
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

    final dbPosts = _hasAuthUser
        ? await _supabaseMapPins.fetchVisiblePlacePosts(
            placeGoogleId: placeId,
          )
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
          posts: dbPosts.isNotEmpty ? dbPosts : entity.posts,
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

    if (_hasAuthUser) {
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
          posts: dbPosts.isNotEmpty ? dbPosts : entity.posts,
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

    if (isMockPlaceId) {
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
    _log('autocomplete source=mock');
    return _dataSource.autocompletePlaces(
      query,
      biasLat: biasLat,
      biasLng: biasLng,
    );
  }

  @override
  Future<List<AppNotification>> getNotifications() =>
      _dataSource.getNotifications();

  @override
  Future<ProfileOverview> getProfileOverview() async {
    final base = await _dataSource.getProfileOverview();
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return base;

    try {
      final row = await _supabase
          .from(SupabaseTables.profiles)
          .select('name, user_code, bio, icon_path, avatar_url')
          .eq('id', uid)
          .maybeSingle();
      if (row == null) return base;

      final name = (row['name'] ?? '').toString().trim();
      final userCode = (row['user_code'] ?? '').toString().trim();
      final bio = (row['bio'] ?? '').toString().trim();
      final iconUrl = await _profileIconUrlFromRow(row);

      return ProfileOverview(
        name: name.isNotEmpty ? name : base.name,
        userCode: userCode.isNotEmpty ? userCode : base.userCode,
        bio: bio,
        avatarUrl: iconUrl ?? base.avatarUrl,
        followers: base.followers,
        following: base.following,
        pinnedShots: base.pinnedShots,
        recentShots: base.recentShots,
      );
    } catch (e) {
      _log('getProfileOverview profiles lookup failed: $e');
    }

    return ProfileOverview(
      name: base.name,
      userCode: base.userCode,
      bio: base.bio,
      avatarUrl: base.avatarUrl,
      followers: base.followers,
      following: base.following,
      pinnedShots: base.pinnedShots,
      recentShots: base.recentShots,
    );
  }

  @override
  Future<RecordSummary> getRecordSummary() => _dataSource.getRecordSummary();

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

  Future<List<FeedPost>> _getHomeFeedFromSupabase() async {
    if (_supabase.auth.currentUser?.id == null) return const [];

    final tProfiles = SupabaseTables.profiles;
    final tPlaces = SupabaseTables.places;
    final tImages = SupabaseTables.postImages;
    final rows = await _supabase
        .from(SupabaseTables.posts)
        .select('''
          id,caption,created_at,post_type,
          $tProfiles(name,icon_path,email),
          $tPlaces(name,google_place_id),
          $tImages(storage_path,display_order)
        ''')
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false)
        .limit(50);

    final list = <FeedPost>[];
    for (final raw in (rows as List<dynamic>)) {
      final row = raw as Map<String, dynamic>;
      final post = await _feedPostFromTimelineRow(row);
      if (post != null) list.add(post);
    }
    return list;
  }

  Future<FeedPost?> _feedPostFromTimelineRow(Map<String, dynamic> row) async {
    final tImages = SupabaseTables.postImages;
    final images = (row[tImages] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    if (images.isEmpty) return null;
    images.sort(
      (a, b) => ((a['display_order'] as num?) ?? 0).compareTo(
        ((b['display_order'] as num?) ?? 0),
      ),
    );
    final storagePath = (images.first['storage_path'] ?? '').toString();
    if (storagePath.isEmpty) return null;

    String imageUrl;
    try {
      imageUrl = await _supabase.storage
          .from('post-images')
          .createSignedUrl(storagePath, 60 * 60 * 24 * 7);
    } catch (e) {
      _log('_feedPostFromTimelineRow signed url failed: $e');
      return null;
    }

    final author =
        _extractEmbeddedUser(row[SupabaseTables.profiles]) ??
        _extractEmbeddedUser(row['users']);
    final displayName = (author?['name'] ?? '').toString().trim();
    final email = (author?['email'] ?? '').toString();
    final userName = displayName.isNotEmpty
        ? displayName
        : (email.isNotEmpty ? email.split('@').first : 'user');

    final iconPath = (author?['avatar_url'] ?? author?['icon_path'] ?? '')
        .toString();
    final userIconUrl = await _signedStorageOrAbsoluteUrl(iconPath);

    final place = _extractEmbeddedPlace(row['places']);
    final postType = (row['post_type'] ?? 'restaurant').toString();
    final placeName = place != null
        ? (place['name'] ?? '不明な店舗').toString()
        : (postType == 'home' ? 'ホーム' : '不明な店舗');

    return FeedPost(
      id: row['id'].toString(),
      userName: userName,
      userIconUrl: userIconUrl,
      placeName: placeName,
      placeGoogleId: (place?['google_place_id'] ?? '').toString(),
      caption: (row['caption'] ?? '').toString(),
      imageUrl: imageUrl,
      likes: 0,
      comments: 0,
      friendAvatars: const [],
    );
  }

  Future<String?> _signedStorageOrAbsoluteUrl(String iconPath) async {
    if (iconPath.isEmpty) return null;
    if (iconPath.startsWith('http://') || iconPath.startsWith('https://')) {
      return iconPath;
    }
    try {
      return await _supabase.storage
          .from('post-images')
          .createSignedUrl(iconPath, 60 * 60 * 24 * 7);
    } catch (e) {
      _log('_signedStorageOrAbsoluteUrl failed: $e');
      return null;
    }
  }

  Map<String, dynamic>? _extractEmbeddedUser(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is List && raw.isNotEmpty && raw.first is Map<String, dynamic>) {
      return raw.first as Map<String, dynamic>;
    }
    return null;
  }

  Future<String?> _profileIconUrlFromRow(Map<String, dynamic>? row) async {
    final direct = (row?['icon_path'] ?? row?['avatar_url'] ?? '').toString();
    if (direct.startsWith('http://') || direct.startsWith('https://')) {
      return direct;
    }
    if (direct.isEmpty) return null;
    return _supabase.storage
        .from('post-images')
        .createSignedUrl(direct, 60 * 60 * 24 * 7);
  }

  Map<String, dynamic>? _extractEmbeddedPlace(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is List && raw.isNotEmpty && raw.first is Map<String, dynamic>) {
      return raw.first as Map<String, dynamic>;
    }
    return null;
  }
}
