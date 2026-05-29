import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/location/device_location.dart';
import '../../application/feed_preferences_store.dart';
import '../../domain/entities/app_entities.dart';
import '../../domain/usecases/dashboard_usecases.dart';

class AppShellController extends ChangeNotifier {
  AppShellController({
    required GetHomeFeedUseCase getHomeFeedUseCase,
    required GetMapPinsUseCase getMapPinsUseCase,
    required GetFriendsUseCase getFriendsUseCase,
    required GetFriendRecommendationsUseCase getFriendRecommendationsUseCase,
    required GetIncomingFriendRequestsUseCase getIncomingFriendRequestsUseCase,
    required GetOutgoingPendingFollowsUseCase getOutgoingPendingFollowsUseCase,
    required FollowUserUseCase followUserUseCase,
    required UnfollowUserUseCase unfollowUserUseCase,
    required TogglePostLikeUseCase togglePostLikeUseCase,
    required GetPostCommentsUseCase getPostCommentsUseCase,
    required CreatePostCommentUseCase createPostCommentUseCase,
    required DeletePostCommentUseCase deletePostCommentUseCase,
    required SearchUsersByCodeUseCase searchUsersByCodeUseCase,
    required SoftDeletePostUseCase softDeletePostUseCase,
    required GetPostsForDayUseCase getPostsForDayUseCase,
    required GetFeedPostByIdUseCase getFeedPostByIdUseCase,
    required GetUserPublicProfileUseCase getUserPublicProfileUseCase,
    required BlockUserUseCase blockUserUseCase,
    required UnblockUserUseCase unblockUserUseCase,
    required GetPendingMealTagsUseCase getPendingMealTagsUseCase,
    required GetRecordSummaryUseCase getRecordSummaryUseCase,
    required GetProfileOverviewUseCase getProfileOverviewUseCase,
    required GetFavoritePostsUseCase getFavoritePostsUseCase,
    required SetProfilePostPinnedUseCase setProfilePostPinnedUseCase,
    required TogglePostFavoriteUseCase togglePostFavoriteUseCase,
    required GetNotificationsUseCase getNotificationsUseCase,
    required CreatePostDraftUseCase createPostDraftUseCase,
    required GetPlaceDetailUseCase getPlaceDetailUseCase,
    required SearchMapPinsUseCase searchMapPinsUseCase,
    required SearchMapPinsAroundUseCase searchMapPinsAroundUseCase,
    required AutocompletePlacesUseCase autocompletePlacesUseCase,
    required ResolvePlacePinFromCoordinateUseCase resolvePlacePinFromCoordinateUseCase,
  }) : _getHomeFeedUseCase = getHomeFeedUseCase,
       _getMapPinsUseCase = getMapPinsUseCase,
       _getFriendsUseCase = getFriendsUseCase,
       _getFriendRecommendationsUseCase = getFriendRecommendationsUseCase,
       _getIncomingFriendRequestsUseCase = getIncomingFriendRequestsUseCase,
       _getOutgoingPendingFollowsUseCase = getOutgoingPendingFollowsUseCase,
       _followUserUseCase = followUserUseCase,
       _unfollowUserUseCase = unfollowUserUseCase,
       _togglePostLikeUseCase = togglePostLikeUseCase,
       _getPostCommentsUseCase = getPostCommentsUseCase,
       _createPostCommentUseCase = createPostCommentUseCase,
       _deletePostCommentUseCase = deletePostCommentUseCase,
       _searchUsersByCodeUseCase = searchUsersByCodeUseCase,
       _softDeletePostUseCase = softDeletePostUseCase,
       _getPostsForDayUseCase = getPostsForDayUseCase,
       _getFeedPostByIdUseCase = getFeedPostByIdUseCase,
       _getUserPublicProfileUseCase = getUserPublicProfileUseCase,
       _blockUserUseCase = blockUserUseCase,
       _unblockUserUseCase = unblockUserUseCase,
       _getPendingMealTagsUseCase = getPendingMealTagsUseCase,
       _getRecordSummaryUseCase = getRecordSummaryUseCase,
       _getProfileOverviewUseCase = getProfileOverviewUseCase,
       _getFavoritePostsUseCase = getFavoritePostsUseCase,
       _setProfilePostPinnedUseCase = setProfilePostPinnedUseCase,
       _togglePostFavoriteUseCase = togglePostFavoriteUseCase,
       _getNotificationsUseCase = getNotificationsUseCase,
       _createPostDraftUseCase = createPostDraftUseCase,
       _getPlaceDetailUseCase = getPlaceDetailUseCase,
       _searchMapPinsUseCase = searchMapPinsUseCase,
       _searchMapPinsAroundUseCase = searchMapPinsAroundUseCase,
       _autocompletePlacesUseCase = autocompletePlacesUseCase,
       _resolvePlacePinFromCoordinateUseCase = resolvePlacePinFromCoordinateUseCase;

