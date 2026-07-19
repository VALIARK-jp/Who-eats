import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/location/device_location.dart';
import '../../../../core/supabase/place_municipality_backfill.dart';
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
    required UpdatePostDetailsUseCase updatePostDetailsUseCase,
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
    required GetCityChoroplethMetricsUseCase getCityChoroplethMetricsUseCase,
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
       _updatePostDetailsUseCase = updatePostDetailsUseCase,
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
       _getCityChoroplethMetricsUseCase = getCityChoroplethMetricsUseCase,
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
  final UpdatePostDetailsUseCase _updatePostDetailsUseCase;
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
  final GetCityChoroplethMetricsUseCase _getCityChoroplethMetricsUseCase;
  final GetPlaceDetailUseCase _getPlaceDetailUseCase;
  final SearchMapPinsUseCase _searchMapPinsUseCase;
  final SearchMapPinsAroundUseCase _searchMapPinsAroundUseCase;
  final AutocompletePlacesUseCase _autocompletePlacesUseCase;
  final ResolvePlacePinFromCoordinateUseCase _resolvePlacePinFromCoordinateUseCase;

  int bottomIndex = 0;
  int homeTabIndex = 0;
  bool loading = true;
  bool feedRefreshing = false;
  int _feedRefreshGeneration = 0;
  int _mapPinsViewportGeneration = 0;
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

  Future<FeedPost> updatePostDetails(
    FeedPost post, {
    required String caption,
    required int rating,
    int? priceYen,
  }) async {
    final normalized = caption.trim();
    final clampedRating = rating.clamp(1, 5);
    await _updatePostDetailsUseCase(
      post.id,
      caption: normalized,
      rating: clampedRating,
      priceYen: priceYen,
    );
    final updated = post.copyWith(
      caption: normalized,
      rating: clampedRating,
      setPriceYen: true,
      priceYen: priceYen,
    );
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

  void openMealTag(PendingMealTag tag) {
    setPostDraft(
      tag.toPostDraft(
        defaultVisibility: profileOverview?.defaultVisibility ?? 'friends',
      ),
    );
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

  Future<void> setFeedTimelineScope(FeedTimelineScope scope) async {
    if (feedTimelineScope == scope) return;
    feedTimelineScope = scope;
    feed = [];
    loading = true;
    feedRefreshing = true;
    notifyListeners();
    await refreshFeed();
  }

  Future<void> refreshFeed() async {
    final generation = ++_feedRefreshGeneration;
    feedRefreshing = true;
    if (feed.isEmpty) loading = true;
    notifyListeners();

    final loaded = await _getHomeFeedUseCase(
      scope: feedTimelineScope,
      onPartial: (partial) {
        if (generation != _feedRefreshGeneration) return;
        feed = partial;
        loading = false;
        feedRefreshing = true;
        notifyListeners();
      },
    );
    if (generation != _feedRefreshGeneration) return;
    feed = loaded;
    loading = false;
    feedRefreshing = false;
    notifyListeners();
  }

  Future<void> initialize() async {
    _log('initialize start');
    loading = feed.isEmpty;
    feedRefreshing = feed.isNotEmpty;
    mapPins = [];
    mapPinsLoaded = false;
    mapPinsLoading = false;
    mapPinsLoadError = null;
    postedPlaceGoogleIds = <String>{};
    postedPlaceUserIcons = <String, String>{};
    notifyListeners();

    // 位置情報の取得・地図ピンの読み込みは起動時には行わない。
    // GPS は地図タブを開いた時に初めて解決する（_MapTab 側）。フィードは位置に依存しない。
    await refreshFeed();
    _log('initialize done feed=${feed.length}');

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

  Future<Map<String, CityChoroplethMetric>> loadCityChoroplethMetrics(
    List<String> prefectureCodes,
  ) async {
    if (prefectureCodes.isEmpty) return const {};

    final List<CityChoroplethMetric> metrics;
    if (prefectureCodes.length >= 2) {
      metrics = await _getCityChoroplethMetricsUseCase.nationwide();
    } else {
      metrics = await _getCityChoroplethMetricsUseCase(prefectureCodes.single);
    }

    return {
      for (final metric in metrics)
        _normalizeCityCode(metric.cityCode): metric,
    };
  }

  static String _normalizeCityCode(String code) {
    final trimmed = code.trim();
    if (trimmed.length >= 5) return trimmed;
    return trimmed.padLeft(5, '0');
  }

  bool _municipalityBackfillStarted = false;

  /// 自分の過去投稿先で city_code 未設定の店舗を補完（マップ表示前に1回）。
  Future<void> backfillMyPlaceMunicipalitiesIfNeeded() async {
    if (_municipalityBackfillStarted || !AppConfig.hasSupabase) return;
    _municipalityBackfillStarted = true;
    final updated = await PlaceMunicipalityBackfill().backfillForCurrentUser();
    if (updated > 0) {
      _log('backfillMyPlaceMunicipalities updated=$updated');
    }
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
    final generation = ++_mapPinsViewportGeneration;
    _log(
      'refreshMapPinsForViewport lat=$lat lng=$lng radius=$radiusMeters '
      'zoom=$zoom keyword=${keyword ?? ''}',
    );
    try {
      final merged = await _searchMapPinsAroundUseCase(
        lat: lat,
        lng: lng,
        radiusMeters: radiusMeters,
        keyword: keyword,
        boundsMinLat: boundsMinLat,
        boundsMaxLat: boundsMaxLat,
        boundsMinLng: boundsMinLng,
        boundsMaxLng: boundsMaxLng,
        zoom: zoom,
        onPartial: (partial) {
          if (generation != _mapPinsViewportGeneration) return;
          _applyMapPins(partial, preservePostedIds: true);
          mapPinsLoaded = true;
          mapPinsLoadError = null;
          notifyListeners();
        },
      );
      if (generation != _mapPinsViewportGeneration) return;
      _applyMapPins(merged, preservePostedIds: true);
      mapPinsLoaded = true;
      mapPinsLoadError = null;
      _log('refreshMapPinsForViewport result=${mapPins.length}');
      notifyListeners();
    } catch (e, st) {
      if (generation != _mapPinsViewportGeneration) return;
      mapPinsLoadError = '$e';
      debugPrint('AppShellController.refreshMapPinsForViewport failed: $e\n$st');
      notifyListeners();
    }
  }

  void _applyMapPins(List<MapPin> pins, {required bool preservePostedIds}) {
    mapPins = pins;
    final previousPostedIds =
        preservePostedIds ? postedPlaceGoogleIds : const <String>{};
    postedPlaceGoogleIds = {
      for (final pin in pins)
        if (pin.hasPostedActivity || previousPostedIds.contains(pin.id))
          pin.id,
    };
    postedPlaceUserIcons = {
      if (preservePostedIds) ...postedPlaceUserIcons,
      for (final pin in pins)
        if (pin.mapPinIconUrl != null && pin.mapPinIconUrl!.isNotEmpty)
          pin.id: pin.mapPinIconUrl!,
    };
  }

  Future<void> ensureMapPinsLoaded() async {
    if (mapPinsLoaded || mapPinsLoading) return;
    mapPinsLoading = true;
    mapPinsLoadError = null;
    notifyListeners();
    try {
      final merged = await _getMapPinsUseCase(
        centerLat: deviceLatitude,
        centerLng: deviceLongitude,
        onPartial: (partial) {
          _applyMapPins(partial, preservePostedIds: false);
          mapPinsLoaded = true;
          mapPinsLoading = false;
          notifyListeners();
        },
      );
      _applyMapPins(merged, preservePostedIds: false);
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
    final results = await Future.wait([
      _getFriendsUseCase(),
      _getIncomingFriendRequestsUseCase(),
      _getOutgoingPendingFollowsUseCase(),
      _getFriendRecommendationsUseCase(),
    ]);
    friends = results[0] as List<FriendCandidate>;
    incomingFriendRequests = results[1] as List<FriendCandidate>;
    outgoingPendingFollows = results[2] as List<FriendCandidate>;
    final recommendations = results[3] as List<FriendCandidate>;
    friendRecommendations = recommendations
        .where((candidate) =>
            !incomingFriendRequests.any((incoming) => incoming.id == candidate.id))
        .toList();
    notifyListeners();
  }

  Future<void> _loadSecondaryData() async {
    try {
      await Future.wait([
        refreshFriendLists(),
        _getRecordSummaryUseCase().then((summary) {
          recordSummary = summary;
          notifyListeners();
        }),
        _getProfileOverviewUseCase().then((overview) {
          profileOverview = overview;
          notifyListeners();
        }),
        _getNotificationsUseCase().then((items) {
          notifications = items;
          notifyListeners();
        }),
        _getPendingMealTagsUseCase().then((tags) {
          pendingMealTags = tags;
          notifyListeners();
        }),
      ]);
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
