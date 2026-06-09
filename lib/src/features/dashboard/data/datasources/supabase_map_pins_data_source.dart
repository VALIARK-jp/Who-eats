import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_storage_urls.dart';
import '../../../../core/supabase/supabase_tables.dart';
import '../../domain/entities/app_entities.dart';

/// Supabase 上の `whoeats_posts` / `whoeats_places` からマップピン・店舗投稿を取得。
class SupabaseMapPinsDataSource {
  SupabaseMapPinsDataSource({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _defaultLat = 35.6595;
  static const _defaultLng = 139.7005;

  Future<List<MapPin>> fetchPostedPinsAround({
    double? lat,
    double? lng,
    required int radiusMeters,
    String? keyword,
    Set<String> mutualFriendIds = const {},
  }) async {
    final centerLat = lat ?? _defaultLat;
    final centerLng = lng ?? _defaultLng;
    if (_client.auth.currentUser == null) return const [];

    try {
      final rows = await _client.rpc(
        'get_restaurant_post_activity_in_radius',
        params: {
          'p_lat': centerLat,
          'p_lng': centerLng,
          'p_radius_meters': radiusMeters,
        },
      );

      final currentUserId = _client.auth.currentUser!.id;
      final aggregates = <String, _PlacePinAggregate>{};
      final q = (keyword ?? '').trim().toLowerCase();

      for (final raw in (rows as List<dynamic>)) {
        final row = raw as Map<String, dynamic>;
        final placeId = (row['google_place_id'] ?? '').toString();
        if (placeId.isEmpty) continue;

        final placeName = (row['place_name'] ?? '').toString();
        final plat = (row['latitude'] as num?)?.toDouble();
        final plng = (row['longitude'] as num?)?.toDouble();
        if (plat == null || plng == null) continue;

        if (q.isNotEmpty && !placeName.toLowerCase().contains(q)) {
          continue;
        }

        final userId = (row['user_id'] ?? '').toString();
        final userName = (row['user_name'] ?? '').toString().trim();
        final isFriend =
            mutualFriendIds.isNotEmpty && mutualFriendIds.contains(userId);
        final isMe = userId == currentUserId;

        final agg = aggregates.putIfAbsent(
          placeId,
          () => _PlacePinAggregate(
            googlePlaceId: placeId,
            placeName: placeName,
            latitude: plat,
            longitude: plng,
          ),
        );
        agg.addVisitor(
          userId: userId,
          userName: userName.isNotEmpty ? userName : 'user',
          isFriend: isFriend,
          isMe: isMe,
        );
      }

      return aggregates.values.map((a) => a.toMapPin()).toList();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[SupabaseMapPinsDataSource] fetchPostedPinsAround: $e\n$st');
      }
      return const [];
    }
  }

  Future<List<PlaceVisitor>> fetchPlaceVisitors({
    required String placeGoogleId,
    Set<String> mutualFriendIds = const {},
  }) async {
    if (_client.auth.currentUser == null) return const [];
    try {
      final rows = await _client.rpc(
        'get_place_visitors',
        params: {'p_google_place_id': placeGoogleId},
      );
      final currentUserId = _client.auth.currentUser!.id;
      final visitors = <PlaceVisitor>[];
      final seen = <String>{};
      for (final raw in (rows as List<dynamic>)) {
        final row = raw as Map<String, dynamic>;
        final userId = (row['user_id'] ?? '').toString();
        if (userId.isEmpty || seen.contains(userId)) continue;
        seen.add(userId);
        final userName = (row['user_name'] ?? '').toString().trim();
        visitors.add(
          PlaceVisitor(
            userId: userId,
            userName: userName.isNotEmpty ? userName : 'user',
            isFriend: mutualFriendIds.contains(userId),
            isMe: userId == currentUserId,
          ),
        );
      }
      return visitors;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[SupabaseMapPinsDataSource] fetchPlaceVisitors: $e\n$st');
      }
      return const [];
    }
  }

