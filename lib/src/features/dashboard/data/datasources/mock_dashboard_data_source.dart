import '../../domain/entities/app_entities.dart';

class MockDashboardDataSource {
  Future<List<FeedPost>> getHomeFeed() async => const [
    FeedPost(
      id: 'p1',
      userId: 'u-haruka',
      userName: 'haruka',
      userIconUrl: null,
      placeName: 'and people udagawa',
      placeGoogleId: 'm1',
      caption: 'オムライスの半熟感が最高だった',
      imageUrl: 'https://images.unsplash.com/photo-1547592180-85f173990554',
      likes: 42,
      comments: 8,
      friendAvatars: ['H', 'R', 'M'],
    ),
    FeedPost(
      id: 'p2',
      userId: 'u-ryota',
      userName: 'ryota',
      userIconUrl: null,
      placeName: '恵比寿焼肉',
      placeGoogleId: 'm2',
      caption: '肉の香りがもう優勝',
      imageUrl: 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1',
      likes: 29,
      comments: 4,
      friendAvatars: ['Y', 'K'],
    ),
  ];

  Future<List<MapPin>> getMapPins() async => const [
    MapPin(
      id: 'm1',
      placeName: 'and people udagawa',
      rating: 4.6,
      friendComment: '雰囲気も味もバランス良い',
      imageUrl: 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4',
      isFriendVisited: true,
      hasPostedActivity: true,
    ),
    MapPin(
      id: 'm2',
      placeName: '渋谷らーめん本舗',
      rating: 4.2,
      friendComment: '深夜に沁みる',
      imageUrl: 'https://images.unsplash.com/photo-1557872943-16a5ac26437e',
      isFriendVisited: false,
    ),
  ];

  Future<List<MapPin>> searchMapPins(String keyword) async => getMapPins();

  Future<MapPin?> resolvePlacePinFromCoordinate(double lat, double lng) async {
    final pins = await getMapPins();
    return pins.isEmpty ? null : pins.first;
  }

  Future<PlaceDetail> getPlaceDetail(String placeId) async => const PlaceDetail(
    placeId: 'm1',
    placeName: 'and people udagawa',
    rating: 4.6,
    friendComment: '雰囲気も味もバランス良い',
    imageUrl: 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4',
    address: '東京都渋谷区宇田川町10-2',
    phoneNumber: '03-0000-0000',
    openNow: true,
    travelMinutes: 9,
    websiteUrl: 'https://www.andpeople.co.jp/',
    googleMapsUrl:
        'https://www.google.com/maps/search/?api=1&query=and+people+udagawa',
    posts: [
      PlacePostPreview(
        id: 'pp1',
        userName: 'haruka',
        comment: 'ライト暗めで写真映えした！',
        imageUrl:
            'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4',
      ),
      PlacePostPreview(
        id: 'pp2',
        userName: 'ryota',
        comment: 'ご飯もデザートも当たり',
        imageUrl:
            'https://images.unsplash.com/photo-1482049016688-2d3e1b311543',
      ),
      PlacePostPreview(
        id: 'pp3',
        userName: 'yuma_21',
        comment: '友達と来るのにちょうど良い',
        imageUrl:
            'https://images.unsplash.com/photo-1504674900247-0877df9cc836',
      ),
    ],
  );

  Future<List<PlaceSuggestion>> autocompletePlaces(
    String query, {
    double? biasLat,
    double? biasLng,
  }) async => const [
    PlaceSuggestion(placeId: 'm1', description: 'and people udagawa'),
    PlaceSuggestion(placeId: 'm2', description: '渋谷らーめん本舗'),
  ];

  Future<List<FriendCandidate>> getFriendCandidates() async => const [];

  Future<List<FriendCandidate>> searchUsersByCode(String query) async {
    return const [];
  }

