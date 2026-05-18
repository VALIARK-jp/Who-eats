import 'dart:math' as math;

import '../../domain/entities/app_entities.dart';
import '../../domain/repositories/dashboard_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../datasources/mock_dashboard_data_source.dart';
import '../datasources/remote/google_places_data_source.dart';
import '../datasources/remote/map_api_data_source.dart';
import '../../../../core/supabase/supabase_tables.dart';

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
  SupabaseClient get _supabase => Supabase.instance.client;

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
  Future<List<MapPin>> getMapPins() async {
    _log('getMapPins start');
    final dbPins = await _getDbPostedPinsAround(
      lat: 35.6595,
      lng: 139.7005,
      radiusMeters: 6000,
      keyword: null,
    );
    if (_googlePlacesDataSource != null) {
      try {
        final googlePins = await _googlePlacesDataSource.searchNearbyPlaces(
          keyword: 'restaurant',
        );
        if (googlePins.isNotEmpty) {
          final postedPlaceIds = dbPins.map((e) => e.id).toSet();
          _log('getMapPins source=google count=${googlePins.length}');
          final merged = _mergeMapPinsPreferDb(
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
          return merged;
        }
      } catch (e) {
        _log('getMapPins google failed: $e');
      }
    }
    if (dbPins.isNotEmpty) return dbPins;

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
    final dbPins = await _getDbPostedPinsAround(
      lat: 35.6595,
      lng: 139.7005,
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
    final dbPins = await _getDbPostedPinsAround(
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

    if (_googlePlacesDataSource != null) {
      try {
        final googleDetail = await _googlePlacesDataSource.getPlaceDetail(
          placeId,
        );
        final myPlacePosts = await _getMyPlacePosts(placeGoogleId: placeId);
        _log('getPlaceDetail source=google');
        final entity = googleDetail.toEntity();
        return PlaceDetail(
          placeId: entity.placeId,
          placeName: entity.placeName,
          rating: entity.rating,
          friendComment: entity.friendComment,
          imageUrl: entity.imageUrl,
          posts: [...myPlacePosts, ...entity.posts],
          address: entity.address,
          phoneNumber: entity.phoneNumber,
          openNow: entity.openNow,
          travelMinutes: entity.travelMinutes,
          latitude: entity.latitude,
          longitude: entity.longitude,
        );
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

  Future<List<MapPin>> _getDbPostedPinsAround({
    required double lat,
    required double lng,
    required int radiusMeters,
    String? keyword,
  }) async {
    try {
      final tPlaces = SupabaseTables.places;
      final tImages = SupabaseTables.postImages;
      final rows = await _supabase
          .from(SupabaseTables.posts)
          .select(
            'id,caption,created_at,$tPlaces!inner(google_place_id,name,latitude,longitude),$tImages(storage_path,display_order)',
          )
          .eq('post_type', 'restaurant')
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false)
          .limit(250);

      final byPlace = <String, MapPin>{};
      final q = (keyword ?? '').trim().toLowerCase();
      for (final raw in (rows as List<dynamic>)) {
        final row = raw as Map<String, dynamic>;
        final place = _extractEmbeddedPlace(row[tPlaces]);
        if (place == null) continue;
        final placeId = (place['google_place_id'] ?? '').toString();
        if (placeId.isEmpty || byPlace.containsKey(placeId)) continue;
        final placeName = (place['name'] ?? '').toString();
        final plat = (place['latitude'] as num?)?.toDouble();
        final plng = (place['longitude'] as num?)?.toDouble();
        if (plat == null || plng == null) continue;
        if (_distanceMeters(lat, lng, plat, plng) > radiusMeters) continue;
        if (q.isNotEmpty &&
            !placeName.toLowerCase().contains(q) &&
            !(row['caption'] ?? '').toString().toLowerCase().contains(q)) {
          continue;
        }
        String imageUrl = '';
        final images = (row[tImages] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        if (images.isNotEmpty) {
          images.sort(
            (a, b) => ((a['display_order'] as num?) ?? 0).compareTo(
              ((b['display_order'] as num?) ?? 0),
            ),
          );
          final storagePath = (images.first['storage_path'] ?? '').toString();
          if (storagePath.isNotEmpty) {
            imageUrl = await _supabase.storage
                .from('post-images')
                .createSignedUrl(storagePath, 60 * 60 * 24);
          }
        }
        byPlace[placeId] = MapPin(
          id: placeId,
          placeName: placeName,
          rating: 4.5,
          friendComment: (row['caption'] ?? '投稿あり').toString(),
          imageUrl: imageUrl,
          isFriendVisited: true,
          friendAvatars: const [],
          latitude: plat,
          longitude: plng,
        );
      }
      return byPlace.values.toList();
    } catch (e) {
      _log('_getDbPostedPinsAround failed: $e');
      return const [];
    }
  }

  double _distanceMeters(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLng = _deg2rad(lng2 - lng1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  double _deg2rad(double d) => d * (math.pi / 180.0);

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
    final images = (row['post_images'] as List<dynamic>? ?? [])
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

  Future<List<PlacePostPreview>> _getMyPlacePosts({
    required String placeGoogleId,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    final user = _supabase.auth.currentUser;
    if (uid == null || user == null) return const [];
    try {
      final tPlaces = SupabaseTables.places;
      final tImages = SupabaseTables.postImages;
      final rows = await _supabase
          .from(SupabaseTables.posts)
          .select(
            'id,caption,$tPlaces!inner(google_place_id),$tImages(storage_path,display_order)',
          )
          .eq('user_id', uid)
          .eq('$tPlaces.google_place_id', placeGoogleId)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false)
          .limit(8);
      final result = <PlacePostPreview>[];
      for (final e in (rows as List<dynamic>)) {
        final row = e as Map<String, dynamic>;
        final images = (row[tImages] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        String? imageUrl;
        if (images.isNotEmpty) {
          images.sort(
            (a, b) => ((a['display_order'] as num?) ?? 0).compareTo(
              ((b['display_order'] as num?) ?? 0),
            ),
          );
          final storagePath = (images.first['storage_path'] ?? '').toString();
          if (storagePath.isNotEmpty) {
            imageUrl = await _supabase.storage
                .from('post-images')
                .createSignedUrl(storagePath, 60 * 60 * 24 * 7);
          }
        }
        result.add(
          PlacePostPreview(
            id: row['id'].toString(),
            userName: (user.email ?? 'me').split('@').first,
            comment: (row['caption'] ?? '').toString(),
            imageUrl: imageUrl,
          ),
        );
      }
      return result;
    } catch (e) {
      _log('_getMyPlacePosts failed: $e');
      return const [];
    }
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
