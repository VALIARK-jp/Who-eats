import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/web/google_maps_loader.dart';
import '../../../auth/presentation/login_page.dart';
import '../../../auth/presentation/signup_page.dart';
import '../../../../core/supabase/post_submit_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/app_entities.dart';
import '../controllers/app_shell_controller.dart';
import '../widgets/floating_bottom_nav.dart';
import '../widgets/signed_in_gate_overlay.dart';
import '../widgets/friend_avatar_stack.dart';
import '../widgets/food_post_card.dart';
import '../widgets/food_pin_3d_viewer.dart';
import '../widgets/place_bottom_sheet.dart';
import '../widgets/friend_avatar.dart';
import '../widgets/orange_glow_button.dart';
import '../widgets/calendar_record_view.dart';
import '../widgets/post_comment_preview.dart';
import '../widgets/profile_food_grid.dart';
import '../widgets/app_state_view.dart';
import 'profile_settings_page.dart';
import 'user_profile_page.dart';

class AppShellPage extends StatefulWidget {
  const AppShellPage({super.key});

  @override
  State<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends State<AppShellPage> {
  MapPin? _activePlaceSheetPin;
  bool _postEditorOpen = false;
  FeedPost? _activePostDetail;
  String? _activeUserProfileId;
  StreamSubscription<AuthState>? _authSub;
  AppShellController? _controller;
  int? _lastAuthUserHash;

  @override
  void initState() {
    super.initState();
    if (AppConfig.hasSupabase) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _controller = context.read<AppShellController>();
        _lastAuthUserHash = Supabase.instance.client.auth.currentUser?.id.hashCode;
        _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((
          AuthState data,
        ) {
          final newHash = data.session?.user.id.hashCode;
          if (newHash == _lastAuthUserHash) return;
          _lastAuthUserHash = newHash;
          unawaited(_handleAuthChanged());
        });
        unawaited(_handleAuthChanged());
      });
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _handleAuthChanged() async {
    if (!mounted) return;
    final controller = _controller;
    if (controller == null) return;
    controller.changeBottomIndex(0);
    controller.clearPostDraft();
    controller.clearPendingPostDraft();
    _activePlaceSheetPin = null;
    _activePostDetail = null;
    _activeUserProfileId = null;
    _postEditorOpen = false;
    setState(() {});
    await controller.initialize();
    if (!mounted) return;
    setState(() {});
  }

  bool _showsSignedInGate(int bottomIndex) {
    if (!AppConfig.hasSupabase) return false;
    if (bottomIndex == 0 || bottomIndex == 1) return false;
    return Supabase.instance.client.auth.currentUser == null;
  }

  double _bottomNavOffset(BuildContext context) {
    // Matches the outer padding of `FloatingBottomNav` (height=62, bottom padding=8).
    return 62 + 8 + MediaQuery.paddingOf(context).bottom;
  }

  void _openPlaceSheet(MapPin pin) {
    setState(() => _activePlaceSheetPin = pin);
  }

  void _closePlaceSheet() {
    if (_activePlaceSheetPin == null) return;
    setState(() => _activePlaceSheetPin = null);
  }

  void _openPostEditor() {
    setState(() => _postEditorOpen = true);
  }

  void _openPostDetail(FeedPost post) {
    setState(() => _activePostDetail = post);
  }

  void _closePostEditor({
    bool clearDraft = true,
    AppShellController? controller,
  }) {
    if (!_postEditorOpen) return;
    setState(() => _postEditorOpen = false);
    if (clearDraft) controller?.clearPostDraft();
  }

  void _closePostDetail() {
    if (_activePostDetail == null) return;
    setState(() => _activePostDetail = null);
  }

  void _openUserProfile(String userId) {
    setState(() => _activeUserProfileId = userId);
  }

  void _closeUserProfile() {
    if (_activeUserProfileId == null) return;
    setState(() => _activeUserProfileId = null);
  }

  void _openPlaceFromPost(FeedPost post, AppShellController controller) {
    if (post.isHomePost || (post.placeGoogleId ?? '').isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('この投稿には地図上の店舗がありません')),
      );
      return;
    }
    _closePostDetail();
    _closePlaceSheet();
    controller.focusMapOnPlace(
      post.placeGoogleId!,
      placeName: post.placeName,
    );
  }

  void _openFriendsPage() {
    if (AppConfig.hasSupabase &&
        Supabase.instance.client.auth.currentUser == null) {
      showDialog<void>(
        context: context,
        builder: (context) {
          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Material(
              color: AppColors.cardElevated,
              elevation: 8,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 40,
                      color: AppColors.orange.withValues(alpha: 0.9),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '友達機能を使うにはログインが必要です',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'ログインしてこの機能を解放しましょう。',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSubtle,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => const LoginPage(),
                            ),
                          );
                        },
                        child: const Text('ログイン'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => const SignupPage(),
                            ),
                          );
                        },
                        child: const Text('新規登録'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          backgroundColor: AppColors.black,
          body: Consumer<AppShellController>(
            builder: (_, ctrl, child) => _FriendsPage(
              controller: ctrl,
              friends: ctrl.friends,
              incoming: ctrl.incomingFriendRequests,
              outgoing: ctrl.outgoingPendingFollows,
              recommendations: ctrl.friendRecommendations,
              onFollow: ctrl.followUser,
              onUnfollow: ctrl.unfollowUser,
              onOpenProfile: _openUserProfile,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppShellController>(
      builder: (context, controller, _) {
        if (controller.loading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final pages = [
          _HomePage(
            controller: controller,
            onOpenPlaceFromPost: (post) => _openPlaceFromPost(post, controller),
            onOpenPostDetail: _openPostDetail,
            onOpenFriends: _openFriendsPage,
            onOpenDraft: () {
              if (controller.postDraft != null) {
                controller.changeBottomIndex(0);
                _openPostEditor();
              }
            },
          ),
          _MapTab(
            mapPins: controller.mapPins,
            controller: controller,
            onPlaceTap: _openPlaceSheet,
            onSearchExpansionChanged: (_) {},
            onEdgeSwipeBack: () {},
          ),
          _CameraPage(
            onShot: () => _startNewPostFlow(
              context,
              controller,
              source: ImageSource.camera,
            ),
            onGalleryPressed: () => _startNewPostFlow(
              context,
              controller,
              source: ImageSource.gallery,
            ),
          ),
          _RecordPage(
            summary: controller.recordSummary!,
            controller: controller,
            onOpenPostDetail: _openPostDetail,
          ),
          _ProfilePage(
            profile: controller.profileOverview!,
            controller: controller,
            onOpenPostDetail: _openPostDetail,
          ),
        ];

        final bottomOffset = _bottomNavOffset(context);
        final availableHeight =
            MediaQuery.of(context).size.height - bottomOffset;

        return Scaffold(
          extendBody: true,
          body: Stack(
            children: [
              pages[controller.bottomIndex],

              if (_showsSignedInGate(controller.bottomIndex))
                SignedInGateOverlay(
                  bottomInset: bottomOffset,
                  tabIndex: controller.bottomIndex,
                ),

              // Place (map pin) bottom sheet overlay.
              if (_activePlaceSheetPin != null)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _closePlaceSheet,
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.25),
                    ),
                  ),
                ),
              if (_activePlaceSheetPin != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: availableHeight,
                  child: DraggableScrollableSheet(
                    initialChildSize: 0.56,
                    minChildSize: 0.34,
                    maxChildSize: 0.78,
                    snap: true,
                    snapSizes: const [0.56, 0.72],
                    expand: false,
                    builder: (context, scrollController) {
                      final pin = _activePlaceSheetPin!;
                      return PlaceBottomSheet(
                        pin: pin,
                        detailFuture: controller.getPlaceDetail(pin.id),
                        scrollController: scrollController,
                        onClose: _closePlaceSheet,
                        onPostTap: (_) {},
                      );
                    },
                  ),
                ),

              // Post editor overlay (camera -> edit -> submit).
              if (_postEditorOpen && controller.postDraft != null)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  bottom: bottomOffset,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _closePostEditor(controller: controller),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.22),
                    ),
                  ),
                ),
              if (_postEditorOpen && controller.postDraft != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: bottomOffset,
                  height: availableHeight,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                      // Keep the same feel as the old bottom-sheet (72%).
                      height: (availableHeight * 0.72).clamp(
                        420.0,
                        availableHeight,
                      ),
                      child: PostCreationPage(
                        draft: controller.postDraft!,
                        controller: controller,
                        sheetHeight: (availableHeight * 0.72).clamp(
                          420.0,
                          availableHeight,
                        ),
                        onClose: () => _closePostEditor(controller: controller),
                      ),
                    ),
                  ),
                ),

              // Post detail overlay.
              if (_activePostDetail != null)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  bottom: bottomOffset,
                  child: ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) {
                      final base = _activePostDetail!;
                      final post = controller.feedPostById(base.id) ?? base;
                      return PostDetailPage(
                        post: post,
                        controller: controller,
                        onClose: _closePostDetail,
                        onPostUpdated: (updated) {
                          setState(() => _activePostDetail = updated);
                        },
                      );
                    },
                  ),
                ),

              if (_activeUserProfileId != null)
                Positioned.fill(
                  child: UserProfilePage(
                    userId: _activeUserProfileId!,
                    controller: controller,
                    onClose: _closeUserProfile,
                  ),
                ),
            ],
          ),
          bottomNavigationBar: FloatingBottomNav(
            selectedIndex: controller.bottomIndex,
            onTabSelected: (index) => controller.changeBottomIndex(index),
            onCameraPressed: () =>
                _startNewPostFlow(context, controller, source: ImageSource.camera),
          ),
        );
      },
    );
  }

  Future<void> _startNewPostFlow(
    BuildContext context,
    AppShellController controller,
    {required ImageSource source}
  ) async {
    // 画像の選択は先に行い、その後で現在地から最寄り店を補完する。
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 88,
    );
    if (file == null) return;

    final loc = await controller.ensureDeviceLocation();
    MapPin? nearest;
    if (loc != null) {
      nearest = await controller.resolvePlacePinFromCoordinate(
        loc.lat,
        loc.lng,
      );
    }

    controller.setPostDraft(
      PostDraft(
        photoUrl: '',
        localImagePath: file.path,
        placeGoogleId: nearest?.id,
        placeLatitude: nearest?.latitude,
        placeLongitude: nearest?.longitude,
        placeName: nearest?.placeName ?? '',
        note: '',
        withWho: '',
      ),
    );

    if (!context.mounted || controller.postDraft == null) return;
    // 編集シートはホーム上に載せる。
    controller.changeBottomIndex(0);
    await Future<void>.delayed(Duration.zero);
    if (!context.mounted || controller.postDraft == null) return;
    _openPostEditor();
  }
}

