import 'dart:async';

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
    required UpdatePostCaptionUseCase updatePostCaptionUseCase,
    required GetPostsForDayUseCase getPostsForDayUseCase,
    required GetFeedPostByIdUseCase getFeedPostByIdUseCase,
    required GetUserPublicProfileUseCase getUserPublicProfileUseCase,
    required BlockUserUseCase blockUserUseCase,
    required UnblockUserUseCase unblockUserUseCase,
    required ReportUserUseCase reportUserUseCase,
    required ReportPostUseCase reportPostUseCase,
    required GetPendingMealTagsUseCase getPendingMealTagsUseCase,
    required GetRecordSummaryUseCase getRecordSummaryUseCase,
    required GetProfileOverviewUseCase getProfileOverviewUseCase,
    required GetProfilePostThumbsUseCase getProfilePostThumbsUseCase,
    required GetFavoritePostsUseCase getFavoritePostsUseCase,
    required SetProfilePostPinnedUseCase setProfilePostPinnedUseCase,
    required TogglePostFavoriteUseCase togglePostFavoriteUseCase,
    required GetNotificationsUseCase getNotificationsUseCase,
    required MarkAllNotificationsReadUseCase markAllNotificationsReadUseCase,
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
       _updatePostCaptionUseCase = updatePostCaptionUseCase,
       _getPostsForDayUseCase = getPostsForDayUseCase,
       _getFeedPostByIdUseCase = getFeedPostByIdUseCase,
       _getUserPublicProfileUseCase = getUserPublicProfileUseCase,
       _blockUserUseCase = blockUserUseCase,
       _unblockUserUseCase = unblockUserUseCase,
       _reportUserUseCase = reportUserUseCase,
       _reportPostUseCase = reportPostUseCase,
       _getPendingMealTagsUseCase = getPendingMealTagsUseCase,
       _getRecordSummaryUseCase = getRecordSummaryUseCase,
       _getProfileOverviewUseCase = getProfileOverviewUseCase,
       _getProfilePostThumbsUseCase = getProfilePostThumbsUseCase,
       _getFavoritePostsUseCase = getFavoritePostsUseCase,
       _setProfilePostPinnedUseCase = setProfilePostPinnedUseCase,
       _togglePostFavoriteUseCase = togglePostFavoriteUseCase,
       _getNotificationsUseCase = getNotificationsUseCase,
       _markAllNotificationsReadUseCase = markAllNotificationsReadUseCase,
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
  final UpdatePostCaptionUseCase _updatePostCaptionUseCase;
  final GetPostsForDayUseCase _getPostsForDayUseCase;
  final GetFeedPostByIdUseCase _getFeedPostByIdUseCase;
  final GetUserPublicProfileUseCase _getUserPublicProfileUseCase;
  final BlockUserUseCase _blockUserUseCase;
  final UnblockUserUseCase _unblockUserUseCase;
  final ReportUserUseCase _reportUserUseCase;
  final ReportPostUseCase _reportPostUseCase;
  final GetPendingMealTagsUseCase _getPendingMealTagsUseCase;
  final GetRecordSummaryUseCase _getRecordSummaryUseCase;
  final GetProfileOverviewUseCase _getProfileOverviewUseCase;
  final GetProfilePostThumbsUseCase _getProfilePostThumbsUseCase;
  final GetFavoritePostsUseCase _getFavoritePostsUseCase;
  final SetProfilePostPinnedUseCase _setProfilePostPinnedUseCase;
  final TogglePostFavoriteUseCase _togglePostFavoriteUseCase;
  final GetNotificationsUseCase _getNotificationsUseCase;
  final MarkAllNotificationsReadUseCase _markAllNotificationsReadUseCase;
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
  bool mapPinsLoaded = false;
  bool mapPinsLoading = false;
  String? mapPinsLoadError;
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
  DeviceLocationAccessStatus mapLocationAccessStatus =
      DeviceLocationAccessStatus.denied;

  bool get hasMapLocationAccess =>
      deviceLatitude != null && deviceLongitude != null;
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

  int get unreadNotificationCount =>
      notifications.where((notification) => !notification.isRead).length;

  Future<List<FeedPost>> loadFavoritePosts() => _getFavoritePostsUseCase();

  Future<List<ProfilePostThumb>> loadProfilePostThumbs({
    required bool pinnedOnly,
  }) => _getProfilePostThumbsUseCase(pinnedOnly: pinnedOnly);

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
    final profileName = (profileOverview?.name ?? '').trim();
    final displayComment = profileName.isEmpty
        ? comment
        : PostComment(
            id: comment.id,
            userId: comment.userId,
            userName: profileName,
            body: comment.body,
            createdAt: comment.createdAt,
            userIconUrl: comment.userIconUrl ??
                profileOverview?.avatarUrl.trim(),
            isMine: comment.isMine,
          );
    final post = feedPostById(postId);
    if (post != null) {
      _replacePostInFeed(
        post.copyWith(
          comments: post.comments + 1,
          setLatestComment: true,
          latestComment: displayComment,
        ),
      );
      notifyListeners();
    }
    return displayComment;
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

  Future<FeedPost> updatePostCaption(FeedPost post, String caption) async {
    final normalized = caption.trim();
    await _updatePostCaptionUseCase(post.id, normalized);
    final updated = post.copyWith(caption: normalized);
    _replacePostInFeed(updated);
    notifyListeners();
    return updated;
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
    mapPins = [];
    mapPinsLoaded = false;
    mapPinsLoading = false;
    mapPinsLoadError = null;
    postedPlaceGoogleIds = <String>{};
    postedPlaceUserIcons = <String, String>{};
    notifyListeners();
    final deviceLocFuture = resolveDeviceLocationAccess(requestIfNeeded: false);
    await loadFeedScopePreference();
    final access = await deviceLocFuture;
    mapLocationAccessStatus = access.status;
    final loc = access.location;
    if (loc != null) {
      deviceLatitude = loc.lat;
      deviceLongitude = loc.lng;
    }
    feed = await _getHomeFeedUseCase(scope: feedTimelineScope);
    loading = false;
    _log('initialize done feed=${feed.length}');
    notifyListeners();

    if (deviceLatitude != null && deviceLongitude != null) {
      _log('device location lat=$deviceLatitude lng=$deviceLongitude');
    } else {
      _log('device location unavailable');
    }

    unawaited(ensureMapPinsLoaded());
    unawaited(_loadSecondaryData());
  }

  /// 地図タブ表示に必要な位置情報を確認・取得する。
  Future<bool> ensureMapLocationAccess({bool requestIfNeeded = true}) async {
    if (hasMapLocationAccess) {
      mapLocationAccessStatus = DeviceLocationAccessStatus.granted;
      return true;
    }
    final access = await resolveDeviceLocationAccess(
      requestIfNeeded: requestIfNeeded,
    );
    mapLocationAccessStatus = access.status;
    final loc = access.location;
    if (loc != null) {
      deviceLatitude = loc.lat;
      deviceLongitude = loc.lng;
      notifyListeners();
      return true;
    }
    notifyListeners();
    return false;
  }

  Future<void> markAllNotificationsRead() async {
    if (notifications.isEmpty || unreadNotificationCount == 0) return;
    await _markAllNotificationsReadUseCase();
    notifications = [
      for (final notification in notifications)
        notification.isRead ? notification : notification.copyWith(isRead: true),
    ];
    notifyListeners();
  }

  void changeBottomIndex(int index) {
    bottomIndex = index;
    notifyListeners();
  }

  /// 地図タブへ切り替え、指定店舗のピンへカメラを移動する。
  /// 位置情報が許可されていない場合は false。
  Future<bool> focusMapOnPlace(
    String placeGoogleId, {
    required String placeName,
  }) async {
    final granted = await ensureMapLocationAccess();
    if (!granted) return false;
    pendingMapPlaceFocus = MapPlaceFocus(
      placeGoogleId: placeGoogleId,
      placeName: placeName,
    );
    changeBottomIndex(1);
    return true;
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
      mapLocationAccessStatus = DeviceLocationAccessStatus.granted;
      return DeviceLatLng(lat: deviceLatitude!, lng: deviceLongitude!);
    }
    final granted = await ensureMapLocationAccess();
    if (!granted) return null;
    return DeviceLatLng(lat: deviceLatitude!, lng: deviceLongitude!);
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

  Future<void> invalidateMapPins() async {
    mapPinsLoaded = false;
    mapPinsLoading = false;
    mapPins = [];
    postedPlaceGoogleIds = {};
    postedPlaceUserIcons = {};
    notifyListeners();
  }

  Future<void> filterMapPins(String keyword) async {
    _log('filterMapPins keyword=$keyword');
    mapPins = await _searchMapPinsUseCase(keyword);
    mapPinsLoaded = true;
    mapPinsLoadError = null;
    _log('filterMapPins result=${mapPins.length}');
    notifyListeners();
  }

  Future<void> refreshMapPinsForViewport({
    required double lat,
    required double lng,
    required int radiusMeters,
    required double zoom,
    String? keyword,
    double? boundsMinLat,
    double? boundsMaxLat,
    double? boundsMinLng,
    double? boundsMaxLng,
  }) async {
    _log(
      'refreshMapPinsForViewport lat=$lat lng=$lng radius=$radiusMeters '
      'zoom=$zoom keyword=${keyword ?? ''}',
    );
    mapPins = await _searchMapPinsAroundUseCase(
      lat: lat,
      lng: lng,
      radiusMeters: radiusMeters,
      keyword: keyword,
      boundsMinLat: boundsMinLat,
      boundsMaxLat: boundsMaxLat,
      boundsMinLng: boundsMinLng,
      boundsMaxLng: boundsMaxLng,
      zoom: zoom,
    );
    mapPinsLoaded = true;
    mapPinsLoadError = null;
    postedPlaceGoogleIds = {
      ...mapPins.where((p) => p.hasPostedActivity).map((p) => p.id),
    };
    postedPlaceUserIcons = {
      for (final pin in mapPins)
        if (pin.mapPinIconUrl != null && pin.mapPinIconUrl!.isNotEmpty)
          pin.id: pin.mapPinIconUrl!,
    };
    _log('refreshMapPinsForViewport result=${mapPins.length}');
    notifyListeners();
  }

  Future<void> ensureMapPinsLoaded() async {
    if (mapPinsLoaded || mapPinsLoading) return;
    mapPinsLoading = true;
    mapPinsLoadError = null;
    notifyListeners();
    try {
      mapPins = await _getMapPinsUseCase(
        centerLat: deviceLatitude,
        centerLng: deviceLongitude,
      );
      postedPlaceGoogleIds = {
        ...mapPins.where((p) => p.hasPostedActivity).map((p) => p.id),
      };
      postedPlaceUserIcons = {
        for (final pin in mapPins)
          if (pin.mapPinIconUrl != null && pin.mapPinIconUrl!.isNotEmpty)
            pin.id: pin.mapPinIconUrl!,
      };
      mapPinsLoaded = true;
      _log('ensureMapPinsLoaded result=${mapPins.length}');
    } catch (e, st) {
      mapPinsLoadError = '$e';
      debugPrint('AppShellController.ensureMapPinsLoaded failed: $e\n$st');
    } finally {
      mapPinsLoading = false;
      notifyListeners();
    }
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

  Future<void> _loadSecondaryData() async {
    try {
      final results = await Future.wait([
        refreshFriendLists(),
        _getRecordSummaryUseCase(),
        _getProfileOverviewUseCase(),
        _getNotificationsUseCase(),
        _getPendingMealTagsUseCase(),
      ]);
      recordSummary = results[1] as RecordSummary;
      profileOverview = results[2] as ProfileOverview;
      notifications = results[3] as List<AppNotification>;
      pendingMealTags = results[4] as List<PendingMealTag>;
      notifyListeners();
    } catch (e, st) {
      debugPrint('AppShellController._loadSecondaryData failed: $e\n$st');
    }
  }

  FriendCandidate? socialStateForUser(String userId) {
    for (final c in friends) {
      if (c.id == userId) return c;
    }
    for (final c in incomingFriendRequests) {
      if (c.id == userId) return c;
    }
    for (final c in outgoingPendingFollows) {
      if (c.id == userId) return c;
    }
    for (final c in friendRecommendations) {
      if (c.id == userId) return c;
    }
    return null;
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

  Future<void> reportUser(String targetUserId, String reason) async {
    await _reportUserUseCase(targetUserId, reason);
  }

  Future<void> reportPost(String postId, String reason) async {
    await _reportPostUseCase(postId, reason);
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('[AppShellController] $message');
  }
}