  final GetHomeFeedUseCase _getHomeFeedUseCase;
  final GetMapPinsUseCase _getMapPinsUseCase;
  final GetFriendsUseCase _getFriendsUseCase;
  final GetFriendRecommendationsUseCase _getFriendRecommendationsUseCase;
  final GetIncomingFriendRequestsUseCase _getIncomingFriendRequestsUseCase;
  final GetOutgoingPendingFollowsUseCase _getOutgoingPendingFollowsUseCase;
  final FollowUserUseCase _followUserUseCase;
  final UnfollowUserUseCase _unfollowUserUseCase;
  final TogglePostLikeUseCase _togglePostLikeUseCase;
  final GetPostCommentsUseCase _getPostCommentsUseCase;
  final CreatePostCommentUseCase _createPostCommentUseCase;
  final DeletePostCommentUseCase _deletePostCommentUseCase;
  final SearchUsersByCodeUseCase _searchUsersByCodeUseCase;
  final SoftDeletePostUseCase _softDeletePostUseCase;
  final GetPostsForDayUseCase _getPostsForDayUseCase;
  final GetFeedPostByIdUseCase _getFeedPostByIdUseCase;
  final GetUserPublicProfileUseCase _getUserPublicProfileUseCase;
  final BlockUserUseCase _blockUserUseCase;
  final UnblockUserUseCase _unblockUserUseCase;
  final GetPendingMealTagsUseCase _getPendingMealTagsUseCase;
  final GetRecordSummaryUseCase _getRecordSummaryUseCase;
  final GetProfileOverviewUseCase _getProfileOverviewUseCase;
  final GetFavoritePostsUseCase _getFavoritePostsUseCase;
  final SetProfilePostPinnedUseCase _setProfilePostPinnedUseCase;
  final TogglePostFavoriteUseCase _togglePostFavoriteUseCase;
  final GetNotificationsUseCase _getNotificationsUseCase;
  final CreatePostDraftUseCase _createPostDraftUseCase;
  final GetPlaceDetailUseCase _getPlaceDetailUseCase;
  final SearchMapPinsUseCase _searchMapPinsUseCase;
  final SearchMapPinsAroundUseCase _searchMapPinsAroundUseCase;
  final AutocompletePlacesUseCase _autocompletePlacesUseCase;
  final ResolvePlacePinFromCoordinateUseCase _resolvePlacePinFromCoordinateUseCase;

  int bottomIndex = 0;
  int homeTabIndex = 0;
  bool loading = true;
  FeedTimelineScope feedTimelineScope = FeedTimelineScope.friends;