class _HomePage extends StatefulWidget {
  const _HomePage({
    required this.controller,
    required this.onOpenPlaceFromPost,
    required this.onOpenPostDetail,
    required this.onOpenFriends,
    required this.onOpenDraft,
  });
  final AppShellController controller;
  final ValueChanged<FeedPost> onOpenPlaceFromPost;
  final ValueChanged<FeedPost> onOpenPostDetail;
  final VoidCallback onOpenFriends;
  final VoidCallback onOpenDraft;

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Stack(
      children: [
        _FeedTab(
          feed: controller.feed,
          controller: controller,
          onTapPost: widget.onOpenPostDetail,
          onOpenPlaceFromPost: widget.onOpenPlaceFromPost,
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Badge(
                        isLabelVisible: controller.incomingFriendRequests.isNotEmpty,
                        label: Text('${controller.incomingFriendRequests.length}'),
                        child: const Icon(Icons.people_outline),
                      ),
                      onPressed: widget.onOpenFriends,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.black.withValues(alpha: 0.8),
                        minimumSize: const Size(46, 46),
                        fixedSize: const Size(46, 46),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.notifications_none),
                      onPressed: () =>
                          _showNotificationSheet(context, controller.notifications),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.black.withValues(alpha: 0.8),
                        minimumSize: const Size(46, 46),
                        fixedSize: const Size(46, 46),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final scope in FeedTimelineScope.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(scope.label),
                            selected: controller.feedTimelineScope == scope,
                            onSelected: (_) =>
                                controller.setFeedTimelineScope(scope),
                          ),
                        ),
                    ],
                  ),
                ),
                if (controller.pendingPostDraft != null) ...[
                  const SizedBox(height: 8),
                  Material(
                    color: AppColors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      dense: true,
                      title: const Text(
                        '投稿に失敗しました',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                      subtitle: const Text('タップして再試行'),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: controller.clearPendingPostDraft,
                      ),
                      onTap: () {
                        controller.setPostDraft(controller.pendingPostDraft!);
                        controller.clearPendingPostDraft();
                        widget.onOpenDraft();
                      },
                    ),
                  ),
                ],
                if (controller.pendingMealTags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Material(
                    color: AppColors.cardElevated,
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.group_add_outlined),
                      title: Text(
                        '${controller.pendingMealTags.first.inviterName}さんと一緒の食事',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(controller.pendingMealTags.first.placeName),
                      onTap: () {
                        final tag = controller.pendingMealTags.first;
                        controller.setPostDraft(
                          PostDraft(
                            photoUrl: '',
                            placeName: tag.placeName,
                            note: '',
                            withWho: tag.inviterName,
                            mealGroupId: tag.mealGroupId,
                          ),
                        );
                        widget.onOpenDraft();
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

}

class _FeedTab extends StatelessWidget {
  const _FeedTab({
    required this.feed,
    required this.controller,
    required this.onTapPost,
    required this.onOpenPlaceFromPost,
  });
  final List<FeedPost> feed;
  final AppShellController controller;
  final ValueChanged<FeedPost> onTapPost;
  final ValueChanged<FeedPost> onOpenPlaceFromPost;

  @override
  Widget build(BuildContext context) {
    final uid = controller.currentUserId;
    final myPosts = uid == null
        ? const <FeedPost>[]
        : feed.where((post) => post.userId == uid).toList();
    final otherPosts = uid == null
        ? feed
        : feed.where((post) => post.userId != uid).toList();

    if (feed.isEmpty) {
      return AppStateView(
        type: AppStateType.empty,
        title: '投稿がまだありません',
        message: '撮影して、みんなの「おすすめ」を広げよう。',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 220, 16, 120),
      children: [
        if (myPosts.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardElevated.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.orange.withValues(alpha: 0.42)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.orange.withValues(alpha: 0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.person_pin_circle_outlined,
                  color: AppColors.orangeAccent,
                  size: 22,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'My Post',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${myPosts.length}件',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final post in myPosts) ...[
            FoodPostCard(
              post: post,
              currentUserId: uid,
              onTap: () => onTapPost(post),
              onOpenPlace: () => onOpenPlaceFromPost(post),
              onToggleLike: uid != null
                  ? () async {
                      try {
                        await controller.togglePostLikeForPost(post);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$e')),
                          );
                        }
                      }
                    }
                  : null,
              onTogglePin: () async {
                final pin = !post.isPinnedOnMyProfile;
                try {
                  await controller.setProfilePinForPost(post, pin);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                }
              },
              onToggleFavorite: null,
            ),
            const SizedBox(height: 14),
          ],
          const SizedBox(height: 4),
        ],
        for (var i = 0; i < otherPosts.length; i++) ...[
          FoodPostCard(
            post: otherPosts[i],
            currentUserId: uid,
            onTap: () => onTapPost(otherPosts[i]),
            onOpenPlace: () => onOpenPlaceFromPost(otherPosts[i]),
            onToggleLike: uid != null
                ? () async {
                    try {
                      await controller.togglePostLikeForPost(otherPosts[i]);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$e')),
                        );
                      }
                    }
                  }
                : null,
            onTogglePin: null,
            onToggleFavorite: uid != null
                ? () => controller.togglePostFavoriteForPost(otherPosts[i])
                : null,
          ),
          if (i != otherPosts.length - 1) const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _MapTab extends StatefulWidget {
  const _MapTab({
    required this.mapPins,
    required this.controller,
    required this.onPlaceTap,
    required this.onSearchExpansionChanged,
    required this.onEdgeSwipeBack,
  });
  final List<MapPin> mapPins;
  final AppShellController controller;
  final ValueChanged<MapPin> onPlaceTap;
  final ValueChanged<bool> onSearchExpansionChanged;
  final VoidCallback onEdgeSwipeBack;

  @override
  State<_MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<_MapTab> {
  static const _defaultCenter = LatLng(35.6595, 139.7005);
  static const _edgeSwipeWidth = 26.0;
  static const _edgeSwipeTriggerDistance = 36.0;
  static const _hideDefaultPoiStyle = '''
[
  {
    "featureType": "poi",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "transit",
    "stylers": [{"visibility": "off"}]
  }
]
''';
  GoogleMapController? _mapController;
  bool _edgeSwipeTriggered = false;
  double _edgeSwipeDelta = 0;
  BitmapDescriptor? _visitedMarkerIcon;
  BitmapDescriptor? _unvisitedMarkerIcon;
  final Map<String, BitmapDescriptor> _clusterIconCache = {};
  final Set<String> _clusterIconLoading = {};
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String? _activeKeyword;
  LatLng _lastCameraTarget = _defaultCenter;
  double _lastZoom = 14;
  int _displayTier = 2;
  bool _fetchingViewportPins = false;
  bool _pendingViewportRefresh = false;
  Map<String, Offset> _visible3dPinOffsets = {};
  int _overlayProjectionRevision = 0;
  bool _searchExpanded = false;

  /// マップ静止時は 30fps、パン/ズーム中は 15〜20fps 相当に下げる（HTML 側 `setTargetFps`）。
  static const int _pin3dFpsMapIdle = 30;
  static const int _pin3dFpsMapMoving = 17;
  final ValueNotifier<int> _pin3dAnimationFps = ValueNotifier<int>(
    _pin3dFpsMapIdle,
  );

  bool _didCenterOnDeviceLocation = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onShellControllerUpdate);
    googleMapsLoadFailedNotifier.addListener(_onGoogleMapsLoadFailureChanged);
    _prepareMarkerIcons();
  }

  void _onShellControllerUpdate() {
    unawaited(_tryFocusPendingPlace());
    unawaited(_tryCenterOnDeviceLocation());
  }

  void _onGoogleMapsLoadFailureChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _tryCenterOnDeviceLocation() async {
    if (_didCenterOnDeviceLocation) return;
    if (widget.controller.pendingMapPlaceFocus != null) return;
    final lat = widget.controller.deviceLatitude;
    final lng = widget.controller.deviceLongitude;
    final map = _mapController;
    if (lat == null || lng == null || map == null) return;
    _didCenterOnDeviceLocation = true;
    try {
      await map.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(lat, lng), zoom: 15),
        ),
      );
      if (!mounted) return;
      setState(() {
        _lastCameraTarget = LatLng(lat, lng);
      });
      await _refreshViewportPins();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[MapTab] center on device location failed: $e\n$st');
      }
      _didCenterOnDeviceLocation = false;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onShellControllerUpdate);
    googleMapsLoadFailedNotifier.removeListener(
      _onGoogleMapsLoadFailureChanged,
    );
    _pin3dAnimationFps.dispose();
    _searchDebounce?.cancel();
    _searchController.dispose();
    widget.onSearchExpansionChanged(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pins = widget.mapPins;
    final topBarY = MediaQuery.paddingOf(context).top;
    if (kIsWeb && googleMapsLoadFailed) {
      return AppStateView(
        type: AppStateType.error,
        title: 'Google Maps を表示できません',
        message:
            googleMapsLoadErrorMessage ?? 'Google Maps API キーの制限を確認してください。',
        onRetry: AppConfig.hasGooglePlacesApi
            ? () async {
                try {
                  await loadGoogleMapsScript(AppConfig.googleMapsWebApiKey);
                } catch (_) {
                  // ignore
                }
                if (mounted) {
                  setState(() {});
                }
              }
            : null,
      );
    }

    if (pins.isEmpty) {
      final hasLocation =
          widget.controller.deviceLatitude != null &&
          widget.controller.deviceLongitude != null;
      return AppStateView(
        type: hasLocation ? AppStateType.empty : AppStateType.permissionDenied,
        title: hasLocation ? '近くの店舗が見つかりません' : '位置情報が必要です',
        message: hasLocation
            ? 'キーワード検索で探してみてください。'
            : '位置情報/位置許可を有効にしてからお試しください。',
        onRetry: hasLocation ? null : () {},
      );
    }
    return Stack(
      children: [
        Positioned.fill(
          child: GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _defaultCenter,
              zoom: 14,
            ),
            style: _hideDefaultPoiStyle,
            onMapCreated: (controller) {
              _mapController = controller;
              _log('Map created, refreshing viewport pins');
              unawaited(
                _refreshViewportPins().catchError((e, st) {
                  _log('Error refreshing viewport pins: $e\n$st');
                }),
              );
              unawaited(_tryCenterOnDeviceLocation());
              unawaited(_tryFocusPendingPlace());
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onCameraMove: (position) {
              if (_pin3dAnimationFps.value != _pin3dFpsMapMoving) {
                _pin3dAnimationFps.value = _pin3dFpsMapMoving;
              }
              _lastCameraTarget = position.target;
              _lastZoom = position.zoom;
              _update3dOverlayPositionsForVisiblePins();
              final nextTier = _displayTierForZoom(_lastZoom);
              if (nextTier != _displayTier) {
                setState(() {
                  _displayTier = nextTier;
                });
              }
            },
            onCameraIdle: () async {
              if (_pin3dAnimationFps.value != _pin3dFpsMapIdle) {
                _pin3dAnimationFps.value = _pin3dFpsMapIdle;
              }
              await _update3dOverlayPositionsForVisiblePins();
              await _refreshViewportPins();
            },
            markers: _buildMapMarkers(context, pins),
          ),
        ),
        if (!_searchExpanded)
          Positioned(
            top: topBarY,
            left: 24,
            child: IconButton(
              icon: const Icon(Icons.search, color: Colors.white70),
              onPressed: () => _setSearchExpanded(true),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.black.withValues(alpha: 0.8),
                minimumSize: const Size(46, 46),
                fixedSize: const Size(46, 46),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        if (_searchExpanded)
          Positioned(
            top: topBarY,
            left: 24,
            right: 92,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.blackElevated.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {});
                      _onSearchChanged(value);
                    },
                    onSubmitted: (_) => _runSearchAndJump(),
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'エリア・店名で検索',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                      ),
                      border: InputBorder.none,
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.white70,
                      ),
                      suffixIcon: _searchController.text.trim().isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white70,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                widget.controller.clearPlaceSuggestions();
                                setState(() {});
                                _applyKeywordFilter(null);
                              },
                            )
                          : IconButton(
                              icon: const Icon(
                                Icons.keyboard_arrow_up,
                                color: Colors.white70,
                              ),
                              onPressed: () => _setSearchExpanded(false),
                            ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                if (_searchController.text.trim().isNotEmpty &&
                    widget.controller.placeSuggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(
                      color: AppColors.blackElevated.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: widget.controller.placeSuggestions.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                      itemBuilder: (context, index) {
                        final suggestion =
                            widget.controller.placeSuggestions[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.location_on_outlined,
                            size: 18,
                            color: Colors.white70,
                          ),
                          title: Text(
                            suggestion.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white),
                          ),
                          onTap: () => _selectSuggestion(suggestion),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        Positioned(
          right: 18,
          bottom: 150,
          child: Column(
            children: [
              _ZoomButton(icon: Icons.add, onTap: _zoomInSmoothly),
              const SizedBox(height: 10),
              _ZoomButton(icon: Icons.remove, onTap: _zoomOutSmoothly),
            ],
          ),
        ),
        ..._build3dPinOverlays(pins),
        Positioned(
          top: 0,
          bottom: 0,
          left: 0,
          width: _edgeSwipeWidth,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: (_) {
              _edgeSwipeTriggered = false;
              _edgeSwipeDelta = 0;
            },
            onHorizontalDragUpdate: (details) {
              if (_edgeSwipeTriggered) return;
              _edgeSwipeDelta += details.delta.dx;
              if (_edgeSwipeDelta > _edgeSwipeTriggerDistance) {
                _edgeSwipeTriggered = true;
                widget.onEdgeSwipeBack();
              }
            },
            onHorizontalDragEnd: (_) {
              _edgeSwipeTriggered = false;
              _edgeSwipeDelta = 0;
            },
            onHorizontalDragCancel: () {
              _edgeSwipeTriggered = false;
              _edgeSwipeDelta = 0;
            },
          ),
        ),
      ],
    );
  }

  LatLng _latLngFor(MapPin pin, int index) {
    if (pin.latitude != null && pin.longitude != null) {
      return LatLng(pin.latitude!, pin.longitude!);
    }
    return LatLng(35.6585 + (index * 0.003), 139.699 + (index * 0.0025));
  }

  Future<void> _openMapBottomSheet(BuildContext context, MapPin pin) async {
    if (!context.mounted) return;
    _log('openBottomSheet placeId=${pin.id} name=${pin.placeName}');
    widget.onPlaceTap(pin);
  }

  Future<void> _applyKeywordFilter(String? keyword) async {
    _activeKeyword = keyword;
    await _refreshViewportPins();
  }

  Future<void> _runSearchAndJump() async {
    final keyword = _searchController.text.trim();
    widget.controller.clearPlaceSuggestions();
    await _applyKeywordFilter(keyword.isEmpty ? null : keyword);
    await _jumpToFirstSearchResult();
    if (!mounted) return;
    if (widget.controller.mapPins.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('該当する店舗が見つかりませんでした')));
    }
  }

  Future<void> _jumpToFirstSearchResult() async {
    final pins = widget.controller.mapPins;
    if (pins.isEmpty) return;
    final target = pins.firstWhere(
      (p) => p.latitude != null && p.longitude != null,
      orElse: () => pins.first,
    );
    await _animateToPin(target);
  }

  Future<void> _animateToPin(MapPin pin) async {
    final controller = _mapController;
    if (controller == null) return;
    final lat = pin.latitude;
    final lng = pin.longitude;
    if (lat == null || lng == null) return;
    final nextZoom = _lastZoom < 15 ? 15.0 : _lastZoom;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(lat, lng), zoom: nextZoom),
      ),
    );
    if (!mounted) return;
    setState(() {
      _lastCameraTarget = LatLng(lat, lng);
      _lastZoom = nextZoom;
    });
  }

  Future<void> _tryFocusPendingPlace() async {
    final focus = widget.controller.pendingMapPlaceFocus;
    if (focus == null) return;
    final map = _mapController;
    if (map == null) return;

    MapPin? pin;
    for (final p in widget.controller.mapPins) {
      if (p.id == focus.placeGoogleId) {
        pin = p;
        break;
      }
    }

    var lat = pin?.latitude;
    var lng = pin?.longitude;

    if (lat == null || lng == null) {
      try {
        final detail = await widget.controller.getPlaceDetail(
          focus.placeGoogleId,
        );
        lat = detail.latitude;
        lng = detail.longitude;
        pin ??= MapPin(
          id: focus.placeGoogleId,
          placeName: detail.placeName.isNotEmpty
              ? detail.placeName
              : focus.placeName,
          rating: detail.rating,
          friendComment: detail.friendComment,
          imageUrl: detail.imageUrl,
          isFriendVisited: widget.controller.postedPlaceGoogleIds.contains(
            focus.placeGoogleId,
          ),
          friendAvatars: const [],
          latitude: lat,
          longitude: lng,
        );
      } catch (e, st) {
        _log('focus pending place failed: $e\n$st');
      }
    }

    if (lat == null || lng == null) {
      widget.controller.clearPendingMapPlaceFocus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('店舗の位置を地図上に表示できませんでした')),
        );
      }
      return;
    }

    final focusLat = lat;
    final focusLng = lng;
    _didCenterOnDeviceLocation = true;
    widget.controller.clearPendingMapPlaceFocus();

    const nextZoom = 15.0;
    await map.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(focusLat, focusLng), zoom: nextZoom),
      ),
    );
    if (!mounted) return;
    setState(() {
      _lastCameraTarget = LatLng(focusLat, focusLng);
      _lastZoom = nextZoom;
    });
    await _refreshViewportPins();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    if (value.trim().isEmpty && _activeKeyword != null) {
      // Clear should immediately restore all pins, not just after debounce.
      widget.controller.clearPlaceSuggestions();
      unawaited(_applyKeywordFilter(null));
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      final keyword = value.trim();
      if (keyword.isEmpty) {
        widget.controller.clearPlaceSuggestions();
      } else {
        widget.controller.searchPlaceSuggestions(keyword);
      }
    });
  }

  void _setSearchExpanded(bool expanded) {
    if (_searchExpanded == expanded) return;
    setState(() {
      _searchExpanded = expanded;
    });
    widget.onSearchExpansionChanged(expanded);
    if (!expanded) {
      widget.controller.clearPlaceSuggestions();
    }
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    _searchController.text = suggestion.description;
    _searchController.selection = TextSelection.collapsed(
      offset: _searchController.text.length,
    );
    widget.controller.clearPlaceSuggestions();
    final detail = await widget.controller.getPlaceDetail(suggestion.placeId);
    final lat = detail.latitude;
    final lng = detail.longitude;
    if (lat != null && lng != null) {
      final controller = _mapController;
      if (controller != null) {
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(lat, lng),
              zoom: _lastZoom < 14.5 ? 14.5 : _lastZoom,
            ),
          ),
        );
      }
      _activeKeyword = null;
      await _refreshViewportPins();
    } else {
      await _applyKeywordFilter(suggestion.description);
      await _jumpToFirstSearchResult();
    }
    if (!mounted) return;
    if (widget.controller.mapPins.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('候補に一致する店舗が見つかりませんでした')));
    }
  }

  Future<void> _refreshViewportPins() async {
    if (_fetchingViewportPins) {
      _pendingViewportRefresh = true;
      return;
    }
    _fetchingViewportPins = true;
    try {
      await widget.controller.refreshMapPinsForViewport(
        lat: _lastCameraTarget.latitude,
        lng: _lastCameraTarget.longitude,
        radiusMeters: _radiusMetersForZoom(_lastZoom),
        keyword: _activeKeyword,
      );
      await _update3dOverlayPositionsForVisiblePins();
    } finally {
      _fetchingViewportPins = false;
      if (_pendingViewportRefresh) {
        _pendingViewportRefresh = false;
        unawaited(_refreshViewportPins());
      }
    }
  }

  Future<void> _update3dOverlayPositionsForVisiblePins() async {
    final controller = _mapController;
    if (controller == null) return;
    if (_displayTier != 2) {
      if (!mounted) return;
      if (_visible3dPinOffsets.isNotEmpty) {
        setState(() {
          _visible3dPinOffsets = {};
        });
      }
      return;
    }

    final pins = widget.mapPins;
    if (pins.isEmpty) {
      if (!mounted) return;
      if (_visible3dPinOffsets.isNotEmpty) {
        setState(() {
          _visible3dPinOffsets = {};
        });
      }
      return;
    }

    final revision = ++_overlayProjectionRevision;
    final nextOffsets = <String, Offset>{};
    try {
      for (int i = 0; i < pins.length; i++) {
        final pin = pins[i];
        final latLng = _latLngFor(pin, i);
        final point = await controller.getScreenCoordinate(latLng);
        nextOffsets[pin.id] = Offset(point.x.toDouble(), point.y.toDouble());
      }
      if (!mounted) return;
      setState(() {
        if (revision != _overlayProjectionRevision) return;
        _visible3dPinOffsets = nextOffsets;
      });
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[MapTab] getScreenCoordinate failed: $e\n$st');
      }
      if (!mounted) return;
      setState(() {
        if (revision != _overlayProjectionRevision) return;
        _visible3dPinOffsets = {};
      });
    }
  }

  List<Widget> _build3dPinOverlays(List<MapPin> pins) {
    if (_displayTier != 2 || _visible3dPinOffsets.isEmpty) {
      return const [];
    }
    final postedIds = widget.controller.postedPlaceGoogleIds;

    return [
      for (int i = 0; i < pins.length; i++)
        if (_visible3dPinOffsets.containsKey(pins[i].id) &&
            (postedIds.contains(pins[i].id) || pins[i].isFriendVisited))
          ..._buildSingle3dOverlayWithTapTarget(
            context,
            pins[i],
            isPostedPin: true,
          ),
    ];
  }

  List<Widget> _buildSingle3dOverlayWithTapTarget(
    BuildContext context,
    MapPin pin, {
    required bool isPostedPin,
  }) {
    final offset = _visible3dPinOffsets[pin.id]!;
    final pinAssetPath = isPostedPin
        ? 'assets/3d_pin_posted.html'
        : 'assets/3d_pin.html';
    final postedIconUrl = widget.controller.postedPlaceUserIcons[pin.id];
    return [
      Positioned(
        left: offset.dx - 75,
        top: offset.dy - 130,
        width: 150,
        height: 150,
        child: IgnorePointer(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: FoodPin3DViewer(
              key: ValueKey('map-3d-${pin.id}-posted:$isPostedPin'),
              width: 150,
              height: 150,
              assetPath: pinAssetPath,
              initialIconUrl: isPostedPin ? postedIconUrl : null,
              initialIconAsset: isPostedPin ? 'doc/yuto.jpg' : null,
              webviewBackground: Colors.transparent,
              animationFpsListenable: _pin3dAnimationFps,
            ),
          ),
        ),
      ),
      Positioned(
        left: offset.dx - 36,
        top: offset.dy - 98,
        width: 72,
        height: 78,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => _openMapBottomSheet(context, pin),
          child: const SizedBox.expand(),
        ),
      ),
    ];
  }

  int _radiusMetersForZoom(double zoom) {
    if (zoom >= 16) return 700;
    if (zoom >= 15) return 1000;
    if (zoom >= 14) return 1600;
    if (zoom >= 13) return 2500;
    if (zoom >= 12) return 3800;
    return 5000;
  }

  int _displayTierForZoom(double zoom) {
    if (zoom >= 14) return 2; // individual pins
    if (zoom >= 11) return 1; // medium clusters
    return 0; // broad clusters
  }

  Set<Marker> _buildMapMarkers(BuildContext context, List<MapPin> pins) {
    if (_displayTier == 2) {
      return {
        for (int i = 0; i < pins.length; i++)
          Marker(
            markerId: MarkerId(pins[i].id),
            position: _latLngFor(pins[i], i),
            icon: pins[i].isFriendVisited
                ? (_visitedMarkerIcon ??
                      BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueOrange,
                      ))
                : (_unvisitedMarkerIcon ??
                      BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueAzure,
                      )),
            zIndexInt: pins[i].isFriendVisited ? 1 : 0,
            onTap: () async => _openMapBottomSheet(context, pins[i]),
          ),
      };
    }

    final grouped = <String, List<MapPin>>{};
    final cellSize = _clusterCellSizeForZoom(_lastZoom);
    for (int i = 0; i < pins.length; i++) {
      final pin = pins[i];
      final latLng = _latLngFor(pin, i);
      final row = (latLng.latitude / cellSize).floor();
      final col = (latLng.longitude / cellSize).floor();
      final key = '$row:$col';
      grouped.putIfAbsent(key, () => <MapPin>[]).add(pin);
    }

    return {
      for (final entry in grouped.entries)
        _buildClusterMarker(entry.key, entry.value),
    };
  }

  double _clusterCellSizeForZoom(double zoom) {
    if (zoom < 9) return 0.6;
    if (zoom < 11) return 0.22;
    if (zoom < 13) return 0.09;
    return 0.035;
  }

  Marker _buildClusterMarker(String key, List<MapPin> pins) {
    var latSum = 0.0;
    var lngSum = 0.0;
    var visitedCount = 0;
    for (final pin in pins) {
      latSum += pin.latitude ?? 0;
      lngSum += pin.longitude ?? 0;
      if (pin.isFriendVisited) visitedCount++;
    }
    final center = LatLng(latSum / pins.length, lngSum / pins.length);
    final icon = _clusterIconFor(total: pins.length, visited: visitedCount);
    return Marker(
      markerId: MarkerId('cluster_$key'),
      position: center,
      icon:
          icon ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      zIndexInt: 3,
      infoWindow: InfoWindow(
        title: '友達が来た店舗: $visitedCount件',
        snippet: 'この範囲の全店舗: ${pins.length}店',
      ),
    );
  }

  BitmapDescriptor? _clusterIconFor({
    required int total,
    required int visited,
  }) {
    final key = 't${_bucket(total)}_v${_bucket(visited)}';
    final cached = _clusterIconCache[key];
    if (cached != null) return cached;
    if (_clusterIconLoading.contains(key)) return null;
    _clusterIconLoading.add(key);
    _drawClusterBytes(
      total: total,
      visited: visited,
      size: _displayTier == 0 ? 92 : 76,
    ).then((bytes) {
      if (!mounted) return;
      setState(() {
        _clusterIconCache[key] = BitmapDescriptor.bytes(bytes);
        _clusterIconLoading.remove(key);
      });
    });
    return null;
  }

  int _bucket(int value) {
    if (value <= 3) return value;
    if (value <= 8) return 8;
    if (value <= 20) return 20;
    if (value <= 60) return 60;
    return 99;
  }

  Future<void> _prepareMarkerIcons() async {
    final visitedBytes = await _drawMicroDotBytes(
      size: 24,
      color: AppColors.orange.withValues(alpha: 0.85),
    );
    final unvisitedBytes = await _drawMicroDotBytes(
      size: 16,
      color: AppColors.gray.withValues(alpha: 0.65),
    );
    if (!mounted) return;
    setState(() {
      _visitedMarkerIcon = BitmapDescriptor.bytes(visitedBytes);
      _unvisitedMarkerIcon = BitmapDescriptor.bytes(unvisitedBytes);
    });
  }

  Future<Uint8List> _drawMicroDotBytes({
    required int size,
    required Color color,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final width = size.toDouble();
    final center = Offset(width / 2, width / 2);
    canvas.drawCircle(
      center,
      width * 0.28,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * 0.08,
    );
    canvas.drawCircle(center, width * 0.22, Paint()..color = color);
    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), width.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<Uint8List> _drawClusterBytes({
    required int total,
    required int visited,
    required int size,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final width = size.toDouble();
    final center = Offset(width / 2, width / 2);
    final orange = AppColors.orange;
    final baseColor =
        visited > 0 ? AppColors.orange : AppColors.gray.withValues(alpha: 0.85);

    final glowPaint = Paint()
      ..color = orange.withValues(alpha: 0.24)
      ..color = baseColor.withValues(alpha: 0.24)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawCircle(center, width * 0.36, glowPaint);

    final corePaint = Paint()
      ..color = orange
      ..color = baseColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, width * 0.26, corePaint);

    canvas.drawCircle(center, width * 0.22, Paint()..color = Colors.white);

    final textPainter = TextPainter(
      text: TextSpan(
        text: '$visited',
        style: TextStyle(
          color: AppColors.blackElevated,
          fontSize: width * 0.26,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2 - (visited > 0 ? width * 0.05 : 0),
      ),
    );

    final visitedPainter = TextPainter(
      text: TextSpan(
        text: '友 $visited',
        style: TextStyle(
          color: visited > 0
              ? AppColors.orangeHighlight
              : AppColors.gray.withValues(alpha: 0.68),
          fontSize: width * 0.13,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    visitedPainter.paint(
      canvas,
      Offset(center.dx - visitedPainter.width / 2, center.dy + width * 0.08),
    );

    final avatarDots = visited.clamp(0, 8);
    for (int i = 0; i < avatarDots; i++) {
      final theta = (2 * pi / avatarDots) * i - pi / 2;
      final dotCenter = Offset(
        center.dx + cos(theta) * width * 0.33,
        center.dy + sin(theta) * width * 0.33,
      );
      canvas.drawCircle(dotCenter, width * 0.05, Paint()..color = Colors.white);
      canvas.drawCircle(dotCenter, width * 0.038, Paint()..color = orange);
      canvas.drawCircle(dotCenter, width * 0.038, Paint()..color = baseColor);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), width.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _zoomInSmoothly() async {
    final controller = _mapController;
    if (controller == null) return;
    await controller.animateCamera(CameraUpdate.zoomIn());
  }

  Future<void> _zoomOutSmoothly() async {
    final controller = _mapController;
    if (controller == null) return;
    await controller.animateCamera(CameraUpdate.zoomOut());
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('[MapTab] $message');
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.black.withValues(alpha: 0.8),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}

class _FriendsPage extends StatefulWidget {
  const _FriendsPage({
    required this.controller,
    required this.friends,
    required this.incoming,
    required this.outgoing,
    required this.recommendations,
    required this.onFollow,
    required this.onUnfollow,
    required this.onOpenProfile,
  });

  final AppShellController controller;
  final List<FriendCandidate> friends;
  final List<FriendCandidate> incoming;
  final List<FriendCandidate> outgoing;
  final List<FriendCandidate> recommendations;
  final Future<bool> Function(String userId) onFollow;
  final Future<void> Function(String userId) onUnfollow;
  final ValueChanged<String> onOpenProfile;

  @override
  State<_FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<_FriendsPage> {
  bool _searchByConnection = false;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onFriendTap(FriendCandidate c) {
    widget.onOpenProfile(c.id);
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      final q = value.trim();
      if (q.length < 2) {
        widget.controller.clearUserCodeSearch();
        return;
      }
      await widget.controller.searchUsersByCode(q);
    });
  }

  void _onBackPressed() {
    if (_searchByConnection) {
      setState(() => _searchByConnection = false);
      return;
    }
    Navigator.pop(context);
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _onBackPressed,
            tooltip: _searchByConnection ? '友達一覧に戻る' : '戻る',
            style: IconButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(40, 40),
            ),
          ),
          Expanded(
            child: Text(
              _searchByConnection ? 'からむで探す' : '友達',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
          ),
          if (!_searchByConnection && widget.incoming.isNotEmpty)
            Badge(
              label: Text('${widget.incoming.length}'),
              child: const Icon(Icons.mail_outline, size: 22),
            ),
        ],
      ),
    );
  }

  bool get _hasNoFriendsData =>
      widget.friends.isEmpty &&
      widget.incoming.isEmpty &&
      widget.outgoing.isEmpty &&
      widget.recommendations.isEmpty;

  Widget _buildDiscoverButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: OrangeGlowButton(
        width: double.infinity,
        height: 42,
        isEnabled: true,
        borderRadius: 999,
        onPressed: () => setState(() => _searchByConnection = true),
        child: const Text(
          'からむで探す',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),

          if (!_searchByConnection) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                onChanged: (v) {
                  setState(() {});
                  _onSearchChanged(v);
                },
                decoration: InputDecoration(
                  hintText: '@user_codeで検索',
                  prefixIcon: const Icon(Icons.search, color: Colors.white70),
                  suffixIcon: _searchController.text.trim().isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (widget.controller.userCodeSearchResults.isNotEmpty)
              ...widget.controller.userCodeSearchResults.map(
                (c) => _FriendCandidateRow(
                  candidate: c,
                  onFriendTap: _onFriendTap,
                  onFollow: widget.onFollow,
                  onUnfollow: widget.onUnfollow,
                ),
              ),
            if (!_hasNoFriendsData) _buildDiscoverButton(),
          ],

          Expanded(
            child: _searchByConnection
                ? FriendSearchPage(
                    incoming: widget.incoming,
                    outgoing: widget.outgoing,
                    candidates: widget.recommendations,
                    onBack: () => setState(() => _searchByConnection = false),
                    onFriendTap: _onFriendTap,
                    onFollow: widget.onFollow,
                    onUnfollow: widget.onUnfollow,
                  )
                : _hasNoFriendsData
                ? Column(
                    children: [
                      const Expanded(
                        child: AppStateView(
                          type: AppStateType.empty,
                          title: '友達がいません',
                          message: '「からむで探す」から友達を見つけましょう。',
                        ),
                      ),
                      _buildDiscoverButton(),
                    ],
                  )
                : FriendGrid(
                    candidates: widget.friends,
                    onFriendTap: _onFriendTap,
                  ),
          ),
        ],
      ),
    );
  }
}

