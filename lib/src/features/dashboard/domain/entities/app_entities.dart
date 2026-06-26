enum FeedTimelineScope { friends, near, all }

extension FeedTimelineScopeX on FeedTimelineScope {
  String get label {
    switch (this) {
      case FeedTimelineScope.friends:
        return '友達';
      case FeedTimelineScope.near:
        return '友達の友達';
      case FeedTimelineScope.all:
        return '全体';
    }
  }

  String get description {
    switch (this) {
      case FeedTimelineScope.friends:
        return '相互フォロー（友達）と自分の投稿だけ表示します。';
      case FeedTimelineScope.near:
        return '友達の友達まで含めて表示します。';
      case FeedTimelineScope.all:
        return '公開範囲とブロック設定に従い、閲覧できる投稿を広く表示します。';
    }
  }

  String get storageValue => name;

  static FeedTimelineScope fromStorage(String? value) {
    return FeedTimelineScope.values.firstWhere(
      (s) => s.name == value,
      orElse: () => FeedTimelineScope.friends,
    );
  }
}

/// フィードなどから地図タブで特定店舗のピンへ飛ぶときのリクエスト。
class MapPlaceFocus {
  const MapPlaceFocus({required this.placeGoogleId, required this.placeName});

  final String placeGoogleId;
  final String placeName;
}

class FeedPost {
  const FeedPost({
    required this.id,
    required this.userId,
    required this.userName,
    this.userIconUrl,
    required this.placeName,
    this.placeGoogleId,
    required this.caption,
    required this.imageUrl,
    required this.likes,
    required this.comments,
    required this.friendAvatars,
    this.isFavoritedByMe = false,
    this.isPinnedOnMyProfile = false,
    this.likedByMe = false,
    this.rating,
    this.createdAt,
    this.postType = 'restaurant',
    this.companionAvatars = const [],
    this.latestComment,
  });

  final String id;
  final String userId;
  final String userName;
  final String? userIconUrl;
  final String placeName;
  final String? placeGoogleId;
  final String caption;
  final String imageUrl;
  final int likes;
  final int comments;
  final List<String> friendAvatars;
  final bool isFavoritedByMe;
  final bool isPinnedOnMyProfile;
  final bool likedByMe;
  final int? rating;
  final DateTime? createdAt;
  final String postType;
  final List<String> companionAvatars;
  final PostComment? latestComment;

  bool get isHomePost => postType == 'home';

  FeedPost copyWith({
    String? caption,
    bool? isFavoritedByMe,
    bool? isPinnedOnMyProfile,
    bool? likedByMe,
    int? likes,
    int? comments,
    int? rating,
    DateTime? createdAt,
    String? postType,
    List<String>? companionAvatars,
    List<String>? friendAvatars,
    PostComment? latestComment,
    bool setLatestComment = false,
  }) {
    return FeedPost(
      id: id,
      userId: userId,
      userName: userName,
      userIconUrl: userIconUrl,
      placeName: placeName,
      placeGoogleId: placeGoogleId,
      caption: caption ?? this.caption,
      imageUrl: imageUrl,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      friendAvatars: friendAvatars ?? this.friendAvatars,
      isFavoritedByMe: isFavoritedByMe ?? this.isFavoritedByMe,
      isPinnedOnMyProfile: isPinnedOnMyProfile ?? this.isPinnedOnMyProfile,
      likedByMe: likedByMe ?? this.likedByMe,
      rating: rating ?? this.rating,
      createdAt: createdAt ?? this.createdAt,
      postType: postType ?? this.postType,
      companionAvatars: companionAvatars ?? this.companionAvatars,
      latestComment: setLatestComment
          ? latestComment
          : (latestComment ?? this.latestComment),
    );
  }
}

class PostComment {
  const PostComment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.body,
    required this.createdAt,
    this.userIconUrl,
    this.isMine = false,
  });

  final String id;
  final String userId;
  final String userName;
  final String body;
  final DateTime createdAt;
  final String? userIconUrl;
  final bool isMine;
}

class RecordDayEntry {
  const RecordDayEntry({
    required this.postId,
    required this.placeName,
    required this.imageUrl,
    required this.postType,
    this.companionNames = const [],
    this.rating,
    this.caption = '',
    this.userName = '',
    this.userIconUrl,
    this.placeGoogleId,
    this.createdAt,
  });

  final String postId;
  final String placeName;
  final String imageUrl;
  final String postType;
  final List<String> companionNames;
  final int? rating;
  final String caption;
  final String userName;
  final String? userIconUrl;
  final String? placeGoogleId;
  final DateTime? createdAt;
}

class UserPublicProfile {
  const UserPublicProfile({
    required this.userId,
    required this.name,
    required this.userCode,
    required this.bio,
    required this.avatarUrl,
    this.isFriend = false,
    this.iFollowThem = false,
    this.theyFollowMe = false,
    this.isBlocked = false,
    this.pinnedPosts = const [],
    this.recentPosts = const [],
  });

  final String userId;
  final String name;
  final String userCode;
  final String bio;
  final String avatarUrl;
  final bool isFriend;
  final bool iFollowThem;
  final bool theyFollowMe;
  final bool isBlocked;
  final List<ProfilePostThumb> pinnedPosts;
  final List<ProfilePostThumb> recentPosts;
}

class PendingMealTag {
  const PendingMealTag({
    required this.sourcePostId,
    required this.mealGroupId,
    required this.inviterName,
    required this.inviterIconUrl,
    required this.placeName,
  });

