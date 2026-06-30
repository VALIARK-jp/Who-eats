import 'dart:convert';

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
      return _rowsToMapPins(
        rows: rows,
        keyword: keyword,
        mutualFriendIds: mutualFriendIds,
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[SupabaseMapPinsDataSource] fetchPostedPinsAround: $e\n$st');
      }
      return const [];
    }
  }

  /// 画面 bbox 内の訪問投稿ピン（日本全土ズームアウト時など）。
  Future<List<MapPin>> fetchPostedPinsInBounds({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    String? keyword,
    Set<String> mutualFriendIds = const {},
    int limit = 500,
  }) async {
    if (_client.auth.currentUser == null) return const [];

    try {
      final rows = await _client.rpc(
        'get_restaurant_post_activity_in_bbox',
        params: {
          'p_min_lat': minLat,
          'p_max_lat': maxLat,
          'p_min_lng': minLng,
          'p_max_lng': maxLng,
          'p_limit': limit,
        },
      );
      return _rowsToMapPins(
        rows: rows,
        keyword: keyword,
        mutualFriendIds: mutualFriendIds,
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[SupabaseMapPinsDataSource] fetchPostedPinsInBounds: $e\n$st');
      }
      return const [];
    }
  }

  Future<List<MapPin>> _rowsToMapPins({
    required dynamic rows,
    String? keyword,
    required Set<String> mutualFriendIds,
  }) async {
    final currentUserId = _client.auth.currentUser!.id;
    final aggregates = <String, _PlacePinAggregate>{};
    final q = (keyword ?? '').trim().toLowerCase();
    final iconPaths = <String>{};
    final parsedRows = <_ActivityRow>[];

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
      final iconPath = (row['icon_path'] ?? '').toString().trim();
      if (iconPath.isNotEmpty) iconPaths.add(iconPath);

      parsedRows.add(
        _ActivityRow(
          placeId: placeId,
          placeName: placeName,
          latitude: plat,
          longitude: plng,
          userId: userId,
          userName: userName,
          iconPath: iconPath,
          isFriend: mutualFriendIds.contains(userId),
          isMe: userId == currentUserId,
        ),
      );
    }

    final signedUrls = await _signIconPaths(iconPaths);

    for (final parsed in parsedRows) {
      final avatarUrl = parsed.iconPath.isEmpty
          ? null
          : signedUrls[parsed.iconPath];
      final agg = aggregates.putIfAbsent(
        parsed.placeId,
        () => _PlacePinAggregate(
          googlePlaceId: parsed.placeId,
          placeName: parsed.placeName,
          latitude: parsed.latitude,
          longitude: parsed.longitude,
        ),
      );
      agg.addVisitor(
        userId: parsed.userId,
        userName: parsed.userName.isNotEmpty ? parsed.userName : 'user',
        isFriend: parsed.isFriend,
        avatarUrl: avatarUrl,
        isMe: parsed.isMe,
      );
    }

    return aggregates.values.map((a) => a.toMapPin()).toList();
  }

  Future<Map<String, String>> _signIconPaths(Set<String> iconPaths) async {
    if (iconPaths.isEmpty) return const {};
    final signed = <String, String>{};
    await Future.wait(
      iconPaths.map((path) async {
        final url = await SupabaseStorageUrls.resolveProfileIconUrl(_client, path);
        if (url != null && url.isNotEmpty) {
          signed[path] = url;
        }
      }),
    );
    return signed;
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
      final iconPaths = <String>{};
      final parsedRows = <({String userId, String userName, String iconPath})>[];

      for (final raw in (rows as List<dynamic>)) {
        final row = raw as Map<String, dynamic>;
        final userId = (row['user_id'] ?? '').toString();
        if (userId.isEmpty) continue;
        final userName = (row['user_name'] ?? '').toString().trim();
        final iconPath = (row['icon_path'] ?? '').toString().trim();
        if (iconPath.isNotEmpty) iconPaths.add(iconPath);
        parsedRows.add((userId: userId, userName: userName, iconPath: iconPath));
      }

      final signedUrls = await _signIconPaths(iconPaths);
      final seen = <String>{};
      final visitors = <PlaceVisitor>[];
      for (final parsed in parsedRows) {
        if (seen.contains(parsed.userId)) continue;
        seen.add(parsed.userId);
        final avatarUrl = parsed.iconPath.isEmpty
            ? null
            : signedUrls[parsed.iconPath];
        visitors.add(
          PlaceVisitor(
            userId: parsed.userId,
            userName: parsed.userName.isNotEmpty ? parsed.userName : 'user',
            isFriend: mutualFriendIds.contains(parsed.userId),
            avatarUrl: avatarUrl,
            isMe: parsed.userId == currentUserId,
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

  Future<List<CityChoroplethMetric>> fetchCityChoroplethMetricsNationwide() async {
    if (_client.auth.currentUser == null) return const [];
    try {
      final raw = await _client.rpc('whoeats_map_choropleth_nationwide');
      final rows = _parseChoroplethRpcRows(raw);
      if (kDebugMode) {
        debugPrint(
          '[SupabaseMapPinsDataSource] choropleth nationwide rows=${rows.length}',
        );
      }
      return _rowsToChoroplethMetrics(rows);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint(
          '[SupabaseMapPinsDataSource] fetchCityChoroplethMetricsNationwide: $e\n$st',
        );
      }
      return const [];
    }
  }

  Future<List<CityChoroplethMetric>> fetchCityChoroplethMetrics(
    String prefectureCode,
  ) async {
    if (_client.auth.currentUser == null) return const [];
    final code = prefectureCode.padLeft(2, '0');
    try {
      final raw = await _client.rpc(
        'whoeats_map_choropleth_prefecture',
        params: {'p_prefecture_code': code},
      );
      final rows = _parseChoroplethRpcRows(raw);
      if (kDebugMode) {
        debugPrint(
          '[SupabaseMapPinsDataSource] choropleth pref=$code rows=${rows.length}',
        );
      }
      return _rowsToChoroplethMetrics(rows);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint(
          '[SupabaseMapPinsDataSource] fetchCityChoroplethMetrics: $e\n$st',
        );
      }
      return const [];
    }
  }

  List<CityChoroplethMetric> _rowsToChoroplethMetrics(
    List<Map<String, dynamic>> rows,
  ) {
    return rows
        .map((city) {
          return CityChoroplethMetric(
            cityCode: city['city_code'].toString(),
            cityName: (city['city_name'] ?? '').toString(),
            hasMine: _readBool(city['has_mine']),
            hasFriend: _readBool(city['has_friend']),
            hasOther: _readBool(city['has_other']),
          );
        })
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _parseChoroplethRpcRows(dynamic raw) {
    if (raw is List) {
      return raw
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(growable: false);
    }
    if (raw is String) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList(growable: false);
      }
      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        final legacy = map['cities'];
        if (legacy is List) {
          return legacy
              .map((row) => Map<String, dynamic>.from(row as Map))
              .toList(growable: false);
        }
      }
    }
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final legacy = map['cities'];
      if (legacy is List) {
        return legacy
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList(growable: false);
      }
    }
    if (kDebugMode) {
      debugPrint(
        '[SupabaseMapPinsDataSource] choropleth unexpected type: '
        '${raw.runtimeType}',
      );
    }
    return const [];
  }

  bool _readBool(dynamic value) {
    if (value == true) return true;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == 't' || normalized == '1';
    }
    return value == 1;
  }
}

