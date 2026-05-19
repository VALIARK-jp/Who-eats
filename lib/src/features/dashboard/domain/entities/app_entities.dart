class FeedPost {
  const FeedPost({
    required this.id,
    required this.userName,
    this.userIconUrl,
    required this.placeName,
    this.placeGoogleId,
    required this.caption,
    required this.imageUrl,
    required this.likes,
    required this.comments,
    required this.friendAvatars,
  });

  final String id;
  final String userName;
  final String? userIconUrl;
  final String placeName;
  final String? placeGoogleId;
  final String caption;
  final String imageUrl;
  final int likes;
  final int comments;
  final List<String> friendAvatars;
}

class MapPin {
  const MapPin({
    required this.id,
    required this.placeName,
    required this.rating,
    required this.friendComment,
    required this.imageUrl,
    required this.isFriendVisited,
    required this.friendAvatars,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String placeName;
  final double rating;
  final String friendComment;
  final String imageUrl;
  final bool isFriendVisited;
  final List<String> friendAvatars;
  final double? latitude;
  final double? longitude;

  MapPin copyWith({
    String? id,
    String? placeName,
    double? rating,
    String? friendComment,
    String? imageUrl,
    bool? isFriendVisited,
    List<String>? friendAvatars,
    double? latitude,
    double? longitude,
  }) {
    return MapPin(
      id: id ?? this.id,
      placeName: placeName ?? this.placeName,
      rating: rating ?? this.rating,
      friendComment: friendComment ?? this.friendComment,
      imageUrl: imageUrl ?? this.imageUrl,
      isFriendVisited: isFriendVisited ?? this.isFriendVisited,
      friendAvatars: friendAvatars ?? this.friendAvatars,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}

class FriendCandidate {
  const FriendCandidate({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.mutualCount,
    required this.isFollowing,
  });

  final String id;
  final String name;
  final String avatarUrl;
  final int mutualCount;
  final bool isFollowing;
}

class RecordSummary {
  const RecordSummary({
    required this.streakDays,
    required this.caloriesAvg,
    required this.proteinAvg,
    required this.aiSuggestion,
    required this.monthlyShots,
  });

  final int streakDays;
  final int caloriesAvg;
  final int proteinAvg;
  final String aiSuggestion;
  final List<String> monthlyShots;
}

class ProfileOverview {
  const ProfileOverview({
    required this.name,
    required this.userCode,
    required this.bio,
    required this.avatarUrl,
    required this.followers,
    required this.following,
    required this.pinnedShots,
    required this.recentShots,
  });

  final String name;
  final String userCode;
  final String bio;
  final String avatarUrl;
  final int followers;
  final int following;
  final List<String> pinnedShots;
  final List<String> recentShots;
}

class AppNotification {
  const AppNotification({required this.id, required this.message});

  final String id;
  final String message;
}

class PostDraft {
  const PostDraft({
    required this.photoUrl,
    this.localImagePath,
    this.placeGoogleId,
    this.placeLatitude,
    this.placeLongitude,
    required this.placeName,
    required this.note,
    required this.withWho,
  });

  final String photoUrl;

  /// Local filesystem path when the image was captured on device (Supabase flow).
  final String? localImagePath;
  final String? placeGoogleId;
  final double? placeLatitude;
  final double? placeLongitude;
  final String placeName;
  final String note;
  final String withWho;
}

class PlacePostPreview {
  const PlacePostPreview({
    required this.id,
    required this.userName,
    required this.comment,
    this.imageUrl,
  });

  final String id;
  final String userName;
  final String comment;
  final String? imageUrl;
}

class PlaceDetail {
  const PlaceDetail({
    required this.placeId,
    required this.placeName,
    required this.rating,
    required this.friendComment,
    required this.imageUrl,
    required this.posts,
    this.address,
    this.phoneNumber,
    this.openNow,
    this.travelMinutes,
    this.latitude,
    this.longitude,
    this.websiteUrl,
    this.googleMapsUrl,
  });

  final String placeId;
  final String placeName;
  final double rating;
  final String friendComment;
  final String imageUrl;
  final List<PlacePostPreview> posts;
  final String? address;
  final String? phoneNumber;
  final bool? openNow;
  final int? travelMinutes;
  final double? latitude;
  final double? longitude;
  final String? websiteUrl;
  final String? googleMapsUrl;
}

class PlaceSuggestion {
  const PlaceSuggestion({required this.placeId, required this.description});

  final String placeId;
  final String description;
}
