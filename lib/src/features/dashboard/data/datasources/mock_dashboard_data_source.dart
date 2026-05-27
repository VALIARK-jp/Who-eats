import '../../domain/entities/app_entities.dart';

class MockDashboardDataSource {
  Future<List<FeedPost>> getHomeFeed() async => const [
    FeedPost(
      id: 'p1',
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
      friendAvatars: ['H', 'R', 'M', 'Y'],
    ),
    MapPin(
      id: 'm2',
      placeName: '渋谷らーめん本舗',
      rating: 4.2,
      friendComment: '深夜に沁みる',
      imageUrl: 'https://images.unsplash.com/photo-1557872943-16a5ac26437e',
      isFriendVisited: false,
      friendAvatars: [],
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
    googleMapsUrl: 'https://www.google.com/maps/search/?api=1&query=and+people+udagawa',
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

  Future<List<FriendCandidate>> getFriendCandidates() async => const [
    FriendCandidate(
      id: 'f1',
      name: 'yuma_21',
      avatarUrl: '',
      mutualCount: 2,
      isFollowing: false,
    ),
    FriendCandidate(
      id: 'f2',
      name: 'saya_27',
      avatarUrl: '',
      mutualCount: 4,
      isFollowing: false,
    ),
    FriendCandidate(
      id: 'f3',
      name: 'mana_03',
      avatarUrl: '',
      mutualCount: 1,
      isFollowing: true,
    ),
    FriendCandidate(
      id: 'f4',
      name: 'takumi_99',
      avatarUrl: '',
      mutualCount: 3,
      isFollowing: false,
    ),
  ];

  Future<RecordSummary> getRecordSummary() async => const RecordSummary(
    streakDays: 12,
    caloriesAvg: 1860,
    proteinAvg: 84,
    aiSuggestion: '夜ごはんの脂質が少し高め。明日は魚中心でバランス調整がおすすめ。',
    monthlyShots: ['1', '4', '5', '8', '12', '16', '20', '24', '26'],
  );

  Future<ProfileOverview> getProfileOverview() async => const ProfileOverview(
    name: 'ryota',
    userCode: '@ryota',
    bio: '',
    avatarUrl: '',
    followers: 498,
    following: 342,
    friends: 120,
    pinnedShots: [
      'https://images.unsplash.com/photo-1604908177225-06b39e6d7f4a',
      'https://images.unsplash.com/photo-1598214886806-c87b84b7078b',
      'https://images.unsplash.com/photo-1498654896293-37aacf113fd9',
    ],
    recentShots: [
      'https://images.unsplash.com/photo-1504674900247-0877df9cc836',
      'https://images.unsplash.com/photo-1466978913421-dad2ebd01d17',
      'https://images.unsplash.com/photo-1473093295043-cdd812d0e601',
      'https://images.unsplash.com/photo-1455619452474-d2be8b1e70cd',
      'https://images.unsplash.com/photo-1515003197210-e0cd71810b5f',
      'https://images.unsplash.com/photo-1526318896980-cf78c088247c',
    ],
  );

  Future<List<AppNotification>> getNotifications() async => const [
    AppNotification(id: 'n1', message: 'haruka さんがコメントしました'),
    AppNotification(id: 'n2', message: 'yuma_21 さんがリアクションしました'),
    AppNotification(id: 'n3', message: 'saya_27 さんにフォローされました'),
  ];

  Future<PostDraft> createPostDraft() async => const PostDraft(
    photoUrl: 'https://images.unsplash.com/photo-1482049016688-2d3e1b311543',
    placeName: '渋谷ヒカリエ',
    note: '甘辛ソースが最高',
    withWho: 'haruka, ryota',
  );
}
