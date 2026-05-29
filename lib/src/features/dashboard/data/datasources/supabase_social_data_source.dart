import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_storage_urls.dart';
import '../../../../core/supabase/supabase_tables.dart';
import '../../domain/entities/app_entities.dart';

/// Friends, profile, feed, notifications, record summary from Supabase.
class SupabaseSocialDataSource {
  SupabaseSocialDataSource({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String? get _uid => _client.auth.currentUser?.id;

  Future<Set<String>> fetchMutualFriendIds() async {
    if (_uid == null) return {};
    try {
      final rows = await _client.rpc('get_my_friends');
      final ids = <String>{};
      for (final raw in (rows as List<dynamic>)) {
        final row = raw as Map<String, dynamic>;
        final id = (row['user_id'] ?? '').toString();
        if (id.isNotEmpty) ids.add(id);
      }
      return ids;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[SupabaseSocialDataSource] fetchMutualFriendIds: $e\n$st');
      }
      return {};
    }
  }

  Future<List<FriendCandidate>> fetchFriends() async {
    if (_uid == null) return const [];
    try {
      final rows = await _client.rpc('get_my_friends');
      final list = <FriendCandidate>[];
      for (final raw in (rows as List<dynamic>)) {
        final row = raw as Map<String, dynamic>;
        final id = (row['user_id'] ?? '').toString();
        if (id.isEmpty) continue;
        final name = (row['name'] ?? '').toString().trim();
        final iconPath = (row['icon_path'] ?? '').toString();
        final avatarUrl =
            await SupabaseStorageUrls.signedPostImage(_client, iconPath) ?? '';
        list.add(
          FriendCandidate(
            id: id,
            name: name.isNotEmpty ? name : 'ユーザー',
            avatarUrl: avatarUrl,
            mutualCount: 0,
            isFriend: true,
          ),
        );
      }
      return list;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[SupabaseSocialDataSource] fetchFriends: $e\n$st');
      }
      return const [];
    }
  }

  Future<List<FriendCandidate>> fetchFriendRecommendations() async {
    if (_uid == null) return const [];
    try {
      final rows = await _client.rpc('get_friend_recommendations', params: {
        'p_limit': 50,
      });
      return _rowsToCandidates(
        rows,
        theyFollowMe: false,
        iFollowThem: false,
        includeMutualCount: true,
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint(
          '[SupabaseSocialDataSource] fetchFriendRecommendations: $e\n$st',
        );
      }
      return const [];
    }
  }

