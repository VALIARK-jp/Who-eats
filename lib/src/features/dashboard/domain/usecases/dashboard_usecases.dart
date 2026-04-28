import '../entities/app_entities.dart';
import '../repositories/dashboard_repository.dart';

class GetHomeFeedUseCase {
  const GetHomeFeedUseCase(this._repository);
  final DashboardRepository _repository;
  Future<List<FeedPost>> call() => _repository.getHomeFeed();
}

class GetMapPinsUseCase {
  const GetMapPinsUseCase(this._repository);
  final DashboardRepository _repository;
  Future<List<MapPin>> call() => _repository.getMapPins();
}

class SearchMapPinsUseCase {
  const SearchMapPinsUseCase(this._repository);
  final DashboardRepository _repository;
  Future<List<MapPin>> call(String keyword) => _repository.searchMapPins(keyword);
}

class SearchMapPinsAroundUseCase {
  const SearchMapPinsAroundUseCase(this._repository);
  final DashboardRepository _repository;
  Future<List<MapPin>> call({
    required double lat,
    required double lng,
    required int radiusMeters,
    String? keyword,
  }) => _repository.searchMapPinsAround(
    lat: lat,
    lng: lng,
    radiusMeters: radiusMeters,
    keyword: keyword,
  );
}

class ResolvePlacePinFromCoordinateUseCase {
  const ResolvePlacePinFromCoordinateUseCase(this._repository);
  final DashboardRepository _repository;
  Future<MapPin?> call(double lat, double lng) =>
      _repository.resolvePlacePinFromCoordinate(lat, lng);
}

class GetPlaceDetailUseCase {
  const GetPlaceDetailUseCase(this._repository);
  final DashboardRepository _repository;
  Future<PlaceDetail> call(String placeId) =>
      _repository.getPlaceDetail(placeId);
}

class AutocompletePlacesUseCase {
  const AutocompletePlacesUseCase(this._repository);
  final DashboardRepository _repository;
  Future<List<PlaceSuggestion>> call(String query) =>
      _repository.autocompletePlaces(query);
}

class GetFriendCandidatesUseCase {
  const GetFriendCandidatesUseCase(this._repository);
  final DashboardRepository _repository;
  Future<List<FriendCandidate>> call() => _repository.getFriendCandidates();
}

class GetRecordSummaryUseCase {
  const GetRecordSummaryUseCase(this._repository);
  final DashboardRepository _repository;
  Future<RecordSummary> call() => _repository.getRecordSummary();
}

class GetProfileOverviewUseCase {
  const GetProfileOverviewUseCase(this._repository);
  final DashboardRepository _repository;
  Future<ProfileOverview> call() => _repository.getProfileOverview();
}

class GetNotificationsUseCase {
  const GetNotificationsUseCase(this._repository);
  final DashboardRepository _repository;
  Future<List<AppNotification>> call() => _repository.getNotifications();
}

class CreatePostDraftUseCase {
  const CreatePostDraftUseCase(this._repository);
  final DashboardRepository _repository;
  Future<PostDraft> call() => _repository.createPostDraft();
}
