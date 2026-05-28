import 'dart:math' as math;

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
    final isAnon = _client.auth.currentUser == null;

    try {
      final tPlaces = SupabaseTables.places;
      final tAuthor = SupabaseTables.postAuthorEmbed;
      final tImages = SupabaseTables.postImages;
      var query = _client
          .from(SupabaseTables.posts)
          .select(
            'id,caption,created_at,user_id,rating,'
            '$tAuthor(name,icon_path),'
            '$tPlaces!inner(google_place_id,name,latitude,longitude),'
            '$tImages(storage_path,display_order)',
          )
          .eq('post_type', 'restaurant')
          .isFilter('deleted_at', null);

      if (isAnon) {
        query = query.eq('visibility', 'public');
      }

      final rows = await query
          .order('created_at', ascending: false)
          .limit(300);

      final aggregates = <String, _PlacePinAggregate>{};
      final q = (keyword ?? '').trim().toLowerCase();

      for (final raw in (rows as List<dynamic>)) {
        final row = raw as Map<String, dynamic>;
        final place = _extractEmbeddedMap(row[tPlaces]);
        if (place == null) continue;

        final placeId = (place['google_place_id'] ?? '').toString();
        if (placeId.isEmpty) continue;

        final placeName = (place['name'] ?? '').toString();
        final plat = (place['latitude'] as num?)?.toDouble();
        final plng = (place['longitude'] as num?)?.toDouble();
        if (plat == null || plng == null) continue;
        if (_distanceMeters(centerLat, centerLng, plat, plng) > radiusMeters) {
          continue;
        }

        final caption = (row['caption'] ?? '').toString();
        if (q.isNotEmpty &&
            !placeName.toLowerCase().contains(q) &&
            !caption.toLowerCase().contains(q)) {
          continue;
        }

        final author =
            _extractEmbeddedMap(row[SupabaseTables.profiles]) ??
            _extractEmbeddedMap(row['whoeats_users']);
        final userName = (author?['name'] ?? '').toString().trim();
        final avatarToken = _avatarToken(userName);
        final postUserId = (row['user_id'] ?? '').toString();
        final isFriendPost =
            mutualFriendIds.isNotEmpty && mutualFriendIds.contains(postUserId);
        final rating = (row['rating'] as num?)?.toDouble();

        final imageUrl = await _firstImageUrl(row[tImages]);
        final agg = aggregates.putIfAbsent(
          placeId,
          () => _PlacePinAggregate(
            googlePlaceId: placeId,
            placeName: placeName,
            latitude: plat,
            longitude: plng,
          ),
        );
        agg.addPost(
          caption: caption,
          imageUrl: imageUrl,
          avatarToken: avatarToken,
          isFriendPost: isFriendPost,
          rating: rating,
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
      final name = (placeRow['name'] ?? '').toString();
      final lat = (placeRow['latitude'] as num?)?.toDouble();
      final lng = (placeRow['longitude'] as num?)?.toDouble();
      final lead = posts.isNotEmpty
          ? posts.first.comment
          : '友達の投稿はまだありません';

      return PlaceDetail(
        placeId: placeGoogleId,
        placeName: name,
        rating: 0,
        friendComment: lead,
        imageUrl: posts.isNotEmpty ? (posts.first.imageUrl ?? '') : '',
        posts: posts,
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

  String _avatarToken(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final runes = trimmed.runes;
    if (runes.isEmpty) return '?';
    return String.fromCharCode(runes.first).toUpperCase();
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
  final List<String> _captions = [];
  final List<String> _imageUrls = [];
  final List<String> _friendAvatarTokens = [];
  final List<double> _ratings = [];
  bool _hasFriendPost = false;

  void addPost({
    required String caption,
    required String imageUrl,
    required String avatarToken,
    required bool isFriendPost,
    double? rating,
  }) {
    if (caption.isNotEmpty) _captions.add(caption);
    if (imageUrl.isNotEmpty) _imageUrls.add(imageUrl);
    if (isFriendPost) {
      _hasFriendPost = true;
      if (!_friendAvatarTokens.contains(avatarToken)) {
        _friendAvatarTokens.add(avatarToken);
      }
    }
    if (rating != null && rating > 0) _ratings.add(rating);
  }

  MapPin toMapPin() {
    final comment = _captions.isNotEmpty
        ? _captions.first
        : (_friendAvatarTokens.length > 1
              ? '${_friendAvatarTokens.length}人の友達が訪問'
              : '投稿あり');
    final avgRating = _ratings.isEmpty
        ? 0.0
        : _ratings.reduce((a, b) => a + b) / _ratings.length;
    return MapPin(
      id: googlePlaceId,
      placeName: placeName,
      rating: avgRating > 0 ? avgRating : 0,
      friendComment: comment,
      imageUrl: _imageUrls.isNotEmpty ? _imageUrls.first : '',
      isFriendVisited: _hasFriendPost,
      friendAvatars: _friendAvatarTokens.take(4).toList(),
      latitude: latitude,
      longitude: longitude,
    );
  }
}