/// 友達アイコンのグリッド（4列）。
class FriendGrid extends StatelessWidget {
  const FriendGrid({
    super.key,
    required this.candidates,
    required this.onFriendTap,
  });

  final List<FriendCandidate> candidates;
  final ValueChanged<FriendCandidate> onFriendTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: candidates.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.9,
      ),
      itemBuilder: (context, index) {
        final item = candidates[index];
        final showDot =
            item.isFriend || item.theyFollowMe || item.mutualCount > 0;
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => onFriendTap(item),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FriendAvatar(
                displayName: item.name,
                radius: 22,
                showStatusDot: showDot,
              ),
              const SizedBox(height: 8),
              Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 「からむで探す」: フォロー返し・承認待ち・おすすめ候補（🔶タグ行のみモック）。
class FriendSearchPage extends StatelessWidget {
  const FriendSearchPage({
    super.key,
    required this.incoming,
    required this.outgoing,
    required this.candidates,
    required this.onBack,
    required this.onFriendTap,
    required this.onFollow,
    required this.onUnfollow,
  });

  final List<FriendCandidate> incoming;
  final List<FriendCandidate> outgoing;
  final List<FriendCandidate> candidates;
  final VoidCallback onBack;
  final ValueChanged<FriendCandidate> onFriendTap;
  final Future<bool> Function(String userId) onFollow;
  final Future<void> Function(String userId) onUnfollow;

  @override
  Widget build(BuildContext context) {
    // 🔶 モック: DB 未整備（doc/mvp-mock-vs-real-data.md 参照）
    final recommendedTags = const ['グルメ', 'カフェ巡り', 'ラーメン', '焼肉', 'スイーツ', 'ランチ'];

    final sorted = [...candidates]
      ..sort((a, b) => b.mutualCount.compareTo(a.mutualCount));

    final top = sorted.take(4).toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (incoming.isNotEmpty) ...[
          const Text(
            '友達申請が届いています',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            '承認すると友達（相互フォロー）になります',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 10),
          ...incoming.map((c) => _FriendCandidateRow(
                candidate: c,
                onFriendTap: onFriendTap,
                onFollow: onFollow,
                onUnfollow: onUnfollow,
              )),
          const SizedBox(height: 18),
        ],
        if (outgoing.isNotEmpty) ...[
          const Text(
            '送信した申請',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            '相手の承認を待っています',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 10),
          ...outgoing.map((c) => _FriendCandidateRow(
                candidate: c,
                onFriendTap: onFriendTap,
                onFollow: onFollow,
                onUnfollow: onUnfollow,
              )),
          const SizedBox(height: 18),
        ],
        const Text(
          '共通の友達が多い人',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),

        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, i) {
              final c = top[i];
              final showDot =
                  c.isFriend || c.theyFollowMe || c.mutualCount > 0;
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onFriendTap(c),
                child: Container(
                  width: 120,
                  decoration: BoxDecoration(
                    color: AppColors.blackElevated.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FriendAvatar(
                        displayName: c.name,
                        radius: 22,
                        showStatusDot: showDot,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '共通 ${c.mutualCount}人',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.65),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemCount: top.length,
          ),
        ),

        const SizedBox(height: 18),

        const Text(
          'おすすめタグ',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),

        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final t in recommendedTags)
              FilterChip(
                label: Text(t),
                onSelected: (_) {},
                selected: false,
                backgroundColor: AppColors.blackElevated.withValues(alpha: 0.7),
                shape: StadiumBorder(
                  side: BorderSide(
                    color: AppColors.orange.withValues(alpha: 0.5),
                  ),
                ),
                labelStyle: const TextStyle(fontWeight: FontWeight.w900),
                checkmarkColor: AppColors.orange,
              ),
          ],
        ),

        const SizedBox(height: 18),

        const Text(
          '候補一覧',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),

        ...sorted.map(
          (c) => _FriendCandidateRow(
            candidate: c,
            onFriendTap: onFriendTap,
            onFollow: onFollow,
            onUnfollow: onUnfollow,
          ),
        ),
      ],
    );
  }
}

