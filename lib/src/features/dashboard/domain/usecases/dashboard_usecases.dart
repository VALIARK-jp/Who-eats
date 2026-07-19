import '../entities/app_entities.dart';
import '../repositories/dashboard_repository.dart';

class GetHomeFeedUseCase {
  const GetHomeFeedUseCase(this._repository);
  final DashboardRepository _repository;
  Future<List<FeedPost>> call({
    FeedTimelineScope scope = FeedTimelineScope.all,
    HomeFeedPartialListener? onPartial,
  }) =>
      _repository.getHomeFeed(scope: scope, onPartial: onPartial);
}

class GetMapPinsUseCase {
  const GetMapPinsUseCase(this._repository);
  final DashboardRepository _repository;
  Future<List<MapPin>> call({
    double? centerLat,
    double? centerLng,
    MapPinsPartialListener? onPartial,
  }) =>
      _repository.getMapPins(
        centerLat: centerLat,
        centerLng: centerLng,
        onPartial: onPartial,
      );
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
    double? boundsMinLat,
    double? boundsMaxLat,
    double? boundsMinLng,
    double? boundsMaxLng,
    double zoom = 14,
    MapPinsPartialListener? onPartial,
  }) => _repository.searchMapPinsAround(
    lat: lat,
    lng: lng,
    radiusMeters: radiusMeters,
    keyword: keyword,
    boundsMinLat: boundsMinLat,
    boundsMaxLat: boundsMaxLat,
    boundsMinLng: boundsMinLng,
    boundsMaxLng: boundsMaxLng,
    zoom: zoom,
    onPartial: onPartial,
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
  Future<List<PlaceSuggestion>> call(
    String query, {
    double? biasLat,
    double? biasLng,
  }) => _repository.autocompletePlaces(
    query,
    biasLat: biasLat,
    biasLng: biasLng,
  );
}

class GetFriendsUseCase {
  const GetFriendsUseCase(this._repository);
  final DashboardRepository _repository;
  Future<List<FriendCandidate>> call() => _repository.getFriends();
}

class GetFriendRecommendationsUseCase {
  const GetFriendRecommendationsUseCase(this._repository);
  final DashboardRepository _repository;
  Future<List<FriendCandidate>> call() =>
      _repository.getFriendRecommendations();
}

class GetIncomingFriendRequestsUseCase {
  const GetIncomingFriendRequestsUseCase(this._repository);
  final DashboardRepository _repository;
  Future<List<FriendCandidate>> call() =>
      _repository.getIncomingFriendRequests();
}

class GetOutgoingPendingFollowsUseCase {
  const GetOutgoingPendingFollowsUseCase(this._repository);
  final DashboardRepository _repository;
  Future<List<FriendCandidate>> call() =>
      _repository.getOutgoingPendingFollows();
}

class FollowUserUseCase {
  const FollowUserUseCase(this._repository);
  final DashboardRepository _repository;
  Future<bool> call(String targetUserId) =>
      _repository.followUser(targetUserId);
}

class UnfollowUserUseCase {
  const UnfollowUserUseCase(this._repository);
  final DashboardRepository _repository;
  Future<void> call(String targetUserId) =>
      _repository.unfollowUser(targetUserId);
}

class TogglePostLikeUseCase {
  const TogglePostLikeUseCase(this._repository);
  final DashboardRepository _repository;
  Future<bool> call(String postId) => _repository.togglePostLike(postId);
}

class GetPostCommentsUseCase {
  const GetPostCommentsUseCase(this._repository);
  final DashboardRepository _repository;
  Future<List<PostComment>> call(String postId) =>
      _repository.getPostComments(postId);
}

class CreatePostCommentUseCase {
  const CreatePostCommentUseCase(this._repository);
  final DashboardRepository _repository;
  Future<PostComment> call(String postId, String body) =>
      _repository.createPostComment(postId, body);
}

class DeletePostCommentUseCase {
  const DeletePostCommentUseCase(this._repository);
  final DashboardRepository _repository;
  Future<void> call(String commentId) =>
      _repository.deletePostComment(commentId);
}

class SearchUsersByCodeUseCase {
  const SearchUsersByCodeUseCase(this._repository);
  final DashboardRepository _repository;
  Future<List<FriendCandidate>> call(String query) =>
      _repository.searchUsersByCode(query);
}

class SoftDeletePostUseCase {
  const SoftDeletePostUseCase(this._repository);
  final DashboardRepository _repository;
  Future<void> call(String postId) => _repository.softDeletePost(postId);
}

