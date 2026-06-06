import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/push/push_notification_service.dart';
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
      final rows = await _client.rpc(
        'get_friend_recommendations',
        params: {'p_limit': 50},
      );
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
    var created = false;
    try {
      await _client.from(SupabaseTables.follows).insert({
        'follower_id': uid,
        'following_id': targetUserId,
      });
      created = true;
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow;
    }
    final mutual = await fetchMutualFriendIds();
    if (created) {
      unawaited(
        PushNotificationService.instance.sendEvent(
          targetUserId: targetUserId,
          eventType: mutual.contains(targetUserId)
              ? 'friend_accepted'
              : 'friend_request',
        ),
      );
    }
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

  Future<List<FeedPost>> fetchHomeFeed({
    FeedTimelineScope scope = FeedTimelineScope.all,
  }) async {
    try {
      final tAuthor = SupabaseTables.postAuthorEmbed;
      final tPlaces = SupabaseTables.places;
      final tImages = SupabaseTables.postImages;
      var query = _client
          .from(SupabaseTables.posts)
          .select('''
            id,caption,created_at,post_type,rating,user_id,
            $tAuthor(name,icon_path,email),
            $tPlaces(name,google_place_id),
            $tImages(storage_path,display_order)
          ''')
          .isFilter('deleted_at', null);

      if (_uid == null) {
        query = query.eq('visibility', 'public');
      }

      final rows = await query.order('created_at', ascending: false).limit(80);
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
      final nearIds = scope == FeedTimelineScope.near
          ? await _fetchNearFeedUserIds()
          : <String>{};
      final favoriteIds = await _fetchMyFavoritePostIds();
      final pinnedIds = await _fetchMyPinnedPostIds();
      final likedIds = await _fetchMyLikedPostIds(postIds);
      final companionsByPost = await _fetchCompanionAvatarsByPost(postIds);
      final latestComments = await _fetchLatestCommentsByPostIds(postIds);

      final uid = _uid;
      final list = <FeedPost>[];
      for (final row in rawRows) {
        final postUserId = (row['user_id'] ?? '').toString();
        if (uid != null && scope == FeedTimelineScope.friends) {
          if (postUserId != uid && !friendIds.contains(postUserId)) continue;
        } else if (uid != null && scope == FeedTimelineScope.near) {
          final allowed =
              nearIds.contains(postUserId) ||
              friendIds.contains(postUserId) ||
              postUserId == uid;
          if (!allowed) continue;
        }

        final postId = row['id'].toString();
        final post = await _feedPostFromRow(
          row,
          likes: reactionCounts[postId] ?? 0,
          comments: commentCounts[postId] ?? 0,
          friendIds: friendIds,
          isFavoritedByMe: favoriteIds.contains(postId),
          isPinnedOnMyProfile: pinnedIds.contains(postId),
          likedByMe: likedIds.contains(postId),
          companionAvatars: companionsByPost[postId] ?? const [],
          latestComment: latestComments[postId],
        );
        if (post != null) list.add(post);
        if (list.length >= 50) break;
      }
      return list;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[SupabaseSocialDataSource] fetchHomeFeed: $e\n$st');
      }
      return const [];
    }
  }

  Future<void> updatePostCaption(String postId, String caption) async {
    final uid = _uid;
    if (uid == null || postId.isEmpty) return;
    await _client
        .from(SupabaseTables.posts)
        .update({'caption': caption.trim()})
        .eq('id', postId)
        .eq('user_id', uid);
  }

  Future<Map<String, int>> _countByPostId(
    String table,
    List<String> postIds, {
    bool deletedFilter = false,
  }) async {
    if (postIds.isEmpty) return {};
    try {
      var query = _client
          .from(table)
          .select('post_id')
          .inFilter('post_id', postIds);
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

  Future<Set<String>> _fetchMyFavoritePostIds() async {
    final uid = _uid;
    if (uid == null) return {};
    try {
      final rows = await _client
          .from(SupabaseTables.postFavorites)
          .select('post_id')
          .eq('user_id', uid);
      return (rows as List<dynamic>)
          .map((r) => (r as Map<String, dynamic>)['post_id'].toString())
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (_) {
      return {};
    }
  }

  Future<Set<String>> _fetchMyPinnedPostIds() async {
    final uid = _uid;
    if (uid == null) return {};
    try {
      final rows = await _client
          .from(SupabaseTables.profilePins)
          .select('post_id')
          .eq('user_id', uid);
      return (rows as List<dynamic>)
          .map((r) => (r as Map<String, dynamic>)['post_id'].toString())
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (_) {
      return {};
    }
  }

  Future<Set<String>> _fetchMyLikedPostIds(List<String> postIds) async {
    final uid = _uid;
    if (uid == null || postIds.isEmpty) return {};
    try {
      final rows = await _client
          .from(SupabaseTables.postReactions)
          .select('post_id')
          .eq('user_id', uid)
          .inFilter('post_id', postIds);
      return (rows as List<dynamic>)
          .map((r) => (r as Map<String, dynamic>)['post_id'].toString())
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (_) {
      return {};
    }
  }

  Future<Set<String>> _fetchNearFeedUserIds() async {
    if (_uid == null) return {};
    try {
      final rows = await _client.rpc('get_near_feed_user_ids');
      return (rows as List<dynamic>)
          .map((id) => id.toString())
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, List<String>>> _fetchCompanionAvatarsByPost(
    List<String> postIds,
  ) async {
    if (postIds.isEmpty) return {};
    try {
      final tUser =
          '${SupabaseTables.profiles}!whoeats_post_companions_user_fk';
      final rows = await _client
          .from(SupabaseTables.postCompanions)
          .select('post_id, $tUser(name, icon_path)')
          .inFilter('post_id', postIds);
      final map = <String, List<String>>{};
      for (final raw in (rows as List<dynamic>)) {
        final row = raw as Map<String, dynamic>;
        final postId = (row['post_id'] ?? '').toString();
        if (postId.isEmpty) continue;
        final user =
            _extractEmbedded(row[SupabaseTables.profiles]) ??
            _extractEmbedded(row['whoeats_users']);
        final name = (user?['name'] ?? '').toString().trim();
        final token = _avatarToken(name.isNotEmpty ? name : '?');
        map.putIfAbsent(postId, () => []).add(token);
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, PostComment>> _fetchLatestCommentsByPostIds(
    List<String> postIds,
  ) async {
    if (postIds.isEmpty) return {};
    final uid = _uid;
    try {
      final tAuthor =
          '${SupabaseTables.profiles}!whoeats_post_comments_user_fk';
      final rows = await _client
          .from(SupabaseTables.postComments)
          .select('id, post_id, body, created_at, user_id, $tAuthor(name)')
          .inFilter('post_id', postIds)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false);
      final map = <String, PostComment>{};
      for (final raw in (rows as List<dynamic>)) {
        final row = raw as Map<String, dynamic>;
        final postId = (row['post_id'] ?? '').toString();
        if (postId.isEmpty || map.containsKey(postId)) continue;
        final author = _extractCommentAuthor(row);
        final userId = (row['user_id'] ?? '').toString();
        final name = (author?['name'] ?? '').toString().trim();
        map[postId] = PostComment(
          id: row['id'].toString(),
          userId: userId,
          userName: name.isNotEmpty ? name : 'ユーザー',
          body: (row['body'] ?? '').toString(),
          createdAt:
              DateTime.tryParse((row['created_at'] ?? '').toString()) ??
              DateTime.now(),
          isMine: uid != null && userId == uid,
        );
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  Future<bool> togglePostLike(String postId) async {
    final uid = _uid;
    if (uid == null) throw StateError('Not signed in');
    final existing = await _client
        .from(SupabaseTables.postReactions)
        .select('post_id')
        .eq('post_id', postId)
        .eq('user_id', uid)
        .maybeSingle();
    if (existing != null) {
      await _client
          .from(SupabaseTables.postReactions)
          .delete()
          .eq('post_id', postId)
          .eq('user_id', uid);
      return false;
    }
    await _client.from(SupabaseTables.postReactions).insert({
      'post_id': postId,
      'user_id': uid,
    });
    final ownerId = await _getPostOwnerId(postId);
    if (ownerId != null && ownerId != uid) {
      unawaited(
        PushNotificationService.instance.sendEvent(
          targetUserId: ownerId,
          eventType: 'like',
          postId: postId,
        ),
      );
    }
    return true;
  }

  Future<List<PostComment>> fetchPostComments(String postId) async {
    final uid = _uid;
    try {
      final tAuthor =
          '${SupabaseTables.profiles}!whoeats_post_comments_user_fk';
      final rows = await _client
          .from(SupabaseTables.postComments)
          .select('id, body, created_at, user_id, $tAuthor(name)')
          .eq('post_id', postId)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: true);
      final list = <PostComment>[];
      for (final raw in (rows as List<dynamic>)) {
        final row = raw as Map<String, dynamic>;
        final author = _extractCommentAuthor(row);
        final userId = (row['user_id'] ?? '').toString();
        final name = (author?['name'] ?? '').toString().trim();
        list.add(
          PostComment(
            id: row['id'].toString(),
            userId: userId,
            userName: name.isNotEmpty ? name : 'ユーザー',
            body: (row['body'] ?? '').toString(),
            createdAt:
                DateTime.tryParse((row['created_at'] ?? '').toString()) ??
                DateTime.now(),
            isMine: uid != null && userId == uid,
          ),
        );
      }
      return list;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[SupabaseSocialDataSource] fetchPostComments: $e\n$st');
      }
      return const [];
    }
  }

  Future<PostComment> createPostComment(String postId, String body) async {
    final uid = _uid;
    if (uid == null) throw StateError('Not signed in');
    final trimmed = body.trim();
    if (trimmed.isEmpty) throw ArgumentError('empty comment');
    final row = await _client
        .from(SupabaseTables.postComments)
        .insert({'post_id': postId, 'user_id': uid, 'body': trimmed})
        .select('id, body, created_at, user_id')
        .single();
    final ownerId = await _getPostOwnerId(postId);
    if (ownerId != null && ownerId != uid) {
      unawaited(
        PushNotificationService.instance.sendEvent(
          targetUserId: ownerId,
          eventType: 'comment',
          postId: postId,
        ),
      );
    }
    return PostComment(
      id: row['id'].toString(),
      userId: uid,
      userName: '自分',
      body: trimmed,
      createdAt:
          DateTime.tryParse((row['created_at'] ?? '').toString()) ??
          DateTime.now(),
      isMine: true,
    );
  }

  Future<void> deletePostComment(String commentId) async {
    if (_uid == null) throw StateError('Not signed in');
    await _client
        .from(SupabaseTables.postComments)
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', commentId)
        .eq('user_id', _uid!);
  }

  Future<void> unfollowUser(String targetUserId) async {
    final uid = _uid;
    if (uid == null || targetUserId.isEmpty) return;
    await _client
        .from(SupabaseTables.follows)
        .delete()
        .eq('follower_id', uid)
        .eq('following_id', targetUserId);
  }

  Future<List<FriendCandidate>> searchUsersByCode(String query) async {
    if (_uid == null) return const [];
    final q = query.trim();
    if (q.length < 2) return const [];
    try {
      final rows = await _client.rpc(
        'search_users_by_code',
        params: {'p_query': q.startsWith('@') ? q : '@$q', 'p_limit': 20},
      );
      return _rowsToCandidates(rows, theyFollowMe: false, iFollowThem: false);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[SupabaseSocialDataSource] searchUsersByCode: $e\n$st');
      }
      return const [];
    }
  }

  Future<void> softDeletePost(String postId) async {
    if (_uid == null) throw StateError('Not signed in');
    await _client.rpc('soft_delete_post', params: {'p_post_id': postId});
  }

  Future<String?> _getPostOwnerId(String postId) async {
    if (postId.isEmpty) return null;
    try {
      final row = await _client
          .from(SupabaseTables.posts)
          .select('user_id')
          .eq('id', postId)
          .maybeSingle();
      final ownerId = (row?['user_id'] ?? '').toString();
      return ownerId.isEmpty ? null : ownerId;
    } catch (_) {
      return null;
    }
  }

  Future<List<RecordDayEntry>> fetchPostsForDay(DateTime dayLocal) async {
    final uid = _uid;
    if (uid == null) return const [];
    final start = DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
    final end = start.add(const Duration(days: 1));
    try {
      final tPlaces = SupabaseTables.places;
      final tImages = SupabaseTables.postImages;
      final rows = await _client
          .from(SupabaseTables.posts)
          .select('''
            id, caption, created_at, post_type, rating,
            $tPlaces(name, google_place_id),
            $tImages(storage_path, display_order)
          ''')
          .eq('user_id', uid)
          .isFilter('deleted_at', null)
          .gte('created_at', start.toUtc().toIso8601String())
          .lt('created_at', end.toUtc().toIso8601String())
          .order('created_at', ascending: false);
      final postIds = <String>[];
      final list = <RecordDayEntry>[];
      for (final raw in (rows as List<dynamic>)) {
        final row = raw as Map<String, dynamic>;
        postIds.add(row['id'].toString());
      }
      final companions = await _fetchCompanionNamesByPost(postIds);
      for (final raw in (rows as List<dynamic>)) {
        final row = raw as Map<String, dynamic>;
        final postId = row['id'].toString();
        final images = (row[tImages] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        if (images.isEmpty) continue;
        images.sort(
          (a, b) => ((a['display_order'] as num?) ?? 0).compareTo(
            (b['display_order'] as num?) ?? 0,
          ),
        );
        final storagePath = (images.first['storage_path'] ?? '').toString();
        final imageUrl =
            await SupabaseStorageUrls.signedPostImage(_client, storagePath) ??
            '';
        if (imageUrl.isEmpty) continue;
        final place = _extractEmbedded(row[tPlaces]);
        final postType = (row['post_type'] ?? 'restaurant').toString();
        final placeName = place != null
            ? (place['name'] ?? '不明').toString()
            : (postType == 'home' ? '自宅' : '外食');
        list.add(
          RecordDayEntry(
            postId: postId,
            placeName: placeName,
            imageUrl: imageUrl,
            postType: postType,
            companionNames: companions[postId] ?? const [],
            rating: (row['rating'] as num?)?.toInt(),
            caption: (row['caption'] ?? '').toString(),
            placeGoogleId: (place?['google_place_id'] ?? '').toString().isEmpty
                ? null
                : (place?['google_place_id'] ?? '').toString(),
            createdAt: DateTime.tryParse((row['created_at'] ?? '').toString()),
          ),
        );
      }
      return list;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[SupabaseSocialDataSource] fetchPostsForDay: $e\n$st');
      }
      return const [];
    }
  }

  Future<Map<String, List<String>>> _fetchCompanionNamesByPost(
    List<String> postIds,
  ) async {
    if (postIds.isEmpty) return {};
    try {
      final tUser =
          '${SupabaseTables.profiles}!whoeats_post_companions_user_fk';
      final rows = await _client
          .from(SupabaseTables.postCompanions)
          .select('post_id, $tUser(name)')
          .inFilter('post_id', postIds);
      final map = <String, List<String>>{};
      for (final raw in (rows as List<dynamic>)) {
        final row = raw as Map<String, dynamic>;
        final postId = (row['post_id'] ?? '').toString();
        final user = _extractEmbedded(row[SupabaseTables.profiles]);
        final name = (user?['name'] ?? '').toString().trim();
        if (postId.isEmpty || name.isEmpty) continue;
        map.putIfAbsent(postId, () => []).add(name);
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  Future<FeedPost?> fetchFeedPostById(String postId) async {
    try {
      final tAuthor = SupabaseTables.postAuthorEmbed;
      final tPlaces = SupabaseTables.places;
      final tImages = SupabaseTables.postImages;
      final row = await _client
          .from(SupabaseTables.posts)
          .select('''
            id,caption,created_at,post_type,rating,user_id,
            $tAuthor(name,icon_path,email),
            $tPlaces(name,google_place_id),
            $tImages(storage_path,display_order)
          ''')
          .eq('id', postId)
          .isFilter('deleted_at', null)
          .maybeSingle();
      if (row == null) return null;
      final friendIds = await fetchMutualFriendIds();
      final reactionCounts = await _countByPostId(
        SupabaseTables.postReactions,
        [postId],
      );
      final commentCounts = await _countByPostId(SupabaseTables.postComments, [
        postId,
      ], deletedFilter: true);
      final likedIds = await _fetchMyLikedPostIds([postId]);
      final companions = await _fetchCompanionAvatarsByPost([postId]);
      final latestComments = await _fetchLatestCommentsByPostIds([postId]);
      return _feedPostFromRow(
        row,
        likes: reactionCounts[postId] ?? 0,
        comments: commentCounts[postId] ?? 0,
        friendIds: friendIds,
        likedByMe: likedIds.contains(postId),
        companionAvatars: companions[postId] ?? const [],
        latestComment: latestComments[postId],
      );
    } catch (_) {
      return null;
    }
  }

  Future<UserPublicProfile?> fetchUserPublicProfile(String userId) async {
    final uid = _uid;
    if (uid == null || userId.isEmpty) return null;
    try {
      final row = await _client
          .from(SupabaseTables.profiles)
          .select('name, user_code, bio, icon_path')
          .eq('id', userId)
          .maybeSingle();
      if (row == null) return null;
      final friendIds = await fetchMutualFriendIds();
      final incoming = await fetchIncomingFriendRequests();
      final outgoing = await fetchOutgoingPendingFollows();
      final isFriend = friendIds.contains(userId);
      final theyFollowMe = incoming.any((c) => c.id == userId);
      final iFollowThem =
          outgoing.any((c) => c.id == userId) ||
          (await _client
                  .from(SupabaseTables.follows)
                  .select('follower_id')
                  .eq('follower_id', uid)
                  .eq('following_id', userId)
                  .maybeSingle()) !=
              null;
      final blocked = await _client
          .from(SupabaseTables.blocks)
          .select('blocker_id')
          .eq('blocker_id', uid)
          .eq('blocked_id', userId)
          .maybeSingle();
      final iconPath = (row['icon_path'] ?? '').toString();
      final avatarUrl =
          await SupabaseStorageUrls.signedPostImage(_client, iconPath) ?? '';
      final recentPosts = await _fetchProfilePostThumbs(
        userId,
        pinnedOnly: false,
      );
      return UserPublicProfile(
        userId: userId,
        name: (row['name'] ?? '').toString().trim().isNotEmpty
            ? (row['name'] ?? '').toString().trim()
            : 'ユーザー',
        userCode: (row['user_code'] ?? '').toString(),
        bio: (row['bio'] ?? '').toString(),
        avatarUrl: avatarUrl,
        isFriend: isFriend,
        iFollowThem: iFollowThem && !isFriend,
        theyFollowMe: theyFollowMe && !isFriend,
        isBlocked: blocked != null,
        recentPosts: recentPosts,
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint(
          '[SupabaseSocialDataSource] fetchUserPublicProfile: $e\n$st',
        );
      }
      return null;
    }
  }

  Future<void> blockUser(String targetUserId) async {
    final uid = _uid;
    if (uid == null || targetUserId.isEmpty) return;
    try {
      await _client.from(SupabaseTables.blocks).insert({
        'blocker_id': uid,
        'blocked_id': targetUserId,
      });
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow;
    }
  }

  Future<void> unblockUser(String targetUserId) async {
    final uid = _uid;
    if (uid == null || targetUserId.isEmpty) return;
    await _client
        .from(SupabaseTables.blocks)
        .delete()
        .eq('blocker_id', uid)
        .eq('blocked_id', targetUserId);
  }

  Future<List<PendingMealTag>> listPendingMealTags() async {
    if (_uid == null) return const [];
    try {
      final rows = await _client.rpc(
        'list_pending_meal_tags',
        params: {'p_limit': 10},
      );
      final list = <PendingMealTag>[];
      for (final raw in (rows as List<dynamic>)) {
        final row = raw as Map<String, dynamic>;
        final iconPath = (row['inviter_icon_path'] ?? '').toString();
        final iconUrl =
            await SupabaseStorageUrls.signedPostImage(_client, iconPath) ?? '';
        list.add(
          PendingMealTag(
            sourcePostId: (row['source_post_id'] ?? '').toString(),
            mealGroupId: (row['meal_group_id'] ?? '').toString(),
            inviterName: (row['inviter_name'] ?? '').toString(),
            inviterIconUrl: iconUrl,
            placeName: (row['place_name'] ?? '').toString(),
          ),
        );
      }
      return list;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[SupabaseSocialDataSource] listPendingMealTags: $e\n$st');
      }
      return const [];
    }
  }

  Future<void> setProfilePostPinned(String postId, bool pin) async {
    if (_uid == null) throw StateError('Not signed in');
    await _client.rpc(
      'set_profile_post_pinned',
      params: {'p_post_id': postId, 'p_pin': pin},
    );
  }

  Future<bool> togglePostFavorite(String postId) async {
    if (_uid == null) throw StateError('Not signed in');
    final result = await _client.rpc(
      'toggle_post_favorite',
      params: {'p_post_id': postId},
    );
    return result == true;
  }

  Future<List<FeedPost>> fetchFavoritePosts() async {
    final uid = _uid;
    if (uid == null) return const [];

    try {
      final favRows = await _client
          .from(SupabaseTables.postFavorites)
          .select('post_id, created_at')
          .eq('user_id', uid)
          .order('created_at', ascending: false);

      final orderedIds = <String>[];
      for (final raw in (favRows as List<dynamic>)) {
        final row = raw as Map<String, dynamic>;
        final id = (row['post_id'] ?? '').toString();
        if (id.isNotEmpty) orderedIds.add(id);
      }
      if (orderedIds.isEmpty) return const [];

      final tAuthor = SupabaseTables.postAuthorEmbed;
      final tPlaces = SupabaseTables.places;
      final tImages = SupabaseTables.postImages;
      final rows = await _client
          .from(SupabaseTables.posts)
          .select('''
            id,caption,created_at,post_type,user_id,
            $tAuthor(name,icon_path,email),
            $tPlaces(name,google_place_id),
            $tImages(storage_path,display_order)
          ''')
          .inFilter('id', orderedIds)
          .isFilter('deleted_at', null);

      final byId = <String, Map<String, dynamic>>{};
      for (final raw in (rows as List<dynamic>)) {
        final row = raw as Map<String, dynamic>;
        byId[row['id'].toString()] = row;
      }

      final postIds = orderedIds.where(byId.containsKey).toList();
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
      final latestComments = await _fetchLatestCommentsByPostIds(postIds);

      final list = <FeedPost>[];
      for (final id in orderedIds) {
        final row = byId[id];
        if (row == null) continue;
        final post = await _feedPostFromRow(
          row,
          likes: reactionCounts[id] ?? 0,
          comments: commentCounts[id] ?? 0,
          friendIds: friendIds,
          isFavoritedByMe: true,
          isPinnedOnMyProfile: false,
          latestComment: latestComments[id],
        );
        if (post != null) list.add(post);
      }
      return list;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[SupabaseSocialDataSource] fetchFavoritePosts: $e\n$st');
      }
      return const [];
    }
  }

  Future<FeedPost?> _feedPostFromRow(
    Map<String, dynamic> row, {
    required int likes,
    required int comments,
    required Set<String> friendIds,
    bool isFavoritedByMe = false,
    bool isPinnedOnMyProfile = false,
    bool likedByMe = false,
    List<String> companionAvatars = const [],
    PostComment? latestComment,
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
        : (postType == 'home' ? '自炊' : '不明な店舗');
    final rating = (row['rating'] as num?)?.toInt();
    final createdAt = DateTime.tryParse((row['created_at'] ?? '').toString());

    final postUserId = (row['user_id'] ?? '').toString();
    final friendAvatars = <String>[];
    if (friendIds.contains(postUserId)) {
      friendAvatars.add(_avatarToken(userName));
    }
    friendAvatars.addAll(companionAvatars);

    return FeedPost(
      id: row['id'].toString(),
      userId: postUserId,
      userName: userName,
      userIconUrl: userIconUrl,
      placeName: placeName,
      placeGoogleId: (place?['google_place_id'] ?? '').toString().isEmpty
          ? null
          : (place?['google_place_id'] ?? '').toString(),
      caption: (row['caption'] ?? '').toString(),
      imageUrl: imageUrl,
      likes: likes,
      comments: comments,
      friendAvatars: friendAvatars,
      isFavoritedByMe: isFavoritedByMe,
      isPinnedOnMyProfile: isPinnedOnMyProfile,
      likedByMe: likedByMe,
      rating: rating,
      createdAt: createdAt,
      postType: postType,
      companionAvatars: companionAvatars,
      latestComment: latestComment,
    );
  }

  Future<({int followers, int following})> _followCounts(String uid) async {
    try {
      final followersRes = await _client
          .from(SupabaseTables.follows)
          .select('follower_id')
          .eq('following_id', uid);
      final followingRes = await _client
          .from(SupabaseTables.follows)
          .select('following_id')
          .eq('follower_id', uid);
      return (
        followers: (followersRes as List<dynamic>).length,
        following: (followingRes as List<dynamic>).length,
      );
    } catch (_) {
      return (followers: 0, following: 0);
    }
  }

  Future<ProfileOverview> fetchProfileOverview() async {
    const empty = ProfileOverview(
      name: 'ゲスト',
      userCode: '',
      bio: '',
      avatarUrl: '',
      followers: 0,
      following: 0,
      friends: 0,
      pinnedPosts: [],
      recentPosts: [],
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
      final counts = await _followCounts(uid);
      final pinnedPosts = await _fetchProfilePostThumbs(uid, pinnedOnly: true);
      final recentPosts = await _fetchProfilePostThumbs(uid, pinnedOnly: false);

      if (row == null) {
        return ProfileOverview(
          name: 'ユーザー',
          userCode: '',
          bio: '',
          avatarUrl: '',
          followers: counts.followers,
          following: counts.following,
          friends: friends.length,
          pinnedPosts: pinnedPosts,
          recentPosts: recentPosts,
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
        followers: counts.followers,
        following: counts.following,
        friends: friends.length,
        pinnedPosts: pinnedPosts,
        recentPosts: recentPosts,
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[SupabaseSocialDataSource] fetchProfileOverview: $e\n$st');
      }
      return empty;
    }
  }

  Future<List<ProfilePostThumb>> fetchProfilePostThumbs({
    required bool pinnedOnly,
  }) async {
    final uid = _uid;
    if (uid == null) return const [];
    return _fetchProfilePostThumbs(uid, pinnedOnly: pinnedOnly, limit: 2000);
  }

  Future<List<ProfilePostThumb>> _fetchProfilePostThumbs(
    String uid, {
    required bool pinnedOnly,
    int limit = 24,
  }) async {
    try {
      final pinRows = await _client
          .from(SupabaseTables.profilePins)
          .select('post_id')
          .eq('user_id', uid);
      final pinnedIds = (pinRows as List<dynamic>)
          .map((r) => (r['post_id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet();

      final tImages = SupabaseTables.postImages;
      var query = _client
          .from(SupabaseTables.posts)
          .select('id, created_at, $tImages(storage_path, display_order)')
          .eq('user_id', uid)
          .isFilter('deleted_at', null);

      final rows = await query
          .order('created_at', ascending: false)
          .limit(limit * 2);

      final thumbs = <ProfilePostThumb>[];
      for (final raw in (rows as List<dynamic>)) {
        final row = raw as Map<String, dynamic>;
        final postId = row['id'].toString();
        final isPinned = pinnedIds.contains(postId);
        if (pinnedOnly && !isPinned) continue;

        final images = (row[tImages] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        if (images.isEmpty) continue;
        images.sort(
          (a, b) => ((a['display_order'] as num?) ?? 0).compareTo(
            (b['display_order'] as num?) ?? 0,
          ),
        );
        final path = (images.first['storage_path'] ?? '').toString();
        final url = await SupabaseStorageUrls.signedPostImage(_client, path);
        if (url == null || url.isEmpty) continue;
        thumbs.add(ProfilePostThumb(postId: postId, imageUrl: url));
        final cap = pinnedOnly ? 3 : limit;
        if (thumbs.length >= cap) break;
      }
      return thumbs;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint(
          '[SupabaseSocialDataSource] _fetchProfilePostThumbs: $e\n$st',
        );
      }
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
        monthlyShots: days.toList()
          ..sort((a, b) => int.parse(a).compareTo(int.parse(b))),
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
      final rows = await _client
          .from(SupabaseTables.notifications)
          .select('id,title,body,created_at,is_read')
          .eq('recipient_user_id', _uid!)
          .order('created_at', ascending: false)
          .limit(50);
      final list = <AppNotification>[];
      for (final raw in (rows as List<dynamic>)) {
        final row = raw as Map<String, dynamic>;
        list.add(
          AppNotification(
            id: (row['id'] ?? '').toString(),
            title: (row['title'] ?? '').toString(),
            body: (row['body'] ?? '').toString(),
            createdAt: row['created_at'] == null
                ? null
                : DateTime.tryParse(row['created_at'].toString()),
            isRead: row['is_read'] == true,
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

  Future<void> markAllNotificationsRead() async {
    if (_uid == null) return;
    try {
      await _client
          .from(SupabaseTables.notifications)
          .update({'is_read': true})
          .eq('recipient_user_id', _uid!)
          .eq('is_read', false);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint(
          '[SupabaseSocialDataSource] markAllNotificationsRead: $e\n$st',
        );
      }
    }
  }

  Map<String, dynamic>? _extractEmbedded(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is List && raw.isNotEmpty && raw.first is Map<String, dynamic>) {
      return raw.first as Map<String, dynamic>;
    }
    return null;
  }

  Map<String, dynamic>? _extractCommentAuthor(Map<String, dynamic> row) {
    return _extractEmbedded(row[SupabaseTables.profiles]) ??
        _extractEmbedded(row['whoeats_users']);
  }

  String _avatarToken(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final runes = trimmed.runes;
    if (runes.isEmpty) return '?';
    return String.fromCharCode(runes.first).toUpperCase();
  }
}