  Future<RecordSummary> getRecordSummary() async => const RecordSummary(
    streakDays: 12,
    caloriesAvg: 1860,
    proteinAvg: 84,
    aiSuggestion: '夜ごはんの脂質が少し高め。明日は魚中心でバランス調整がおすすめ。',
    monthlyShots: ['1', '4', '5', '8', '12', '16', '20', '24', '26'],
  );

  Future<ProfileOverview> getProfileOverview() async => ProfileOverview(
    name: 'ryota',
    userCode: '@ryota',
    bio: '',
    avatarUrl: '',
    followers: 24,
    following: 18,
    friends: 12,
    pinnedPosts: [
      const ProfilePostThumb(
        postId: 'pin-1',
        imageUrl:
            'https://images.unsplash.com/photo-1604908177225-06b39e6d7f4a',
      ),
      const ProfilePostThumb(
        postId: 'pin-2',
        imageUrl:
            'https://images.unsplash.com/photo-1598214886806-c87b84b7078b',
      ),
      const ProfilePostThumb(
        postId: 'pin-3',
        imageUrl:
            'https://images.unsplash.com/photo-1498654896293-37aacf113fd9',
      ),
    ],
    recentPosts: [
      // ピン済み投稿もすべての投稿一覧に含まれる（ピン留めは集合のサブセット）
      const ProfilePostThumb(
        postId: 'pin-1',
        imageUrl:
            'https://images.unsplash.com/photo-1604908177225-06b39e6d7f4a',
      ),
      const ProfilePostThumb(
        postId: 'pin-2',
        imageUrl:
            'https://images.unsplash.com/photo-1598214886806-c87b84b7078b',
      ),
      const ProfilePostThumb(
        postId: 'pin-3',
        imageUrl:
            'https://images.unsplash.com/photo-1498654896293-37aacf113fd9',
      ),
      const ProfilePostThumb(
        postId: 'recent-1',
        imageUrl:
            'https://images.unsplash.com/photo-1504674900247-0877df9cc836',
      ),
      const ProfilePostThumb(
        postId: 'recent-2',
        imageUrl:
            'https://images.unsplash.com/photo-1466978913421-dad2ebd01d17',
      ),
      const ProfilePostThumb(
        postId: 'recent-3',
        imageUrl:
            'https://images.unsplash.com/photo-1473093295043-cdd812d0e601',
      ),
      const ProfilePostThumb(
        postId: 'recent-4',
        imageUrl:
            'https://images.unsplash.com/photo-1455619452474-d2be8b1e70cd',
      ),
      const ProfilePostThumb(
        postId: 'recent-5',
        imageUrl:
            'https://images.unsplash.com/photo-1515003197210-e0cd71810b5f',
      ),
      const ProfilePostThumb(
        postId: 'recent-6',
        imageUrl:
            'https://images.unsplash.com/photo-1526318896980-cf78c088247c',
      ),
    ],
  );

  Future<void> reportUser(String userId, String reason) async {}

  Future<void> reportPost(String postId, String reason) async {}

  Future<List<AppNotification>> getNotifications() async => const [
    AppNotification(
      id: 'n1',
      title: 'コメントが届きました',
      body: 'haruka さんがあなたの投稿にコメントしました',
      eventType: 'comment',
      actorUserId: 'haruka-id',
    ),
    AppNotification(
      id: 'n2',
      title: 'いいねが届きました',
      body: 'yuma_21 さんがあなたの投稿にいいねしました',
      eventType: 'like',
      actorUserId: 'yuma-id',
    ),
    AppNotification(
      id: 'n3',
      title: '友達申請が届きました',
      body: 'saya_27 さんから友達申請が届きました',
      eventType: 'friend_request',
      actorUserId: 'saya-id',
    ),
  ];

  Future<PostDraft> createPostDraft() async => const PostDraft(
    photoUrl: 'https://images.unsplash.com/photo-1482049016688-2d3e1b311543',
    placeName: '渋谷ヒカリエ',
    note: '甘辛ソースが最高',
    withWho: 'haruka, ryota',
  );
}
