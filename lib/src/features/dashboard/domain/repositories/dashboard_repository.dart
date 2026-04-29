import '../entities/app_entities.dart';

abstract interface class DashboardRepository {
  Future<List<FeedPost>> getHomeFeed();
  Future<List<MapPin>> getMapPins();
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
  Future<List<FriendCandidate>> getFriendCandidates();
  Future<RecordSummary> getRecordSummary();
  Future<ProfileOverview> getProfileOverview();
  Future<List<AppNotification>> getNotifications();
  Future<PostDraft> createPostDraft();
}