  List<FeedPost> feed = [];
  List<MapPin> mapPins = [];
  List<FriendCandidate> friends = [];
  List<FriendCandidate> incomingFriendRequests = [];
  List<FriendCandidate> outgoingPendingFollows = [];
  List<FriendCandidate> friendRecommendations = [];
  List<FriendCandidate> userCodeSearchResults = [];
  RecordSummary? recordSummary;
  ProfileOverview? profileOverview;
  List<AppNotification> notifications = [];
  PostDraft? postDraft;
  PostDraft? pendingPostDraft;
  List<PendingMealTag> pendingMealTags = [];
  List<PlaceSuggestion> placeSuggestions = [];
  Set<String> postedPlaceGoogleIds = <String>{};
  Map<String, String> postedPlaceUserIcons = <String, String>{};
  double? deviceLatitude;
  double? deviceLongitude;
  MapPlaceFocus? pendingMapPlaceFocus;

  String? get currentUserId {
    if (!AppConfig.hasSupabase) return null;
    return Supabase.instance.client.auth.currentUser?.id;
  }

  FeedPost? feedPostById(String postId) {
    for (final p in feed) {
      if (p.id == postId) return p;
    }
    return null;
  }

  Future<void> refreshProfileOverview() async {
    profileOverview = await _getProfileOverviewUseCase();
    notifyListeners();
  }

  Future<List<FeedPost>> loadFavoritePosts() => _getFavoritePostsUseCase();

  Future<FeedPost> togglePostFavoriteForPost(FeedPost post) async {
    final favorited = await _togglePostFavoriteUseCase(post.id);
    final updated = post.copyWith(isFavoritedByMe: favorited);
    _replacePostInFeed(updated);
    notifyListeners();
    return updated;
  }

  Future<FeedPost> setProfilePinForPost(FeedPost post, bool pin) async {
    await _setProfilePostPinnedUseCase(post.id, pin);
    final updated = post.copyWith(isPinnedOnMyProfile: pin);
    _replacePostInFeed(updated);
    await refreshProfileOverview();
    return updated;
  }

  Future<FeedPost> togglePostLikeForPost(FeedPost post) async {
    final liked = await _togglePostLikeUseCase(post.id);
    final delta = liked ? 1 : -1;
    final updated = post.copyWith(
      likedByMe: liked,
      likes: (post.likes + delta).clamp(0, 1 << 30),
    );
    _replacePostInFeed(updated);
    notifyListeners();
    return updated;
  }

  void _replacePostInFeed(FeedPost updated) {
    feed = [
      for (final p in feed)
        if (p.id == updated.id) updated else p,
    ];
  }

  Future<List<PostComment>> loadPostComments(String postId) =>
      _getPostCommentsUseCase(postId);

  Future<PostComment> addPostComment(String postId, String body) async {
    final comment = await _createPostCommentUseCase(postId, body);
    final post = feedPostById(postId);
    if (post != null) {
      _replacePostInFeed(
        post.copyWith(
          comments: post.comments + 1,
          setLatestComment: true,
          latestComment: comment,
        ),
      );
      notifyListeners();
    }
    return comment;
  }

  Future<void> removePostComment(
    String postId,
    String commentId, {
    PostComment? nextLatestComment,
    int? remainingCount,
  }) async {
    await _deletePostCommentUseCase(commentId);
    final post = feedPostById(postId);
    if (post != null) {
      final count = remainingCount ?? (post.comments - 1).clamp(0, 1 << 30);
      _replacePostInFeed(
        post.copyWith(
          comments: count,
          setLatestComment: true,
          latestComment: count > 0 ? nextLatestComment : null,
        ),
      );
      notifyListeners();
    }
  }

  Future<void> deletePost(String postId) async {
    await _softDeletePostUseCase(postId);
    feed = feed.where((p) => p.id != postId).toList();
    await refreshProfileOverview();
    notifyListeners();
  }

  Future<List<RecordDayEntry>> loadPostsForDay(DateTime dayLocal) =>
      _getPostsForDayUseCase(dayLocal);

  Future<FeedPost?> loadFeedPostById(String postId) =>
      _getFeedPostByIdUseCase(postId);

  Future<UserPublicProfile?> loadUserPublicProfile(String userId) =>
      _getUserPublicProfileUseCase(userId);