class UpdatePostCaptionUseCase {
  const UpdatePostCaptionUseCase(this._repository);
  final DashboardRepository _repository;
  Future<void> call(String postId, String caption) =>
      _repository.updatePostCaption(postId, caption);
}

class UpdatePostDetailsUseCase {
  const UpdatePostDetailsUseCase(this._repository);
  final DashboardRepository _repository;
  Future<void> call(
    String postId, {
    required String caption,
    required int rating,
    int? priceYen,
  }) =>
      _repository.updatePostDetails(
        postId,
        caption: caption,
        rating: rating,
        priceYen: priceYen,
      );
}

class GetPostsForDayUseCase {
  const GetPostsForDayUseCase(this._repository);
  final DashboardRepository _repository;
  Future<List<RecordDayEntry>> call(DateTime dayLocal) =>
      _repository.getPostsForDay(dayLocal);
}

class GetFeedPostByIdUseCase {
  const GetFeedPostByIdUseCase(this._repository);
  final DashboardRepository _repository;
  Future<FeedPost?> call(String postId) => _repository.getFeedPostById(postId);
}

class GetUserPublicProfileUseCase {
  const GetUserPublicProfileUseCase(this._repository);
  final DashboardRepository _repository;
  Future<UserPublicProfile?> call(String userId) =>
      _repository.getUserPublicProfile(userId);
}

class BlockUserUseCase {
  const BlockUserUseCase(this._repository);
  final DashboardRepository _repository;
  Future<void> call(String userId) => _repository.blockUser(userId);
}

class UnblockUserUseCase {
  const UnblockUserUseCase(this._repository);
  final DashboardRepository _repository;
  Future<void> call(String userId) => _repository.unblockUser(userId);
}

class ReportUserUseCase {
  const ReportUserUseCase(this._repository);
  final DashboardRepository _repository;
  Future<void> call(String userId, String reason) =>
      _repository.reportUser(userId, reason);
}

class ReportPostUseCase {
  const ReportPostUseCase(this._repository);
  final DashboardRepository _repository;
  Future<void> call(String postId, String reason) =>
      _repository.reportPost(postId, reason);
}

class GetPendingMealTagsUseCase {
  const GetPendingMealTagsUseCase(this._repository);
  final DashboardRepository _repository;
  Future<List<PendingMealTag>> call() => _repository.getPendingMealTags();
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

class GetProfilePostThumbsUseCase {
  const GetProfilePostThumbsUseCase(this._repository);
  final DashboardRepository _repository;
  Future<List<ProfilePostThumb>> call({required bool pinnedOnly}) =>
      _repository.getProfilePostThumbs(pinnedOnly: pinnedOnly);
}

class GetFavoritePostsUseCase {
  const GetFavoritePostsUseCase(this._repository);
  final DashboardRepository _repository;
  Future<List<FeedPost>> call() => _repository.getFavoritePosts();
}

class SetProfilePostPinnedUseCase {
  const SetProfilePostPinnedUseCase(this._repository);
  final DashboardRepository _repository;
  Future<void> call(String postId, bool pin) =>
      _repository.setProfilePostPinned(postId, pin);
}

class TogglePostFavoriteUseCase {
  const TogglePostFavoriteUseCase(this._repository);
  final DashboardRepository _repository;
  Future<bool> call(String postId) => _repository.togglePostFavorite(postId);
}

class GetNotificationsUseCase {
  const GetNotificationsUseCase(this._repository);
  final DashboardRepository _repository;
  Future<List<AppNotification>> call() => _repository.getNotifications();
}

class MarkAllNotificationsReadUseCase {
  const MarkAllNotificationsReadUseCase(this._repository);
  final DashboardRepository _repository;
  Future<void> call() => _repository.markAllNotificationsRead();
}

class CreatePostDraftUseCase {
  const CreatePostDraftUseCase(this._repository);
  final DashboardRepository _repository;
  Future<PostDraft> call() => _repository.createPostDraft();
}

class GetCityChoroplethMetricsUseCase {
  const GetCityChoroplethMetricsUseCase(this._repository);
  final DashboardRepository _repository;
  Future<List<CityChoroplethMetric>> call(String prefectureCode) =>
      _repository.getCityChoroplethMetrics(prefectureCode);

  Future<List<CityChoroplethMetric>> nationwide() =>
      _repository.getCityChoroplethMetricsNationwide();
}
