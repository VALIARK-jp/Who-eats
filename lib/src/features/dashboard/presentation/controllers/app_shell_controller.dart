import 'package:flutter/foundation.dart';

import '../../domain/entities/app_entities.dart';
import '../../domain/usecases/dashboard_usecases.dart';

class AppShellController extends ChangeNotifier {
  AppShellController({
    required GetHomeFeedUseCase getHomeFeedUseCase,
    required GetMapPinsUseCase getMapPinsUseCase,
    required GetFriendCandidatesUseCase getFriendCandidatesUseCase,
    required GetRecordSummaryUseCase getRecordSummaryUseCase,
    required GetProfileOverviewUseCase getProfileOverviewUseCase,
    required GetNotificationsUseCase getNotificationsUseCase,
    required CreatePostDraftUseCase createPostDraftUseCase,
    required GetPlaceDetailUseCase getPlaceDetailUseCase,
    required SearchMapPinsUseCase searchMapPinsUseCase,
    required SearchMapPinsAroundUseCase searchMapPinsAroundUseCase,
    required AutocompletePlacesUseCase autocompletePlacesUseCase,
    required ResolvePlacePinFromCoordinateUseCase resolvePlacePinFromCoordinateUseCase,
  }) : _getHomeFeedUseCase = getHomeFeedUseCase,
       _getMapPinsUseCase = getMapPinsUseCase,
       _getFriendCandidatesUseCase = getFriendCandidatesUseCase,
       _getRecordSummaryUseCase = getRecordSummaryUseCase,
       _getProfileOverviewUseCase = getProfileOverviewUseCase,
       _getNotificationsUseCase = getNotificationsUseCase,
       _createPostDraftUseCase = createPostDraftUseCase,
       _getPlaceDetailUseCase = getPlaceDetailUseCase,
       _searchMapPinsUseCase = searchMapPinsUseCase,
       _searchMapPinsAroundUseCase = searchMapPinsAroundUseCase,
       _autocompletePlacesUseCase = autocompletePlacesUseCase,
       _resolvePlacePinFromCoordinateUseCase = resolvePlacePinFromCoordinateUseCase;

  final GetHomeFeedUseCase _getHomeFeedUseCase;
  final GetMapPinsUseCase _getMapPinsUseCase;
  final GetFriendCandidatesUseCase _getFriendCandidatesUseCase;
  final GetRecordSummaryUseCase _getRecordSummaryUseCase;
  final GetProfileOverviewUseCase _getProfileOverviewUseCase;
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
  List<FriendCandidate> friendCandidates = [];
  RecordSummary? recordSummary;
  ProfileOverview? profileOverview;
  List<AppNotification> notifications = [];
  PostDraft? postDraft;
  List<PlaceSuggestion> placeSuggestions = [];

  Future<void> initialize() async {
    _log('initialize start');
    loading = true;
    notifyListeners();
    feed = await _getHomeFeedUseCase();
    mapPins = await _getMapPinsUseCase();
    friendCandidates = await _getFriendCandidatesUseCase();
    recordSummary = await _getRecordSummaryUseCase();
    profileOverview = await _getProfileOverviewUseCase();
    notifications = await _getNotificationsUseCase();
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
    _log('refreshMapPinsForViewport result=${mapPins.length}');
    notifyListeners();
  }

  Future<void> searchPlaceSuggestions(String query) async {
    _log('searchPlaceSuggestions query="$query"');
    placeSuggestions = await _autocompletePlacesUseCase(query);
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

  void _log(String message) {
    if (kDebugMode) debugPrint('[AppShellController] $message');
  }
}
