import '../entities/app_entities.dart';

abstract interface class DashboardRepository {
  Future<List<FeedPost>> getHomeFeed();
  Future<List<MapPin>> getMapPins({double? centerLat, double? centerLng});
  Future<List<MapPin>> searchMapPins(String keyword);
  Future<List<MapPin>> searchMapPinsAround({
    required double lat,
    required double lng,
    required int radiusMeters,
    String? keyword,
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
  Future<RecordSummary> getRecordSummary();
  Future<ProfileOverview> getProfileOverview();
  Future<List<FeedPost>> getFavoritePosts();
  Future<void> setProfilePostPinned(String postId, bool pin);
  Future<bool> togglePostFavorite(String postId);
  Future<List<AppNotification>> getNotifications();
  Future<PostDraft> createPostDraft();
}