  /// 店舗詳細シート用: 閲覧可能な投稿一覧（RLS 適用）。
  Future<List<PlacePostPreview>> fetchVisiblePlacePosts({
    required String placeGoogleId,
    int limit = 24,
  }) async {
    try {
      final tPlaces = SupabaseTables.places;
      final tAuthor = SupabaseTables.postAuthorEmbed;
      final tImages = SupabaseTables.postImages;
      var query = _client
          .from(SupabaseTables.posts)
          .select(
            'id,caption,created_at,'
            '$tAuthor(name,icon_path,email),'
            '$tPlaces!inner(google_place_id),'
            '$tImages(storage_path,display_order)',
          )
          .eq('$tPlaces.google_place_id', placeGoogleId)
          .eq('post_type', 'restaurant')
          .isFilter('deleted_at', null);

      if (_client.auth.currentUser == null) {
        query = query.eq('visibility', 'public');
      }

      final rows = await query
          .order('created_at', ascending: false)
          .limit(limit);

      final result = <PlacePostPreview>[];
      for (final raw in (rows as List<dynamic>)) {
        final row = raw as Map<String, dynamic>;
        final author =
            _extractEmbeddedMap(row[SupabaseTables.profiles]) ??
            _extractEmbeddedMap(row['whoeats_users']);
        final displayName = (author?['name'] ?? '').toString().trim();
        final email = (author?['email'] ?? '').toString();
        final userName = displayName.isNotEmpty
            ? displayName
            : (email.isNotEmpty ? email.split('@').first : 'user');
        final imageUrl = await _firstImageUrl(row[tImages]);
        result.add(
          PlacePostPreview(
            id: row['id'].toString(),
            userName: userName,
            comment: (row['caption'] ?? '').toString(),
            imageUrl: imageUrl,
          ),
        );
      }
      return result;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[SupabaseMapPinsDataSource] fetchVisiblePlacePosts: $e\n$st');
      }
      return const [];
    }
  }

  Future<PlaceDetail?> fetchPlaceDetailShell({
    required String placeGoogleId,
    Set<String> mutualFriendIds = const {},
  }) async {
    try {
      final tPlaces = SupabaseTables.places;
      final placeRow = await _client
          .from(tPlaces)
          .select('google_place_id,name,latitude,longitude,address')
          .eq('google_place_id', placeGoogleId)
          .maybeSingle();
      if (placeRow == null) return null;

      final posts = await fetchVisiblePlacePosts(placeGoogleId: placeGoogleId);
      final visitors = await fetchPlaceVisitors(
        placeGoogleId: placeGoogleId,
        mutualFriendIds: mutualFriendIds,
      );
      final name = (placeRow['name'] ?? '').toString();
      final lat = (placeRow['latitude'] as num?)?.toDouble();
      final lng = (placeRow['longitude'] as num?)?.toDouble();
      final lead = posts.isNotEmpty
          ? posts.first.comment
          : visitors.isNotEmpty
          ? '${visitors.length}人が訪問'
          : 'まだ訪問記録がありません';

      return PlaceDetail(
        placeId: placeGoogleId,
        placeName: name,
        rating: 0,
        friendComment: lead,
        imageUrl: posts.isNotEmpty ? (posts.first.imageUrl ?? '') : '',
        posts: posts,
        visitors: visitors,
        address: (placeRow['address'] ?? '').toString(),
        phoneNumber: '',
        openNow: null,
        travelMinutes: null,
        latitude: lat,
        longitude: lng,
        websiteUrl: null,
        googleMapsUrl:
            'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(name)}',
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[SupabaseMapPinsDataSource] fetchPlaceDetailShell: $e\n$st');
      }
      return null;
    }
  }

  Future<String> _firstImageUrl(dynamic imagesRaw) async {
    final images = (imagesRaw as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    if (images.isEmpty) return '';
    images.sort(
      (a, b) => ((a['display_order'] as num?) ?? 0).compareTo(
        ((b['display_order'] as num?) ?? 0),
      ),
    );
    final storagePath = (images.first['storage_path'] ?? '').toString();
    return await SupabaseStorageUrls.signedPostImage(_client, storagePath) ?? '';
  }

  Map<String, dynamic>? _extractEmbeddedMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is List && raw.isNotEmpty && raw.first is Map<String, dynamic>) {
      return raw.first as Map<String, dynamic>;
    }
    return null;
  }

}

class _PlacePinAggregate {
  _PlacePinAggregate({
    required this.googlePlaceId,
    required this.placeName,
    required this.latitude,
    required this.longitude,
  });

  final String googlePlaceId;
  final String placeName;
  final double latitude;
  final double longitude;
  final List<PlaceVisitor> _visitors = [];
  bool _hasFriendPost = false;

  void addVisitor({
    required String userId,
    required String userName,
    required bool isFriend,
    required bool isMe,
  }) {
    if (_visitors.any((v) => v.userId == userId)) return;
    _visitors.add(
      PlaceVisitor(
        userId: userId,
        userName: userName,
        isFriend: isFriend,
        isMe: isMe,
      ),
    );
    if (isFriend) _hasFriendPost = true;
  }

  MapPin toMapPin() {
    final comment = _visitors.length > 1
        ? '${_visitors.length}人が訪問'
        : (_visitors.isNotEmpty
              ? '${_visitors.first.userName}が訪問'
              : '投稿あり');
    return MapPin(
      id: googlePlaceId,
      placeName: placeName,
      rating: 0,
      friendComment: comment,
      imageUrl: '',
      isFriendVisited: _hasFriendPost,
      friendAvatars: const [],
      hasPostedActivity: _visitors.isNotEmpty,
      visitors: List<PlaceVisitor>.unmodifiable(_visitors),
      latitude: latitude,
      longitude: longitude,
    );
  }
}