  final String sourcePostId;
  final String mealGroupId;
  final String inviterName;
  final String inviterIconUrl;
  final String placeName;
}

class ProfilePostThumb {
  const ProfilePostThumb({required this.postId, required this.imageUrl});

  final String postId;
  final String imageUrl;
}

class PlaceVisitor {
  const PlaceVisitor({
    required this.userId,
    required this.userName,
    required this.isFriend,
    this.avatarUrl,
    this.isMe = false,
  });

  final String userId;
  final String userName;
  final bool isFriend;
  final String? avatarUrl;
  final bool isMe;
}

class MapPin {
  const MapPin({
    required this.id,
    required this.placeName,
    required this.rating,
    required this.friendComment,
    required this.imageUrl,
    required this.isFriendVisited,
    this.hasPostedActivity = false,
    this.visitors = const [],
    this.mapPinIconUrl,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String placeName;
  final double rating;
  final String friendComment;
  final String imageUrl;

  /// 友達が投稿した店（従来のオレンジ強調用）。
  final bool isFriendVisited;

  /// Who eats 上で誰かが訪問投稿した店（友達以外も含む）。
  final bool hasPostedActivity;
  final List<PlaceVisitor> visitors;

  /// 地図ピン上に載せるアイコン（友達 → 自分の優先順。他人は載せない）。
  final String? mapPinIconUrl;
  final double? latitude;
  final double? longitude;

  MapPin copyWith({
    String? id,
    String? placeName,
    double? rating,
    String? friendComment,
    String? imageUrl,
    bool? isFriendVisited,
    bool? hasPostedActivity,
    List<PlaceVisitor>? visitors,
    String? mapPinIconUrl,
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
      hasPostedActivity: hasPostedActivity ?? this.hasPostedActivity,
      visitors: visitors ?? this.visitors,
      mapPinIconUrl: mapPinIconUrl ?? this.mapPinIconUrl,
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
    required this.isFriend,
    this.theyFollowMe = false,
    this.iFollowThem = false,
  });

  final String id;
  final String name;
  final String avatarUrl;

  /// 共通の友達（相互フォロー）の人数。おすすめ候補用。
  final int mutualCount;

  /// 相互フォロー済み（友達）なら true。
  final bool isFriend;

  /// 相手が自分をフォロー済み（フォロー返しで友達になれる）。
  final bool theyFollowMe;

  /// 自分が相手をフォロー済みだが、まだ相互ではない（承認待ち）。
  final bool iFollowThem;

  String get actionLabel {
    if (isFriend) return '友達';
    if (theyFollowMe && !iFollowThem) return '申請を承認';
    if (iFollowThem) return '申請中';
    return '友達申請';
  }

  bool get canFollow => !isFriend && !iFollowThem;

  bool get canCancelRequest => iFollowThem && !isFriend;
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
    required this.friends,
    required this.pinnedPosts,
    required this.recentPosts,
    this.defaultVisibility = 'friends',
  });

  final String name;
  final String userCode;
  final String bio;
  final String avatarUrl;
  final int followers;
  final int following;
  final int friends;
  final List<ProfilePostThumb> pinnedPosts;
  final List<ProfilePostThumb> recentPosts;
  final String defaultVisibility;

  List<String> get pinnedShots =>
      pinnedPosts.map((p) => p.imageUrl).where((u) => u.isNotEmpty).toList();

  List<String> get recentShots =>
      recentPosts.map((p) => p.imageUrl).where((u) => u.isNotEmpty).toList();
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.eventType,
    this.actorUserId,
    this.createdAt,
    this.isRead = false,
  });

  final String id;
  final String title;
  final String body;
  final String? eventType;
  final String? actorUserId;
  final DateTime? createdAt;
  final bool isRead;

  AppNotification copyWith({
    String? id,
    String? title,
    String? body,
    String? eventType,
    String? actorUserId,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      eventType: eventType ?? this.eventType,
      actorUserId: actorUserId ?? this.actorUserId,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }
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
    this.rating,
    this.companionUserIds = const [],
    this.mealGroupId,
    this.postType = 'restaurant',
    this.visibility = 'friends',
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
  final int? rating;
  final List<String> companionUserIds;
  final String? mealGroupId;
  final String postType;
  final String visibility;

  PostDraft copyWith({
    String? photoUrl,
    String? localImagePath,
    String? placeGoogleId,
    double? placeLatitude,
    double? placeLongitude,
    String? placeName,
    String? note,
    String? withWho,
    int? rating,
    List<String>? companionUserIds,
    String? mealGroupId,
    String? postType,
    String? visibility,
  }) {
    return PostDraft(
      photoUrl: photoUrl ?? this.photoUrl,
      localImagePath: localImagePath ?? this.localImagePath,
      placeGoogleId: placeGoogleId ?? this.placeGoogleId,
      placeLatitude: placeLatitude ?? this.placeLatitude,
      placeLongitude: placeLongitude ?? this.placeLongitude,
      placeName: placeName ?? this.placeName,
      note: note ?? this.note,
      withWho: withWho ?? this.withWho,
      rating: rating ?? this.rating,
      companionUserIds: companionUserIds ?? this.companionUserIds,
      mealGroupId: mealGroupId ?? this.mealGroupId,
      postType: postType ?? this.postType,
      visibility: visibility ?? this.visibility,
    );
  }
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
    this.visitors = const [],
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
  final List<PlaceVisitor> visitors;
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