  Future<void> searchUsersByCode(String query) async {
    userCodeSearchResults = await _searchUsersByCodeUseCase(query);
    notifyListeners();
  }

  void clearUserCodeSearch() {
    if (userCodeSearchResults.isEmpty) return;
    userCodeSearchResults = [];
    notifyListeners();
  }

  Future<void> refreshPendingMealTags() async {
    pendingMealTags = await _getPendingMealTagsUseCase();
    notifyListeners();
  }

  void setPendingPostDraft(PostDraft? draft) {
    pendingPostDraft = draft;
    notifyListeners();
  }

  void clearPendingPostDraft() {
    if (pendingPostDraft == null) return;
    pendingPostDraft = null;
    notifyListeners();
  }

  Future<void> loadFeedScopePreference() async {
    final uid = currentUserId;
    if (uid == null) return;
    feedTimelineScope = await FeedPreferencesStore.loadDefaultScope(uid);
    notifyListeners();
  }

  Future<void> setFeedTimelineScope(FeedTimelineScope scope) async {
    if (feedTimelineScope == scope) return;
    feedTimelineScope = scope;
    final uid = currentUserId;
    if (uid != null) {
      await FeedPreferencesStore.saveDefaultScope(uid, scope);
    }
    await refreshFeed();
  }

  Future<void> setDefaultFeedTimelineScope(FeedTimelineScope scope) async {
    final uid = currentUserId;
    if (uid == null) return;
    await FeedPreferencesStore.saveDefaultScope(uid, scope);
    if (feedTimelineScope != scope) {
      feedTimelineScope = scope;
      await refreshFeed();
    } else {
      notifyListeners();
    }
  }

  Future<void> refreshFeed() async {
    feed = await _getHomeFeedUseCase(scope: feedTimelineScope);
    notifyListeners();
  }

  Future<void> initialize() async {
    _log('initialize start');
    loading = true;
    notifyListeners();
    final deviceLocFuture = readDeviceLatLng();
    final loc = await deviceLocFuture;
    if (loc != null) {
      deviceLatitude = loc.lat;
      deviceLongitude = loc.lng;
    }
    await loadFeedScopePreference();
    feed = await _getHomeFeedUseCase(scope: feedTimelineScope);
    mapPins = await _getMapPinsUseCase(
      centerLat: deviceLatitude,
      centerLng: deviceLongitude,
    );
    await refreshFriendLists();
    recordSummary = await _getRecordSummaryUseCase();
    profileOverview = await _getProfileOverviewUseCase();
    notifications = await _getNotificationsUseCase();
    pendingMealTags = await _getPendingMealTagsUseCase();
    postedPlaceGoogleIds = {
      ...feed
          .map((p) => p.placeGoogleId)
          .whereType<String>()
          .where((v) => v.isNotEmpty),
      ...mapPins.where((p) => p.isFriendVisited).map((p) => p.id),
    };
    postedPlaceUserIcons = {
      for (final p in feed)
        if ((p.placeGoogleId ?? '').isNotEmpty &&
            (p.userIconUrl ?? '').isNotEmpty)
          p.placeGoogleId!: p.userIconUrl!,
    };
    if (deviceLatitude != null && deviceLongitude != null) {
      _log('device location lat=$deviceLatitude lng=$deviceLongitude');
    } else {
      _log('device location unavailable');
    }
    loading = false;
    _log('initialize done feed=${feed.length} pins=${mapPins.length}');
    notifyListeners();
  }

  void changeBottomIndex(int index) {
    bottomIndex = index;
    notifyListeners();
  }

  /// 地図タブへ切り替え、指定店舗のピンへカメラを移動する。
  void focusMapOnPlace(String placeGoogleId, {required String placeName}) {
    pendingMapPlaceFocus = MapPlaceFocus(
      placeGoogleId: placeGoogleId,
      placeName: placeName,
    );
    changeBottomIndex(1);
  }

  void clearPendingMapPlaceFocus() {
    if (pendingMapPlaceFocus == null) return;
    pendingMapPlaceFocus = null;
  }

