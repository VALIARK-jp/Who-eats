import '../entities/app_entities.dart';

typedef HomeFeedPartialListener = void Function(List<FeedPost> posts);
typedef MapPinsPartialListener = void Function(List<MapPin> pins);

abstract interface class DashboardRepository {
  Future<List<FeedPost>> getHomeFeed({
    FeedTimelineScope scope = FeedTimelineScope.all,
    HomeFeedPartialListener? onPartial,
  });
  Future<List<MapPin>> getMapPins({
    double? centerLat,
    double? centerLng,
    MapPinsPartialListener? onPartial,
  });
  Future<List<MapPin>> searchMapPins(String keyword);
  Future<List<MapPin>> searchMapPinsAround({
    required double lat,
    required double lng,
    required int radiusMeters,
    String? keyword,
    double? boundsMinLat,
    double? boundsMaxLat,
    double? boundsMinLng,
    double? boundsMaxLng,
    double zoom = 14,
    MapPinsPartialListener? onPartial,
  });
  Future<MapPin?> resolvePlacePinFromCoordinate(double lat, double lng);
  Future<PlaceDetail> getPlaceDetail(String placeId);
  Future<List<PlaceSuggestion>> autocompletePlaces(
    String query, {
    double? biasLat,
    double? biasLng,
  });
  /// 相互フォロー済みの友達一覧。
  Future<List<FriendCandidate>> getFriends();

  /// まだ友達でないおすすめ候補（共通友達数付き）。
  Future<List<FriendCandidate>> getFriendRecommendations();

  /// 相手からフォローされていて、フォロー返しで友達になれる一覧。
  Future<List<FriendCandidate>> getIncomingFriendRequests();

  /// 自分がフォロー済みで、相手のフォロー返し待ち一覧。
  Future<List<FriendCandidate>> getOutgoingPendingFollows();

  /// フォローする。戻り値 true = この操作で相互フォロー（友達）になった。
  Future<bool> followUser(String targetUserId);

  Future<void> unfollowUser(String targetUserId);
  Future<bool> togglePostLike(String postId);
  Future<List<PostComment>> getPostComments(String postId);
  Future<PostComment> createPostComment(String postId, String body);
  Future<void> deletePostComment(String commentId);
  Future<List<FriendCandidate>> searchUsersByCode(String query);
  Future<void> softDeletePost(String postId);
  Future<void> updatePostCaption(String postId, String caption);
  Future<void> updatePostDetails(
    String postId, {
    required String caption,
    required int rating,
    int? priceYen,
  });
  Future<List<RecordDayEntry>> getPostsForDay(DateTime dayLocal);
  Future<FeedPost?> getFeedPostById(String postId);
  Future<UserPublicProfile?> getUserPublicProfile(String userId);
  Future<void> blockUser(String userId);
  Future<void> unblockUser(String userId);
  Future<void> reportUser(String userId, String reason);
  Future<void> reportPost(String postId, String reason);
  Future<List<PendingMealTag>> getPendingMealTags();

  Future<RecordSummary> getRecordSummary();
  Future<ProfileOverview> getProfileOverview();
  Future<List<ProfilePostThumb>> getProfilePostThumbs({
    required bool pinnedOnly,
  });
  Future<List<FeedPost>> getFavoritePosts();
  Future<void> setProfilePostPinned(String postId, bool pin);
  Future<bool> togglePostFavorite(String postId);
  Future<List<AppNotification>> getNotifications();
  Future<void> markAllNotificationsRead();
  Future<PostDraft> createPostDraft();
  Future<List<CityChoroplethMetric>> getCityChoroplethMetrics(
    String prefectureCode,
  );
  Future<List<CityChoroplethMetric>> getCityChoroplethMetricsNationwide();
}