class _FriendCandidateRow extends StatelessWidget {
  const _FriendCandidateRow({
    required this.candidate,
    required this.onFriendTap,
    required this.onFollow,
    required this.onUnfollow,
  });

  final FriendCandidate candidate;
  final ValueChanged<FriendCandidate> onFriendTap;
  final Future<bool> Function(String userId) onFollow;
  final Future<void> Function(String userId) onUnfollow;

  @override
  Widget build(BuildContext context) {
    final c = candidate;
    final subtitle = c.theyFollowMe && !c.iFollowThem
        ? 'あなたに友達申請が届いています'
        : c.iFollowThem
        ? '申請中'
        : '共通友達 ${c.mutualCount}人';

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => onFriendTap(c),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.blackElevated.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            FriendAvatar(
              displayName: c.name,
              radius: 20,
              showStatusDot:
                  c.isFriend || c.theyFollowMe || c.mutualCount > 0,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.65),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: c.canCancelRequest
                  ? () async {
                      await onUnfollow(c.id);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${c.name} への申請を取り消しました')),
                      );
                    }
                  : c.canFollow
                  ? () async {
                      final becameFriend = await onFollow(c.id);
                      if (!context.mounted) return;
                      final msg = becameFriend
                          ? '${c.name} と友達になりました'
                          : '${c.name} に友達申請を送りました';
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(msg)));
                    }
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.black,
                shape: const StadiumBorder(),
              ),
              child: Text(c.actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraPage extends StatelessWidget {
  const _CameraPage({
    required this.onShot,
    required this.onGalleryPressed,
  });
  final VoidCallback onShot;
  final VoidCallback onGalleryPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: GestureDetector(
        onTap: onShot,
        child: Container(
          color: Colors.black,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'タップしてカメラで撮影',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  '位置情報の取得は撮影のあとに行います。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white38,
                    height: 1.35,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 220,
                child: OutlinedButton.icon(
                  onPressed: onGalleryPressed,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('ギャラリーから選ぶ'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordPage extends StatelessWidget {
  const _RecordPage({
    required this.summary,
    required this.controller,
    required this.onOpenPostDetail,
  });
  final RecordSummary summary;
  final AppShellController controller;
  final ValueChanged<FeedPost> onOpenPostDetail;

  Future<void> _openEntry(RecordDayEntry entry) async {
    final fromFeed = controller.feedPostById(entry.postId);
    if (fromFeed != null) {
      onOpenPostDetail(fromFeed);
      return;
    }
    final loaded = await controller.loadFeedPostById(entry.postId);
    if (loaded != null) {
      onOpenPostDetail(loaded);
      return;
    }
    onOpenPostDetail(
      FeedPost(
        id: entry.postId,
        userId: controller.currentUserId ?? '',
        userName: entry.userName.isNotEmpty ? entry.userName : '自分',
        userIconUrl: entry.userIconUrl,
        placeName: entry.placeName,
        placeGoogleId: entry.placeGoogleId,
        caption: entry.caption,
        imageUrl: entry.imageUrl,
        likes: 0,
        comments: 0,
        friendAvatars: const [],
        rating: entry.rating,
        createdAt: entry.createdAt,
        postType: entry.postType,
        companionAvatars: entry.companionNames
            .map((n) => n.isNotEmpty ? n[0].toUpperCase() : '?')
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CalendarRecordView(
        summary: summary,
        loadDayEntries: controller.loadPostsForDay,
        onOpenPost: _openEntry,
      ),
    );
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage({
    required this.profile,
    required this.controller,
    required this.onOpenPostDetail,
  });
  final ProfileOverview profile;
  final AppShellController controller;
  final ValueChanged<FeedPost> onOpenPostDetail;

  FeedPost _postFromThumb(ProfilePostThumb thumb, {required bool pinned}) {
    final fromFeed = controller.feedPostById(thumb.postId);
    if (fromFeed != null) return fromFeed;
    final uid = controller.currentUserId ?? '';
    return FeedPost(
      id: thumb.postId,
      userId: uid,
      userName: profile.name,
      userIconUrl: profile.avatarUrl.isNotEmpty ? profile.avatarUrl : null,
      placeName: '',
      caption: '',
      imageUrl: thumb.imageUrl,
      likes: 0,
      comments: 0,
      friendAvatars: const [],
      isPinnedOnMyProfile: pinned,
    );
  }

  void _openThumb(BuildContext context, ProfilePostThumb thumb, {required bool pinned}) {
    onOpenPostDetail(_postFromThumb(thumb, pinned: pinned));
  }

  @override
  Widget build(BuildContext context) {
    final initial = profile.name.isNotEmpty
        ? profile.name.characters.first.toUpperCase()
        : '?';

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          120 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'プロフィール',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ProfileSettingsPage(
                        controller: controller,
                        onOpenPostDetail: onOpenPostDetail,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundImage: profile.avatarUrl.isNotEmpty
                    ? NetworkImage(profile.avatarUrl)
                    : null,
                child: profile.avatarUrl.isEmpty ? Text(initial) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (profile.userCode.isNotEmpty)
                      Text(
                        profile.userCode,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textSubtle),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (profile.bio.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              profile.bio,
              style: const TextStyle(color: AppColors.textSubtle, height: 1.4),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatTile(label: '友達', value: profile.friends),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('ピン留めしたご飯', style: TextStyle(fontWeight: FontWeight.w900)),
          ProfileFoodGrid(
            thumbs: profile.pinnedPosts,
            onThumbTap: (t) => _openThumb(context, t, pinned: true),
          ),
          const SizedBox(height: 12),
          const Text('投稿一覧', style: TextStyle(fontWeight: FontWeight.w900)),
          ProfileFoodGrid(
            thumbs: profile.recentPosts,
            onThumbTap: (t) => _openThumb(context, t, pinned: false),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _MapPlaceSheet extends StatelessWidget {
  const _MapPlaceSheet({
    required this.pin,
    required this.detailFuture,
    required this.scrollController,
    required this.onClose,
  });
  final MapPin pin;
  final Future<PlaceDetail> detailFuture;
  final ScrollController scrollController;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.blackElevated.withValues(alpha: 0.9),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: FutureBuilder<PlaceDetail>(
        future: detailFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError && kDebugMode) {
            debugPrint('[MapPlaceSheet] detail error: ${snapshot.error}');
          }
          final detail = snapshot.data;
          return ListView(
            controller: scrollController,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            children: [
              Center(
                child: Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (snapshot.hasError)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: Text('店舗詳細の取得に失敗しました')),
                )
              else if (detail == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (detail != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: detail.imageUrl.isEmpty
                          ? Container(
                              width: 112,
                              height: 92,
                              color: AppColors.gray,
                              alignment: Alignment.center,
                              child: const Icon(Icons.restaurant, size: 28),
                            )
                          : Image.network(
                              detail.imageUrl,
                              width: 112,
                              height: 92,
                              fit: BoxFit.cover,
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  detail.placeName,
                                  style: const TextStyle(
                                    fontSize: 27,
                                    fontWeight: FontWeight.w700,
                                    height: 1.05,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white70,
                                ),
                                onPressed: onClose,
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '★ ${detail.rating.toStringAsFixed(1)}',
                            style: const TextStyle(
                              color: AppColors.orange,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if ((detail.address ?? '').isNotEmpty)
                            Text(
                              detail.address!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.72),
                              ),
                            ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (detail.openNow != null)
                                Text(
                                  detail.openNow! ? '営業中' : '営業時間外',
                                  style: TextStyle(
                                    color: detail.openNow!
                                        ? AppColors.orange
                                        : Colors.white70,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              if (detail.travelMinutes != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '徒歩 ${detail.travelMinutes}分',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.blackElevated.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                        child: _PlaceActionButton(
                          icon: Icons.call_outlined,
                          label: '電話',
                        ),
                      ),
                      Expanded(
                        child: _PlaceActionButton(
                          icon: Icons.directions_walk,
                          label: '経路',
                          subLabel: '徒歩',
                        ),
                      ),
                      Expanded(
                        child: _PlaceActionButton(
                          icon: Icons.map_outlined,
                          label: 'Google Maps',
                          subLabel: 'で開く',
                        ),
                      ),
                      Expanded(
                        child: _PlaceActionButton(
                          icon: Icons.bookmark_border,
                          label: '保存',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Text(
                      '友達が行っています',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Text(
                      '${pin.friendAvatars.length} 人',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: pin.friendAvatars.isEmpty
                        ? 1
                        : pin.friendAvatars.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      if (pin.friendAvatars.isEmpty) {
                        return const CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.gray,
                          child: Icon(Icons.person_outline),
                        );
                      }
                      return CircleAvatar(
                        radius: 20,
                        backgroundImage: NetworkImage(pin.friendAvatars[i]),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                const Text('写真', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 86,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: 5,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      if (detail.imageUrl.isEmpty) {
                        return Container(
                          width: 108,
                          decoration: BoxDecoration(
                            color: AppColors.gray,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.photo_outlined),
                        );
                      }
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          detail.imageUrl,
                          width: 108,
                          fit: BoxFit.cover,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'みんなの投稿',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (detail.posts.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.blackElevated.withValues(alpha: 0.67),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('レビューはまだありません'),
                  )
                else
                  ...detail.posts
                      .take(3)
                      .map(
                        (post) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.blackElevated.withValues(
                              alpha: 0.67,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            children: [
                              if (post.imageUrl != null &&
                                  post.imageUrl!.isNotEmpty)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    post.imageUrl!,
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              else
                                const CircleAvatar(
                                  radius: 28,
                                  backgroundColor: AppColors.gray,
                                  child: Icon(Icons.photo_outlined, size: 20),
                                ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      post.userName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      post.comment,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _BottomStat(
                        icon: Icons.star_rounded,
                        label: '評価',
                        value: detail.rating.toStringAsFixed(1),
                      ),
                    ),
                    Expanded(
                      child: _BottomStat(
                        icon: Icons.bookmark_border,
                        label: '保存数',
                        value: '${(detail.rating * 90).round()}',
                      ),
                    ),
                    Expanded(
                      child: _BottomStat(
                        icon: Icons.local_fire_department_outlined,
                        label: 'チェックイン',
                        value: '${(detail.rating * 260).round()}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: () {},
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('投稿する'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PlaceActionButton extends StatelessWidget {
  const _PlaceActionButton({
    required this.icon,
    required this.label,
    this.subLabel,
  });

  final IconData icon;
  final String label;
  final String? subLabel;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            Icon(icon, size: 18, color: Colors.white70),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11)),
            if (subLabel != null)
              Text(
                subLabel!,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.65),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomStat extends StatelessWidget {
  const _BottomStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppColors.orange),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.white70),
        ),
      ],
    );
  }
}

class PostCreationPage extends StatefulWidget {
  const PostCreationPage({
    super.key,
    required this.draft,
    required this.controller,
    required this.onClose,
    this.sheetHeight,
  });
  final PostDraft draft;
  final AppShellController controller;
  final VoidCallback onClose;
  final double? sheetHeight;

  @override
  State<PostCreationPage> createState() => _PostCreationPageState();
}

class _PostCreationPageState extends State<PostCreationPage> {
  late final TextEditingController _captionController;
  late final TextEditingController _placeController;
  late String _postType;
  late String _visibility;
  String? _localImagePath;
  String? _photoUrl;
  bool _submitting = false;
  String? _selectedPlaceGoogleId;
  double? _selectedPlaceLat;
  double? _selectedPlaceLng;
  String _selectedPlaceName = '';
  int? _rating;
  final Set<String> _companionIds = {};
  Timer? _placeSearchDebounce;
  bool _suppressPlaceChange = false;
  bool _resolvingPlace = false;

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController(text: widget.draft.note);
    _placeController = TextEditingController(text: widget.draft.placeName);
    _localImagePath = widget.draft.localImagePath;
    _photoUrl = widget.draft.photoUrl;
    _selectedPlaceGoogleId = widget.draft.placeGoogleId;
    _selectedPlaceLat = widget.draft.placeLatitude;
    _selectedPlaceLng = widget.draft.placeLongitude;
    _selectedPlaceName = widget.draft.placeName;
    _postType = widget.draft.postType;
    _visibility = widget.draft.visibility;
    _rating = widget.draft.rating;
    _companionIds.addAll(widget.draft.companionUserIds);
  }

  @override
  void dispose() {
    _placeSearchDebounce?.cancel();
    _captionController.dispose();
    _placeController.dispose();
    super.dispose();
  }

  String _visibilityLabel() {
    switch (_visibility) {
      case 'public':
        return '公開';
      case 'private':
        return '非公開';
      default:
        return '友だちのみ';
    }
  }

  String _currentPlaceName() {
    final text = _placeController.text.trim();
    if (text.isNotEmpty) return text;
    return _selectedPlaceName;
  }

  String _currentCaption() => _captionController.text.trim();

  PostDraft _currentDraft() {
    return widget.draft.copyWith(
      photoUrl: _photoUrl ?? widget.draft.photoUrl,
      localImagePath: _localImagePath ?? widget.draft.localImagePath,
      placeGoogleId: _selectedPlaceGoogleId,
      placeLatitude: _selectedPlaceLat,
      placeLongitude: _selectedPlaceLng,
      placeName: _currentPlaceName(),
      note: _currentCaption(),
      withWho: widget.draft.withWho,
      rating: _rating,
      companionUserIds: _companionIds.toList(),
      mealGroupId: widget.draft.mealGroupId,
      postType: _postType,
      visibility: _visibility,
    );
  }

  void _clearPlaceSuggestions() {
    widget.controller.clearPlaceSuggestions();
  }

  void _schedulePlaceSearch(String query) {
    _placeSearchDebounce?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      _clearPlaceSuggestions();
      return;
    }
    _placeSearchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      widget.controller.searchPlaceSuggestions(trimmed);
    });
  }

  void _onPlaceChanged(String value) {
    if (_suppressPlaceChange) return;
    setState(() {
      _selectedPlaceGoogleId = null;
      _selectedPlaceLat = null;
      _selectedPlaceLng = null;
      _selectedPlaceName = value;
    });
    _schedulePlaceSearch(value);
  }

  Future<void> _choosePlaceSuggestion(PlaceSuggestion suggestion) async {
    if (_resolvingPlace) return;
    _placeSearchDebounce?.cancel();
    _clearPlaceSuggestions();
    setState(() => _resolvingPlace = true);
    try {
      final detail = await widget.controller.getPlaceDetail(suggestion.placeId);
      if (!mounted) return;
      final resolvedName = detail.placeName.isNotEmpty
          ? detail.placeName
          : suggestion.description;
      _suppressPlaceChange = true;
      _placeController.text = resolvedName;
      _selectedPlaceGoogleId = detail.placeId;
      _selectedPlaceLat = detail.latitude;
      _selectedPlaceLng = detail.longitude;
      _selectedPlaceName = resolvedName;
      setState(() {});
      unawaited(
        Future<void>.delayed(Duration.zero, () {
          if (mounted) _suppressPlaceChange = false;
        }),
      );
    } catch (_) {
      if (!mounted) return;
      _suppressPlaceChange = true;
      _placeController.text = suggestion.description;
      _selectedPlaceGoogleId = suggestion.placeId;
      _selectedPlaceLat = null;
      _selectedPlaceLng = null;
      _selectedPlaceName = suggestion.description;
      setState(() {});
      unawaited(
        Future<void>.delayed(Duration.zero, () {
          if (mounted) _suppressPlaceChange = false;
        }),
      );
    } finally {
      if (mounted) setState(() => _resolvingPlace = false);
    }
  }

  Future<void> _replaceImage(ImageSource source) async {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 88,
    );
    if (file == null || !mounted) return;
    setState(() {
      _localImagePath = file.path;
      _photoUrl = '';
    });
  }

  Future<void> _submit(BuildContext context) async {
    if (_submitting) return;
    final draft = _currentDraft();
    if (AppConfig.hasSupabase) {
      final path = _localImagePath;
      if (path == null || path.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('写真が必要です')));
        return;
      }
      if (_postType == 'restaurant' &&
          (_selectedPlaceGoogleId == null ||
              _selectedPlaceLat == null ||
              _selectedPlaceLng == null)) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('店名の候補を選択してください')),
        );
        return;
      }
      setState(() => _submitting = true);
      try {
        await PostSubmitService().submitPhotoPost(
          imageFile: File(path),
          postType: _postType,
          visibility: _visibility,
          restaurantPlaceGoogleId: _postType == 'restaurant'
              ? _selectedPlaceGoogleId
              : null,
          restaurantPlaceName: _postType == 'restaurant'
              ? _currentPlaceName()
              : null,
          restaurantPlaceLatitude:
              _postType == 'restaurant' ? _selectedPlaceLat : null,
          restaurantPlaceLongitude:
              _postType == 'restaurant' ? _selectedPlaceLng : null,
          caption: _captionController.text.trim().isEmpty
              ? null
              : _captionController.text.trim(),
          rating: _rating,
          mealGroupId: widget.draft.mealGroupId,
          companionUserIds: _companionIds.toList(),
        );
        if (!context.mounted) return;
        widget.controller.clearPostDraft();
        widget.controller.clearPendingPostDraft();
        await widget.controller.initialize();
        if (!context.mounted) return;
        widget.onClose();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('投稿しました')));
      } catch (e) {
        if (!context.mounted) return;
        widget.controller.setPendingPostDraft(draft);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('投稿に失敗しました: $e')));
      } finally {
        if (mounted) setState(() => _submitting = false);
      }
      return;
    }
    if (!context.mounted) return;
    widget.onClose();
  }

  void _onSubmitPressed(BuildContext context) {
    FocusScope.of(context).unfocus();
    _submit(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    const actionAreaHeight = 84.0;
    final suggestions = widget.controller.placeSuggestions;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: widget.sheetHeight ?? MediaQuery.of(context).size.height * 0.72,
        child: Stack(
          children: [
            Positioned.fill(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: widget.onClose,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        '新しい投稿',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: 200,
                      width: double.infinity,
                      child: _localImagePath != null
                          ? Image.file(
                              File(_localImagePath!),
                              fit: BoxFit.cover,
                            )
                          : (_photoUrl?.isNotEmpty == true
                              ? Image.network(_photoUrl!, fit: BoxFit.cover)
                              : Container(
                                  color: AppColors.gray.withValues(alpha: 0.35),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.photo_outlined,
                                    size: 42,
                                    color: Colors.white70,
                                  ),
                                )),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _replaceImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('ギャラリー'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _replaceImage(ImageSource.camera),
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: const Text('撮り直す'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_postType == 'restaurant') ...[
                    TextField(
                      controller: _placeController,
                      onChanged: _onPlaceChanged,
                      decoration: InputDecoration(
                        labelText: '店名',
                        hintText: '店名を入力すると候補が出ます',
                        suffixIcon: _resolvingPlace
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : (_placeController.text.isNotEmpty
                                ? IconButton(
                                    tooltip: '入力を消す',
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _placeSearchDebounce?.cancel();
                                      _suppressPlaceChange = true;
                                      _placeController.clear();
                                      setState(() {
                                        _selectedPlaceGoogleId = null;
                                        _selectedPlaceLat = null;
                                        _selectedPlaceLng = null;
                                        _selectedPlaceName = '';
                                      });
                                      _clearPlaceSuggestions();
                                      unawaited(
                                        Future<void>.delayed(Duration.zero, () {
                                          if (mounted) {
                                            _suppressPlaceChange = false;
                                          }
                                        }),
                                      );
                                    },
                                  )
                                : null),
                      ),
                    ),
                    if (_selectedPlaceGoogleId == null)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          '候補を選ぶと、店名と位置情報が自動で入ります。',
                          style: TextStyle(fontSize: 12, color: Colors.orange),
                        ),
                      ),
                    if (_selectedPlaceGoogleId == null &&
                        _placeController.text.trim().isNotEmpty &&
                        suggestions.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: AppColors.blackElevated,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white12),
                        ),
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: suggestions.length,
                          separatorBuilder: (_, _) => Divider(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                          itemBuilder: (context, index) {
                            final suggestion = suggestions[index];
                            return ListTile(
                              dense: true,
                              title: Text(
                                suggestion.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              leading: const Icon(
                                Icons.place_outlined,
                                size: 18,
                                color: AppColors.orange,
                              ),
                              onTap: () => _choosePlaceSuggestion(suggestion),
                            );
                          },
                        ),
                      ),
                    if (_selectedPlaceGoogleId == null)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          '位置情報または最寄り店の解決に失敗したため、外食投稿できません。',
                          style: TextStyle(fontSize: 12, color: Colors.orange),
                        ),
                      ),
                  ],
                  TextField(
                    controller: _captionController,
                    decoration: InputDecoration(
                      labelText: 'キャプション',
                      hintText: widget.draft.note,
                    ),
                  ),
                  if (AppConfig.hasSupabase) ...[
                    const SizedBox(height: 12),
                    const Text(
                      '評価（1〜5）',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                    Slider(
                      value: (_rating ?? 3).toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      label: '${_rating ?? 3}',
                      onChanged: (v) => setState(() => _rating = v.round()),
                    ),
                    if (widget.controller.friends.isNotEmpty) ...[
                      const Text(
                        '一緒に食べた友達',
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final f in widget.controller.friends)
                            FilterChip(
                              label: Text(f.name),
                              selected: _companionIds.contains(f.id),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _companionIds.add(f.id);
                                  } else {
                                    _companionIds.remove(f.id);
                                  }
                                });
                              },
                            ),
                        ],
                      ),
                    ],
                  ],
                  if (AppConfig.hasSupabase) ...[
                    const SizedBox(height: 12),
                    const Text(
                      '種類',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                    const SizedBox(height: 6),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'restaurant', label: Text('外食')),
                        ButtonSegment(value: 'home', label: Text('自宅')),
                      ],
                      selected: {_postType},
                      onSelectionChanged: (s) {
                        setState(() => _postType = s.first);
                      },
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        '公開範囲',
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) => setState(() => _visibility = v),
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'friends', child: Text('友だちのみ')),
                          PopupMenuItem(value: 'public', child: Text('公開')),
                          PopupMenuItem(value: 'private', child: Text('非公開')),
                        ],
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_visibilityLabel()),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: actionAreaHeight),
                ],
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 12 + bottomInset,
              child: SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed:
                      (_submitting ||
                          (_postType == 'restaurant' &&
                              _selectedPlaceGoogleId == null))
                      ? null
                      : () => _onSubmitPressed(context),
                  child: _submitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('投稿する'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// MVPのための投稿詳細オーバーレイ（後続ToDoでUI精度を上げます）
class PostDetailPage extends StatefulWidget {
  const PostDetailPage({
    super.key,
    required this.post,
    required this.controller,
    required this.onClose,
    this.onPostUpdated,
  });

  final FeedPost post;
  final AppShellController controller;
  final VoidCallback onClose;
  final ValueChanged<FeedPost>? onPostUpdated;

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  late FeedPost _post;
  bool _actionBusy = false;
  final TextEditingController _commentController = TextEditingController();
  List<PostComment> _comments = [];
  bool _commentsLoading = true;
  bool _commentsExpanded = false;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    final seed = widget.post.latestComment;
    if (seed != null) {
      _comments = [seed];
      _commentsLoading = false;
    }
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _commentsLoading = true);
    final list = await controller.loadPostComments(_post.id);
    if (!mounted) return;
    setState(() {
      _comments = list;
      _commentsLoading = false;
    });
  }

  @override
  void didUpdateWidget(covariant PostDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id == widget.post.id) {
      _post = widget.post;
    }
  }

  PostComment? get _previewComment {
    if (_comments.isEmpty) return null;
    return _comments.last;
  }

  void _syncPostCommentMeta() {
    final preview = _previewComment;
    _post = _post.copyWith(
      comments: _comments.length,
      setLatestComment: true,
      latestComment: preview,
    );
    widget.onPostUpdated?.call(_post);
  }

  List<Widget> _buildCommentSection() {
    final count = _comments.isNotEmpty ? _comments.length : _post.comments;
    if (count == 0 && _comments.isEmpty) {
      return [
        Text(
          'まだコメントがありません',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 13,
          ),
        ),
      ];
    }

    final preview = _previewComment ?? _post.latestComment;
    if (preview == null) {
      return [
        Text(
          'コメントを読み込めませんでした',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 13,
          ),
        ),
      ];
    }

    if (!_commentsExpanded && count > 1) {
      return [
        PostCommentPreview(
          comment: preview,
          totalCount: count,
          onMoreTap: () => setState(() => _commentsExpanded = true),
          onDelete: preview.isMine ? () => _deleteComment(preview) : null,
        ),
      ];
    }

    final source = _comments.isNotEmpty ? _comments : [preview];
    return [
      for (final c in source)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: PostCommentPreview(
            comment: c,
            totalCount: count,
            showMoreHint: false,
            onDelete: c.isMine ? () => _deleteComment(c) : null,
          ),
        ),
    ];
  }

  AppShellController get controller => widget.controller;
  VoidCallback get onClose => widget.onClose;

  bool get _isOwnPost {
    final uid = controller.currentUserId;
    return uid != null && uid.isNotEmpty && _post.userId == uid;
  }

  Future<void> _openWebsite(BuildContext context, PlaceDetail? place) async {
    final raw =
        (((place?.websiteUrl ?? '').trim().isNotEmpty
                    ? place?.websiteUrl
                    : place?.googleMapsUrl) ??
                '')
            .trim();
    final uri = Uri.tryParse(raw);
    if (raw.isEmpty || uri == null || !uri.hasScheme) {
      _showSnack(context, '店舗サイトが見つかりません');
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) _showSnack(context, '店舗サイトを開けませんでした');
  }

  Future<void> _openGoogleMaps(BuildContext context, PlaceDetail? place) async {
    final placeName = place?.placeName ?? _post.placeName;
    final placeId = _post.placeGoogleId ?? place?.placeId ?? '';
    final rawUrl = (place?.googleMapsUrl ?? '').trim();
    final directUri = Uri.tryParse(rawUrl);
    final uri = directUri != null && directUri.hasScheme
        ? directUri
        : Uri.https('www.google.com', '/maps/search/', {
            'api': '1',
            'query': placeName,
            if (placeId.isNotEmpty) 'query_place_id': placeId,
          });
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) _showSnack(context, 'Google Mapsを開けませんでした');
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _togglePin() async {
    if (_actionBusy || !_isOwnPost) return;
    setState(() => _actionBusy = true);
    try {
      final updated = await controller.setProfilePinForPost(
        _post,
        !_post.isPinnedOnMyProfile,
      );
      setState(() => _post = updated);
      widget.onPostUpdated?.call(updated);
      if (!mounted) return;
      _showSnack(
        context,
        updated.isPinnedOnMyProfile
            ? 'プロフィールにピン留めしました'
            : 'ピン留めを外しました',
      );
    } catch (e) {
      if (mounted) _showSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _toggleLike() async {
    if (_actionBusy || controller.currentUserId == null) return;
    setState(() => _actionBusy = true);
    try {
      final updated = await controller.togglePostLikeForPost(_post);
      setState(() => _post = updated);
      widget.onPostUpdated?.call(updated);
    } catch (e) {
      if (mounted) _showSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _submitComment() async {
    final body = _commentController.text.trim();
    if (body.isEmpty || _actionBusy) return;
    setState(() => _actionBusy = true);
    try {
      final comment = await controller.addPostComment(_post.id, body);
      _commentController.clear();
      setState(() {
        _comments = [..._comments, comment];
        _commentsExpanded = true;
      });
      _syncPostCommentMeta();
    } catch (e) {
      if (mounted) _showSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _deleteComment(PostComment comment) async {
    if (_actionBusy) return;
    setState(() => _actionBusy = true);
    try {
      final remaining = _comments.where((c) => c.id != comment.id).toList();
      await controller.removePostComment(
        _post.id,
        comment.id,
        nextLatestComment: remaining.isEmpty ? null : remaining.last,
        remainingCount: remaining.length,
      );
      setState(() {
        _comments = remaining;
        if (_comments.length <= 1) _commentsExpanded = false;
      });
      _syncPostCommentMeta();
    } catch (e) {
      if (mounted) _showSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _confirmDeletePost() async {
    if (!_isOwnPost || _actionBusy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('投稿を削除'),
        content: const Text('この投稿を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _actionBusy = true);
    try {
      await controller.deletePost(_post.id);
      if (!mounted) return;
      onClose();
    } catch (e) {
      if (mounted) _showSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _toggleFavorite() async {
    if (_actionBusy || _isOwnPost) return;
    setState(() => _actionBusy = true);
    try {
      final updated = await controller.togglePostFavoriteForPost(_post);
      setState(() => _post = updated);
      widget.onPostUpdated?.call(updated);
      if (!mounted) return;
      _showSnack(
        context,
        updated.isFavoritedByMe
            ? 'お気に入りに追加しました'
            : 'お気に入りを外しました',
      );
    } catch (e) {
      if (mounted) _showSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final placeFuture = (_post.placeGoogleId ?? '').isNotEmpty
        ? controller.getPlaceDetail(_post.placeGoogleId!)
        : Future<PlaceDetail?>.value(null);
    final iconUrl = _post.userIconUrl ?? '';
    final hasNetworkIcon =
        iconUrl.isNotEmpty &&
        (iconUrl.startsWith('http://') || iconUrl.startsWith('https://'));
    final initial = _post.userName.isNotEmpty
        ? _post.userName[0].toUpperCase()
        : '?';

    return Container(
      color: AppColors.black.withValues(alpha: 0.94),
      child: SafeArea(
        top: true,
        bottom: false,
        child: FutureBuilder<PlaceDetail?>(
          future: placeFuture,
          builder: (context, snapshot) {
            final place = snapshot.data;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: onClose,
                      ),
                      const SizedBox(width: 4),
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.blackElevated,
                        backgroundImage: hasNetworkIcon
                            ? NetworkImage(iconUrl)
                            : null,
                        child: hasNetworkIcon
                            ? null
                            : Text(
                                initial,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '@${_post.userName}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_isOwnPost)
                        IconButton(
                          tooltip: _post.isPinnedOnMyProfile
                              ? 'ピン留めを外す'
                              : 'プロフィールにピン留め',
                          onPressed: _actionBusy ? null : _togglePin,
                          icon: Icon(
                            _post.isPinnedOnMyProfile
                                ? Icons.push_pin
                                : Icons.push_pin_outlined,
                            color: _post.isPinnedOnMyProfile
                                ? AppColors.orangeAccent
                                : Colors.white70,
                          ),
                        )
                      else if (controller.currentUserId != null)
                        IconButton(
                          tooltip: _post.isFavoritedByMe
                              ? 'お気に入りを外す'
                              : 'お気に入り',
                          onPressed: _actionBusy ? null : _toggleFavorite,
                          icon: Icon(
                            _post.isFavoritedByMe
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                            color: _post.isFavoritedByMe
                                ? AppColors.orangeAccent
                                : Colors.white70,
                          ),
                        ),
                      if (_isOwnPost)
                        IconButton(
                          tooltip: '投稿を削除',
                          onPressed: _actionBusy ? null : _confirmDeletePost,
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Stack(
                          children: [
                            Image.network(
                              _post.imageUrl,
                              height: 300,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                height: 300,
                                width: double.infinity,
                                color: AppColors.cardElevated,
                                alignment: Alignment.center,
                                child: const Icon(Icons.fastfood_outlined),
                              ),
                            ),
                            Positioned.fill(
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withValues(alpha: 0.35),
                                        Colors.black.withValues(alpha: 0.72),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 14,
                              right: 14,
                              bottom: 14,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    place?.placeName ?? _post.placeName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 20,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      if (_post.rating != null) ...[
                                        const Icon(
                                          Icons.star,
                                          size: 16,
                                          color: AppColors.orangeAccent,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${_post.rating}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ] else if ((place?.rating ?? 0) > 0) ...[
                                        const Icon(
                                          Icons.star,
                                          size: 16,
                                          color: AppColors.orangeAccent,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          place!.rating.toStringAsFixed(1),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                      if (_post.isHomePost) ...[
                                        const SizedBox(width: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.orange.withValues(alpha: 0.35),
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: const Text(
                                            '自炊',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      if ((place?.address ?? '').isNotEmpty)
                        Text(
                          place!.address!,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      if (place?.travelMinutes != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '徒歩 ${place!.travelMinutes}分',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _PostPlaceActionPanel(
                        place: place,
                        fallbackPlaceName: _post.placeName,
                        onOpenWebsite: () => _openWebsite(context, place),
                        onOpenGoogleMaps: () => _openGoogleMaps(context, place),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _post.caption,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          InkWell(
                            onTap: _actionBusy ? null : _toggleLike,
                            child: Row(
                              children: [
                                Icon(
                                  _post.likedByMe
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  size: 18,
                                  color: _post.likedByMe
                                      ? AppColors.orangeAccent
                                      : Colors.white.withValues(alpha: 0.85),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${_post.likes}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 18),
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 18,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${_post.comments}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_commentsLoading && _comments.isEmpty)
                        const LinearProgressIndicator(minHeight: 2)
                      else
                        ..._buildCommentSection(),
                      if (controller.currentUserId != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _commentController,
                                decoration: const InputDecoration(
                                  hintText: 'コメントを入力',
                                  isDense: true,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _actionBusy ? null : _submitComment,
                              icon: const Icon(Icons.send),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      FriendAvatarStack(
                        avatarDisplays: _post.friendAvatars,
                        maxVisible: 4,
                        avatarRadius: 16,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PostPlaceActionPanel extends StatelessWidget {
  const _PostPlaceActionPanel({
    required this.place,
    required this.fallbackPlaceName,
    required this.onOpenWebsite,
    required this.onOpenGoogleMaps,
  });

  final PlaceDetail? place;
  final String fallbackPlaceName;
  final VoidCallback onOpenWebsite;
  final VoidCallback onOpenGoogleMaps;

  @override
  Widget build(BuildContext context) {
    final websiteHost = _hostLabel(place?.websiteUrl);
    final openLabel = place?.openNow == null
        ? null
        : place!.openNow!
        ? '営業中'
        : '営業時間外';
    final placeName = (place?.placeName ?? fallbackPlaceName).trim();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.blackElevated.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.storefront_outlined,
                size: 18,
                color: AppColors.orange,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  placeName.isEmpty ? '店舗情報' : placeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              if (openLabel != null)
                Text(
                  openLabel,
                  style: TextStyle(
                    color: place!.openNow!
                        ? AppColors.orangeHighlight
                        : Colors.white70,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          if ((place?.address ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              place!.address!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (websiteHost != null) ...[
            const SizedBox(height: 6),
            Text(
              websiteHost,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.orangeHighlight,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onOpenWebsite,
                  icon: const Icon(Icons.language, size: 17),
                  label: const Text('店舗サイト'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenGoogleMaps,
                  icon: const Icon(Icons.map_outlined, size: 17),
                  label: const Text('地図'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String? _hostLabel(String? raw) {
    final uri = Uri.tryParse((raw ?? '').trim());
    final host = uri?.host;
    if (host == null || host.isEmpty) return null;
    return host.startsWith('www.') ? host.substring(4) : host;
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Text('$value', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(label),
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.urls});
  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: urls.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (_, i) => ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(urls[i], fit: BoxFit.cover),
      ),
    );
  }
}

void _showNotificationSheet(
  BuildContext context,
  List<AppNotification> notifications,
) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.blackElevated,
    builder: (_) => ListView(
      children: [
        const ListTile(
          title: Text('通知', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        ...notifications.map(
          (n) => ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: Text(n.message),
          ),
        ),
      ],
    ),
  );
}
