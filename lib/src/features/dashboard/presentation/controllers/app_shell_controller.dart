import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/location/device_location.dart';
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

  List<FeedPost> feed = [];
  List<MapPin> mapPins = [];
  List<FriendCandidate> friends = [];
  List<FriendCandidate> incomingFriendRequests = [];
  List<FriendCandidate> outgoingPendingFollows = [];
  List<FriendCandidate> friendRecommendations = [];
  RecordSummary? recordSummary;
  ProfileOverview? profileOverview;
  List<AppNotification> notifications = [];
  PostDraft? postDraft;
  List<PlaceSuggestion> placeSuggestions = [];
  Set<String> postedPlaceGoogleIds = <String>{};
  Map<String, String> postedPlaceUserIcons = <String, String>{};
  double? deviceLatitude;
  double? deviceLongitude;

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
    feed = [
      for (final p in feed)
        if (p.id == post.id) updated else p,
    ];
    notifyListeners();
    return updated;
  }

  Future<FeedPost> setProfilePinForPost(FeedPost post, bool pin) async {
    await _setProfilePostPinnedUseCase(post.id, pin);
    final updated = post.copyWith(isPinnedOnMyProfile: pin);
    feed = [
      for (final p in feed)
        if (p.id == post.id) updated else p,
    ];
    await refreshProfileOverview();
    return updated;
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
    feed = await _getHomeFeedUseCase();
    mapPins = await _getMapPinsUseCase(
      centerLat: deviceLatitude,
      centerLng: deviceLongitude,
    );
    await refreshFriendLists();
    recordSummary = await _getRecordSummaryUseCase();
    profileOverview = await _getProfileOverviewUseCase();
    notifications = await _getNotificationsUseCase();
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

  /// フォローする。相互フォローになったら true。
  Future<bool> followUser(String targetUserId) async {
    final becameFriend = await _followUserUseCase(targetUserId);
    await refreshFriendLists();
    return becameFriend;
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('[AppShellController] $message');
  }
}