  /// 相手が自分をフォロー済み。フォロー返しで相互フォロー（友達）になる。
  Future<List<FriendCandidate>> fetchIncomingFriendRequests() async {
    if (_uid == null) return const [];
    try {
      final rows = await _client.rpc('get_incoming_friend_requests');
      return _rowsToCandidates(rows, theyFollowMe: true, iFollowThem: false);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint(
          '[SupabaseSocialDataSource] fetchIncomingFriendRequests: $e\n$st',
        );
      }
      return const [];
    }
  }

  /// 自分がフォロー済みだが相手のフォロー返し待ち。
  Future<List<FriendCandidate>> fetchOutgoingPendingFollows() async {
    if (_uid == null) return const [];
    try {
      final rows = await _client.rpc('get_outgoing_pending_follows');
      return _rowsToCandidates(rows, theyFollowMe: false, iFollowThem: true);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint(
          '[SupabaseSocialDataSource] fetchOutgoingPendingFollows: $e\n$st',
        );
      }
      return const [];
    }
  }

  /// フォローする。戻り値 true = 操作後に相互フォロー（友達）になった。
  Future<bool> followUser(String targetUserId) async {
    final uid = _uid;
    if (uid == null || targetUserId.isEmpty || targetUserId == uid) {
      return false;
    }
    try {
      await _client.from(SupabaseTables.follows).insert({
        'follower_id': uid,
        'following_id': targetUserId,
      });
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow;
    }
    final mutual = await fetchMutualFriendIds();
    return mutual.contains(targetUserId);
  }

  Future<List<FriendCandidate>> _rowsToCandidates(
    dynamic rows, {
    required bool theyFollowMe,
    required bool iFollowThem,
    bool includeMutualCount = false,
  }) async {
    final list = <FriendCandidate>[];
    for (final raw in (rows as List<dynamic>)) {
      final row = raw as Map<String, dynamic>;
      final id = (row['user_id'] ?? '').toString();
      if (id.isEmpty) continue;
      final name = (row['name'] ?? '').toString().trim();
      final iconPath = (row['icon_path'] ?? '').toString();
      final avatarUrl =
          await SupabaseStorageUrls.signedPostImage(_client, iconPath) ?? '';
      list.add(
        FriendCandidate(
          id: id,
          name: name.isNotEmpty ? name : 'ユーザー',
          avatarUrl: avatarUrl,
          mutualCount: includeMutualCount
              ? (row['mutual_count'] as num?)?.toInt() ?? 0
              : 0,
          isFriend: false,
          theyFollowMe: theyFollowMe,
          iFollowThem: iFollowThem,
        ),
      );
    }
    return list;
  }

  Future<List<FeedPost>> fetchHomeFeed() async {
    try {
      final tAuthor = SupabaseTables.postAuthorEmbed;
      final tPlaces = SupabaseTables.places;
      final tImages = SupabaseTables.postImages;
      var query = _client
          .from(SupabaseTables.posts)
          .select('''
            id,caption,created_at,post_type,user_id,
            $tAuthor(name,icon_path,email),
            $tPlaces(name,google_place_id),
            $tImages(storage_path,display_order)
          ''')
          .isFilter('deleted_at', null);

      if (_uid == null) {
        query = query.eq('visibility', 'public');
      }

      final rows = await query
          .order('created_at', ascending: false)
          .limit(50);
      final postIds = <String>[];
      final rawRows = <Map<String, dynamic>>[];
      for (final raw in (rows as List<dynamic>)) {
        final row = raw as Map<String, dynamic>;
        rawRows.add(row);
        postIds.add(row['id'].toString());
      }

      final reactionCounts = await _countByPostId(
        SupabaseTables.postReactions,
        postIds,
      );
      final commentCounts = await _countByPostId(
        SupabaseTables.postComments,
        postIds,
        deletedFilter: true,
      );

      final friendIds = await fetchMutualFriendIds();
      final list = <FeedPost>[];
      for (final row in rawRows) {
        final postId = row['id'].toString();
        final post = await _feedPostFromRow(
          row,
          likes: reactionCounts[postId] ?? 0,
          comments: commentCounts[postId] ?? 0,
          friendIds: friendIds,
        );
        if (post != null) list.add(post);
      }
      return list;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[SupabaseSocialDataSource] fetchHomeFeed: $e\n$st');
      }
      return const [];
    }
  }

  Future<Map<String, int>> _countByPostId(
    String table,
    List<String> postIds, {
    bool deletedFilter = false,
  }) async {
    if (postIds.isEmpty) return {};
    try {
      var query = _client.from(table).select('post_id').inFilter('post_id', postIds);
      if (deletedFilter) {
        query = query.isFilter('deleted_at', null);
      }
      final rows = await query;
      final counts = <String, int>{};
      for (final raw in (rows as List<dynamic>)) {
        final row = raw as Map<String, dynamic>;
        final pid = (row['post_id'] ?? '').toString();
        if (pid.isEmpty) continue;
        counts[pid] = (counts[pid] ?? 0) + 1;
      }
      return counts;
    } catch (_) {
      return {};
    }
  }

  Future<FeedPost?> _feedPostFromRow(
    Map<String, dynamic> row, {
    required int likes,
    required int comments,
    required Set<String> friendIds,
  }) async {
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
    final imageUrl = await SupabaseStorageUrls.signedPostImage(
      _client,
      storagePath,
    );
    if (imageUrl == null || imageUrl.isEmpty) return null;

    final author =
        _extractEmbedded(row[SupabaseTables.profiles]) ??
        _extractEmbedded(row['whoeats_users']);
    final displayName = (author?['name'] ?? '').toString().trim();
    final email = (author?['email'] ?? '').toString();
    final userName = displayName.isNotEmpty
        ? displayName
        : (email.isNotEmpty ? email.split('@').first : 'user');

    final iconPath = (author?['icon_path'] ?? '').toString();
    final userIconUrl = await SupabaseStorageUrls.signedPostImage(
      _client,
      iconPath,
    );

    final place =
        _extractEmbedded(row[SupabaseTables.places]) ??
        _extractEmbedded(row['places']);
    final postType = (row['post_type'] ?? 'restaurant').toString();
    final placeName = place != null
        ? (place['name'] ?? '不明な店舗').toString()
        : (postType == 'home' ? 'ホーム' : '不明な店舗');

    final postUserId = (row['user_id'] ?? '').toString();
    final friendAvatars = <String>[];
    if (friendIds.contains(postUserId)) {
      friendAvatars.add(_avatarToken(userName));
    }

    return FeedPost(
      id: row['id'].toString(),
      userName: userName,
      userIconUrl: userIconUrl,
      placeName: placeName,
      placeGoogleId: (place?['google_place_id'] ?? '').toString(),
      caption: (row['caption'] ?? '').toString(),
      imageUrl: imageUrl,
      likes: likes,
      comments: comments,
      friendAvatars: friendAvatars,
    );
  }

  Future<ProfileOverview> fetchProfileOverview() async {
    const empty = ProfileOverview(
      name: 'ゲスト',
      userCode: '',
      bio: '',
      avatarUrl: '',
      friendCount: 0,
      pinnedShots: [],
      recentShots: [],
    );

    final uid = _uid;
    if (uid == null) return empty;

    try {
      final row = await _client
          .from(SupabaseTables.profiles)
          .select('name, user_code, bio, icon_path')
          .eq('id', uid)
          .maybeSingle();

      final friends = await fetchFriends();
      final shots = await _fetchMyPostImageUrls(uid, limit: 12);

      if (row == null) {
        return ProfileOverview(
          name: 'ユーザー',
          userCode: '',
          bio: '',
          avatarUrl: '',
          friendCount: friends.length,
          pinnedShots: shots.take(3).toList(),
          recentShots: shots,
        );
      }

      final name = (row['name'] ?? '').toString().trim();
      final userCode = (row['user_code'] ?? '').toString().trim();
      final bio = (row['bio'] ?? '').toString().trim();
      final iconPath = (row['icon_path'] ?? '').toString();
      final avatarUrl =
          await SupabaseStorageUrls.signedPostImage(_client, iconPath) ?? '';

      return ProfileOverview(
        name: name.isNotEmpty ? name : 'ユーザー',
        userCode: userCode,
        bio: bio,
        avatarUrl: avatarUrl,
        friendCount: friends.length,
        pinnedShots: shots.take(3).toList(),
        recentShots: shots,
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[SupabaseSocialDataSource] fetchProfileOverview: $e\n$st');
      }
      return empty;
    }
  }

  Future<List<String>> _fetchMyPostImageUrls(String uid, {int limit = 12}) async {
    try {
      final tImages = SupabaseTables.postImages;
      final rows = await _client
          .from(SupabaseTables.posts)
          .select('id, $tImages(storage_path, display_order)')
          .eq('user_id', uid)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false)
          .limit(limit);

      final urls = <String>[];
      for (final raw in (rows as List<dynamic>)) {
        final row = raw as Map<String, dynamic>;
        final images = (row[tImages] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        if (images.isEmpty) continue;
        images.sort(
          (a, b) => ((a['display_order'] as num?) ?? 0).compareTo(
            ((b['display_order'] as num?) ?? 0),
          ),
        );
        final path = (images.first['storage_path'] ?? '').toString();
        final url = await SupabaseStorageUrls.signedPostImage(_client, path);
        if (url != null && url.isNotEmpty) urls.add(url);
      }
      return urls;
    } catch (_) {
      return const [];
    }
  }

  Future<RecordSummary> fetchRecordSummary() async {
    final uid = _uid;
    if (uid == null) {
      return const RecordSummary(
        streakDays: 0,
        caloriesAvg: 0,
        proteinAvg: 0,
        aiSuggestion: 'ログインすると記録が表示されます',
        monthlyShots: [],
      );
    }

    try {
      final userRow = await _client
          .from(SupabaseTables.profiles)
          .select('streak_days')
          .eq('id', uid)
          .maybeSingle();
      final streak = (userRow?['streak_days'] as num?)?.toInt() ?? 0;

      final now = DateTime.now().toUtc();
      final monthStart = DateTime.utc(now.year, now.month, 1);
      final rows = await _client
          .from(SupabaseTables.posts)
          .select('created_at')
          .eq('user_id', uid)
          .isFilter('deleted_at', null)
          .gte('created_at', monthStart.toIso8601String())
          .order('created_at', ascending: false);

      final days = <String>{};
      for (final raw in (rows as List<dynamic>)) {
        final row = raw as Map<String, dynamic>;
        final created = DateTime.tryParse((row['created_at'] ?? '').toString());
        if (created == null) continue;
        days.add('${created.toLocal().day}');
      }

      final postCount = (rows as List).length;
      final suggestion = postCount > 0
          ? '今月 $postCount 件のごはんを記録しています。'
          : '今月はまだ投稿がありません。写真から記録を始めましょう。';

      return RecordSummary(
        streakDays: streak,
        caloriesAvg: 0,
        proteinAvg: 0,
        aiSuggestion: suggestion,
        monthlyShots: days.toList()..sort((a, b) => int.parse(a).compareTo(int.parse(b))),
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[SupabaseSocialDataSource] fetchRecordSummary: $e\n$st');
      }
      return const RecordSummary(
        streakDays: 0,
        caloriesAvg: 0,
        proteinAvg: 0,
        aiSuggestion: '記録を読み込めませんでした',
        monthlyShots: [],
      );
    }
  }

  Future<List<AppNotification>> fetchNotifications() async {
    if (_uid == null) return const [];
    try {
      final rows = await _client.rpc(
        'list_inbox_notifications',
        params: {'p_limit': 50},
      );
      final list = <AppNotification>[];
      for (final raw in (rows as List<dynamic>)) {
        final row = raw as Map<String, dynamic>;
        list.add(
          AppNotification(
            id: (row['id'] ?? '').toString(),
            message: (row['message'] ?? '').toString(),
          ),
        );
      }
      return list;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[SupabaseSocialDataSource] fetchNotifications: $e\n$st');
      }
      return const [];
    }
  }

  Map<String, dynamic>? _extractEmbedded(dynamic raw) {
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
}