class _ActivityRow {
  const _ActivityRow({
    required this.placeId,
    required this.placeName,
    required this.latitude,
    required this.longitude,
    required this.userId,
    required this.userName,
    required this.iconPath,
    required this.isFriend,
    required this.isMe,
  });

  final String placeId;
  final String placeName;
  final double latitude;
  final double longitude;
  final String userId;
  final String userName;
  final String iconPath;
  final bool isFriend;
  final bool isMe;
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
    required String? avatarUrl,
    required bool isMe,
  }) {
    if (_visitors.any((v) => v.userId == userId)) return;
    _visitors.add(
      PlaceVisitor(
        userId: userId,
        userName: userName,
        isFriend: isFriend,
        avatarUrl: avatarUrl,
        isMe: isMe,
      ),
    );
    if (isFriend) _hasFriendPost = true;
  }

  String? _mapPinIconUrl() {
    for (final visitor in _visitors) {
      if (visitor.isFriend) {
        final url = visitor.avatarUrl?.trim();
        if (url != null && url.isNotEmpty) return url;
      }
    }
    for (final visitor in _visitors) {
      if (visitor.isMe) {
        final url = visitor.avatarUrl?.trim();
        if (url != null && url.isNotEmpty) return url;
      }
    }
    return null;
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
      hasPostedActivity: _visitors.isNotEmpty,
      visitors: List<PlaceVisitor>.unmodifiable(_visitors),
      mapPinIconUrl: _mapPinIconUrl(),
      latitude: latitude,
      longitude: longitude,
    );
  }
}