  void changeHomeTab(int index) {
    homeTabIndex = index;
    notifyListeners();
  }

  Future<void> openCameraFlow() async {
    postDraft = await _createPostDraftUseCase();
    notifyListeners();
  }

  Future<DeviceLatLng?> ensureDeviceLocation() async {
    if (deviceLatitude != null && deviceLongitude != null) {
      return DeviceLatLng(lat: deviceLatitude!, lng: deviceLongitude!);
    }
    final loc = await readDeviceLatLng();
    if (loc != null) {
      deviceLatitude = loc.lat;
      deviceLongitude = loc.lng;
      notifyListeners();
    }
    return loc;
  }

  void setPostDraft(PostDraft draft) {
    postDraft = draft;
    notifyListeners();
  }

  void clearPostDraft() {
    if (postDraft == null) return;
    postDraft = null;
    notifyListeners();
  }

  Future<PlaceDetail> getPlaceDetail(String placeId) {
    _log('getPlaceDetail placeId=$placeId');
    return _getPlaceDetailUseCase(placeId);
  }

  Future<void> filterMapPins(String keyword) async {
    _log('filterMapPins keyword=$keyword');
    mapPins = await _searchMapPinsUseCase(keyword);
    _log('filterMapPins result=${mapPins.length}');
    notifyListeners();
  }

  Future<void> refreshMapPinsForViewport({
    required double lat,
    required double lng,
    required int radiusMeters,
    String? keyword,
  }) async {
    _log(
      'refreshMapPinsForViewport lat=$lat lng=$lng radius=$radiusMeters keyword=${keyword ?? ''}',
    );
    mapPins = await _searchMapPinsAroundUseCase(
      lat: lat,
      lng: lng,
      radiusMeters: radiusMeters,
      keyword: keyword,
    );
    postedPlaceGoogleIds = {
      ...postedPlaceGoogleIds,
      ...mapPins.where((p) => p.isFriendVisited).map((p) => p.id),
    };
    _log('refreshMapPinsForViewport result=${mapPins.length}');
    notifyListeners();
  }

  Future<void> searchPlaceSuggestions(String query) async {
    _log('searchPlaceSuggestions query="$query"');
    placeSuggestions = await _autocompletePlacesUseCase(
      query,
      biasLat: deviceLatitude,
      biasLng: deviceLongitude,
    );
    _log('searchPlaceSuggestions result=${placeSuggestions.length}');
    notifyListeners();
  }

  void clearPlaceSuggestions() {
    if (placeSuggestions.isEmpty) return;
    placeSuggestions = [];
    notifyListeners();
  }

  Future<MapPin?> resolvePlacePinFromCoordinate(double lat, double lng) {
    _log('resolveFromCoord lat=$lat lng=$lng');
    return _resolvePlacePinFromCoordinateUseCase(lat, lng);
  }

  Future<void> refreshFriendLists() async {
    friends = await _getFriendsUseCase();
    incomingFriendRequests = await _getIncomingFriendRequestsUseCase();
    outgoingPendingFollows = await _getOutgoingPendingFollowsUseCase();
    friendRecommendations = await _getFriendRecommendationsUseCase();
    notifyListeners();
  }

  Future<bool> followUser(String targetUserId) async {
    final becameFriend = await _followUserUseCase(targetUserId);
    await refreshFriendLists();
    return becameFriend;
  }

  Future<void> unfollowUser(String targetUserId) async {
    await _unfollowUserUseCase(targetUserId);
    await refreshFriendLists();
  }

  Future<void> blockUser(String targetUserId) async {
    await _blockUserUseCase(targetUserId);
    feed = feed.where((p) => p.userId != targetUserId).toList();
    await refreshFriendLists();
    notifyListeners();
  }

  Future<void> unblockUser(String targetUserId) async {
    await _unblockUserUseCase(targetUserId);
    notifyListeners();
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('[AppShellController] $message');
  }
}
