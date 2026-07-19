import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/location/device_location.dart';
import '../../../../core/map/prefecture_bounds.dart';
import '../../../../core/user/user_code_format.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/web/google_maps_loader.dart';
import '../../../auth/presentation/login_page.dart';
import '../../../auth/presentation/signup_page.dart';
import '../../../../core/supabase/post_submit_service.dart';
import '../../../../core/format/yen_format.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/app_entities.dart';
import '../../domain/post_visibility.dart';
import '../controllers/app_shell_controller.dart';
import '../map/map_display_config.dart';
import '../map/map_choropleth_helper.dart';
import '../widgets/floating_bottom_nav.dart';
import '../widgets/signed_in_gate_overlay.dart';
import '../widgets/friend_avatar_stack.dart';
import '../widgets/food_pin_3d_viewer.dart';
import '../widgets/map_pin_icon_preloader.dart';
import '../widgets/place_bottom_sheet.dart';
import '../widgets/friend_avatar.dart';
import '../widgets/calendar_record_view.dart';
import '../widgets/post_comment_preview.dart';
import '../widgets/profile_food_grid.dart';
import '../widgets/app_state_view.dart';
import '../widgets/report_reason_sheet.dart';
import '../widgets/segmented_tab.dart';
import 'profile_settings_page.dart';
import 'user_profile_page.dart';

class AppShellPage extends StatefulWidget {
  const AppShellPage({super.key});

  @override
  State<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends State<AppShellPage> {
  MapPin? _activePlaceSheetPin;
  FeedPost? _activePostDetail;
  String? _activeUserProfileId;
  StreamSubscription<AuthState>? _authSub;
  AppShellController? _controller;
  int? _lastAuthUserHash;
  bool _isPostEditorOpen = false;

  @override
  void initState() {
    super.initState();
    if (AppConfig.hasSupabase) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _controller = context.read<AppShellController>();
        _lastAuthUserHash =
            Supabase.instance.client.auth.currentUser?.id.hashCode;
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
    final controller = _controller;
    if (controller == null || controller.postDraft == null) return;
    unawaited(_showPostEditorSheet(controller));
  }

  void _openPostDetail(FeedPost post) {
    setState(() => _activePostDetail = post);
  }

  Future<void> _showPostEditorSheet(AppShellController controller) async {
    final draft = controller.postDraft;
    if (draft == null || _isPostEditorOpen) return;
    setState(() => _isPostEditorOpen = true);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.58),
      builder: (sheetContext) {
        final height = MediaQuery.sizeOf(sheetContext).height * 0.94;
        return Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            color: Colors.transparent,
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
                height: height,
                child: PostCreationPage(
                  draft: draft,
                  controller: controller,
                  sheetHeight: height,
                  onClose: () {
                    controller.clearPostDraft();
                    if (Navigator.of(sheetContext).canPop()) {
                      Navigator.of(sheetContext).pop();
                    }
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
    if (mounted) setState(() => _isPostEditorOpen = false);
  }

  void _closePostDetail() {
    if (_activePostDetail == null) return;
    setState(() => _activePostDetail = null);
  }

  void _openUserProfile(String userId) {
    setState(() => _activeUserProfileId = userId);
  }

  void _pushUserProfileRoute(
    BuildContext navigatorContext,
    AppShellController controller,
    String userId,
  ) {
    Navigator.of(navigatorContext).push(
      MaterialPageRoute<void>(
        builder: (profileContext) => UserProfilePage(
          userId: userId,
          controller: controller,
          onClose: () => Navigator.of(profileContext).pop(),
        ),
      ),
    );
  }

  void _closeUserProfile() {
    if (_activeUserProfileId == null) return;
    setState(() => _activeUserProfileId = null);
  }

  void _openPlaceFromPost(FeedPost post, AppShellController controller) {
    if (post.isHomePost || (post.placeGoogleId ?? '').isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('この投稿には地図上の店舗がありません')));
      return;
    }
    _closePostDetail();
    _closePlaceSheet();
    unawaited(_focusMapOnPlaceFromPost(post, controller));
  }

  Future<void> _focusMapOnPlaceFromPost(
    FeedPost post,
    AppShellController controller,
  ) async {
    final ok = await controller.focusMapOnPlace(
      post.placeGoogleId!,
      placeName: post.placeName,
    );
    if (!mounted || ok) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('地図を表示するには位置情報の許可が必要です')));
  }

  Future<void> _onBottomTabSelected(
    AppShellController controller,
    int index,
  ) async {
    if (_isPostEditorOpen) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('投稿を完了するか、閉じてから移動してください'),
        ),
      );
      return;
    }
    if (index == 1) {
      final granted = await controller.ensureMapLocationAccess();
      if (!mounted) return;
      if (!granted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('地図を表示するには位置情報の許可が必要です')));
        return;
      }
    }
    _closePlaceSheet();
    controller.changeBottomIndex(index);
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
        builder: (friendsContext) => Scaffold(
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
              onOpenProfile: (userId) =>
                  _pushUserProfileRoute(friendsContext, ctrl, userId),
            ),
          ),
        ),
      ),
    );
  }

  void _openFriendListPage(AppShellController controller) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (friendsContext) => Scaffold(
          backgroundColor: AppColors.black,
          body: SafeArea(
            child: Consumer<AppShellController>(
              builder: (_, ctrl, __) => _FriendListPage(
                friends: ctrl.friends,
                incoming: ctrl.incomingFriendRequests,
                onFollow: ctrl.followUser,
                onUnfollow: ctrl.unfollowUser,
                onOpenProfile: (userId) =>
                    _pushUserProfileRoute(friendsContext, ctrl, userId),
              ),
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
        // 起動時は全画面スピナーで待たせず、シェルを即描画する。
        // フィード読込中は _FeedTab がスケルトンを表示する。
        final pages = [
          _HomePage(
            controller: controller,
            onOpenPlaceFromPost: (post) => _openPlaceFromPost(post, controller),
            onOpenPostDetail: _openPostDetail,
            onOpenProfile: _openUserProfile,
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
          _SimpleCameraPage(
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
            summary:
                controller.recordSummary ??
                const RecordSummary(
                  streakDays: 0,
                  caloriesAvg: 0,
                  proteinAvg: 0,
                  aiSuggestion: '記録を読み込んでいます',
                  monthlyShots: [],
                ),
            controller: controller,
            onOpenPostDetail: _openPostDetail,
          ),
          _ProfilePage(
            profile:
                controller.profileOverview ??
                const ProfileOverview(
                  name: '読み込み中',
                  userCode: '',
                  bio: '',
                  avatarUrl: '',
                  followers: 0,
                  following: 0,
                  friends: 0,
                  pinnedPosts: [],
                  recentPosts: [],
                ),
            controller: controller,
            onOpenPostDetail: _openPostDetail,
            onOpenProfile: _openUserProfile,
            onOpenFriendList: () => _openFriendListPage(controller),
          ),
        ];

        final bottomOffset = _bottomNavOffset(context);

        return Scaffold(
          extendBody: true,
          resizeToAvoidBottomInset: false,
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
                  bottom: bottomOffset,
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
                  top: 0,
                  bottom: bottomOffset,
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
                        controller: controller,
                        detailFuture: controller.getPlaceDetail(pin.id),
                        scrollController: scrollController,
                        onClose: _closePlaceSheet,
                        onPostTap: (preview) async {
                          _closePlaceSheet();
                          final post =
                              controller.feedPostById(preview.id) ??
                              await controller.loadFeedPostById(preview.id);
                          if (!mounted || post == null) return;
                          _openPostDetail(post);
                        },
                      );
                    },
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
                        onOpenProfile: (userId) {
                          _closePostDetail();
                          _openUserProfile(userId);
                        },
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
            enabled: !_isPostEditorOpen,
            onTabSelected: (index) {
              unawaited(_onBottomTabSelected(controller, index));
            },
            onCameraPressed: () {
              unawaited(_onBottomTabSelected(controller, 2));
            },
          ),
        );
      },
    );
  }

  Future<void> _startNewPostFlow(
    BuildContext context,
    AppShellController controller, {
    required ImageSource source,
  }) async {
    // 画像の選択は先に行い、その後で現在地から最寄り店を補完する。
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 88,
    );
    if (file == null) return;

    final loc = await controller.ensureDeviceLocation();

    controller.setPostDraft(
      PostDraft(
        photoUrl: '',
        localImagePath: file.path,
        placeGoogleId: null,
        placeLatitude: loc?.lat,
        placeLongitude: loc?.lng,
        placeName: '',
        note: '',
        withWho: '',
        visibility: controller.profileOverview?.defaultVisibility ?? 'friends',
      ),
    );

    if (!context.mounted || controller.postDraft == null) return;
    // 投稿フォームはモーダルで開く。
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
    required this.onOpenProfile,
    required this.onOpenFriends,
    required this.onOpenDraft,
  });
  final AppShellController controller;
  final ValueChanged<FeedPost> onOpenPlaceFromPost;
  final ValueChanged<FeedPost> onOpenPostDetail;
  final ValueChanged<String> onOpenProfile;
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
          onOpenProfile: widget.onOpenProfile,
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const SizedBox(width: 48),
                    const Spacer(),
                    const SizedBox(width: 48),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.blackElevated.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.border),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Badge(
                              isLabelVisible:
                                  controller.incomingFriendRequests.isNotEmpty,
                              label: Text(
                                '${controller.incomingFriendRequests.length}',
                              ),
                              child: const Icon(Icons.people_outline),
                            ),
                            onPressed: widget.onOpenFriends,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              minimumSize: const Size(42, 42),
                              fixedSize: const Size(42, 42),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                          IconButton(
                            icon: Badge(
                              isLabelVisible:
                                  calculateNotificationBadgeCount(
                                        unreadNotificationCount:
                                            controller.unreadNotificationCount,
                                        pendingMealTagCount:
                                            controller.pendingMealTags.length,
                                      ) >
                                  0,
                              label: Text(
                                '${calculateNotificationBadgeCount(
                                  unreadNotificationCount:
                                      controller.unreadNotificationCount,
                                  pendingMealTagCount:
                                      controller.pendingMealTags.length,
                                )}',
                              ),
                              child: const Icon(Icons.notifications_none),
                            ),
                            onPressed: () async {
                              await controller.markAllNotificationsRead();
                              await controller.refreshPendingMealTags();
                              if (!context.mounted) return;
                              _showNotificationSheet(
                                context,
                                controller: controller,
                                notifications: controller.notifications,
                                pendingMealTags: controller.pendingMealTags,
                                onOpenProfile: widget.onOpenProfile,
                                onOpenPostDetail: widget.onOpenPostDetail,
                                onOpenMealTag: (tag) {
                                  Navigator.of(context).pop();
                                  controller.openMealTag(tag);
                                  widget.onOpenDraft();
                                },
                              );
                            },
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              minimumSize: const Size(42, 42),
                              fixedSize: const Size(42, 42),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (controller.pendingPostDraft != null) ...[
                  const SizedBox(height: 8),
                  Material(
                    color: AppColors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      dense: true,
                      title: const Text(
                        '投稿に失敗しました',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
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
    required this.onOpenProfile,
  });
  final List<FeedPost> feed;
  final AppShellController controller;
  final ValueChanged<FeedPost> onTapPost;
  final ValueChanged<FeedPost> onOpenPlaceFromPost;
  final ValueChanged<String> onOpenProfile;

  static int _compareFeedPostsDesc(FeedPost a, FeedPost b) {
    final aCreatedAt = a.createdAt;
    final bCreatedAt = b.createdAt;
    if (aCreatedAt == null && bCreatedAt == null) return 0;
    if (aCreatedAt == null) return 1;
    if (bCreatedAt == null) return -1;
    final createdAtCompare = bCreatedAt.compareTo(aCreatedAt);
    if (createdAtCompare != 0) return createdAtCompare;
    return b.id.compareTo(a.id);
  }

  static bool _canViewOtherPosts(List<FeedPost> myPosts) {
    if (myPosts.isEmpty) return true;
    final latest = myPosts.first.createdAt;
    if (latest == null) return true;
    return DateTime.now().difference(latest.toLocal()) <
        const Duration(hours: 24);
  }

  static List<FeedPost> _getTodayPosts(List<FeedPost> posts) {
    final today = DateTime.now();
    return posts.where((post) {
      if (post.createdAt == null) return false;
      final postDate = post.createdAt!.toLocal();
      return postDate.year == today.year &&
          postDate.month == today.month &&
          postDate.day == today.day;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final uid = controller.currentUserId;
    final sortedFeed = [...feed]..sort(_compareFeedPostsDesc);
    final myPosts = uid == null
        ? const <FeedPost>[]
        : sortedFeed.where((post) => post.userId == uid).toList();
    Widget timelineTabs() => SegmentedTab<FeedTimelineScope>(
      items: const [
        SegmentedTabItem(value: FeedTimelineScope.friends, label: '友達'),
        SegmentedTabItem(value: FeedTimelineScope.near, label: '友達の友達'),
        SegmentedTabItem(value: FeedTimelineScope.all, label: '全体'),
      ],
      selected: controller.feedTimelineScope,
      onChanged: controller.setFeedTimelineScope,
    );

    Widget emptyTimelineState({
      required String title,
      required String message,
    }) {
      return Container(
        color: AppColors.black,
        child: RefreshIndicator(
          color: AppColors.orange,
          backgroundColor: AppColors.blackElevated,
          onRefresh: controller.refreshFeed,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 126, 16, 120),
            children: [
              timelineTabs(),
              const SizedBox(height: 20),
              SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.42,
                child: AppStateView(
                  type: AppStateType.empty,
                  title: title,
                  message: message,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 初回読み込み中（まだ1件も無い）はスケルトンを表示する。
    // 「投稿がまだありません」等の空状態は loading 完了後にのみ出す。
    if (controller.loading && feed.isEmpty) {
      return Container(
        color: AppColors.black,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 126, 16, 120),
          children: [
            timelineTabs(),
            const SizedBox(height: 20),
            for (var i = 0; i < 3; i++) ...[
              const _FeedSkeletonCard(),
              if (i != 2) const SizedBox(height: 18),
            ],
          ],
        ),
      );
    }

    final isPublicTimeline =
        controller.feedTimelineScope == FeedTimelineScope.all;
    final shouldPromptFirstPost =
        uid != null && myPosts.isEmpty && !isPublicTimeline;
    if (shouldPromptFirstPost) {
      return emptyTimelineState(
        title: 'まずは最初の投稿をしてみよう',
        message: '自分の投稿が1件できると、投稿フィードが見られるようになります。',
      );
    }
    final todayMyPosts = _getTodayPosts(myPosts);
    final hasTodayMyPosts = todayMyPosts.isNotEmpty;
    final featuredPost = hasTodayMyPosts ? todayMyPosts.first : null;
    final swipeableMyPosts = todayMyPosts;
    final remainingPosts = featuredPost == null
        ? sortedFeed
        : sortedFeed.where((post) => post.id != featuredPost.id).toList();
    final remainingOtherPosts = uid == null
        ? remainingPosts
        : remainingPosts.where((post) => post.userId != uid).toList();
    final canViewOtherPosts =
        uid == null || isPublicTimeline || _canViewOtherPosts(myPosts);
    final visibleOtherPosts = canViewOtherPosts
        ? remainingOtherPosts
        : const <FeedPost>[];

    if (feed.isEmpty && !controller.loading) {
      return emptyTimelineState(
        title: '投稿がまだありません',
        message: '撮影して、みんなの「おすすめ」を広げよう。',
      );
    }
    return Container(
      color: AppColors.black,
      child: RefreshIndicator(
        color: AppColors.orange,
        backgroundColor: AppColors.blackElevated,
        onRefresh: controller.refreshFeed,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 126, 16, 120),
          children: [
            timelineTabs(),
            if (controller.feedRefreshing) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(
                minHeight: 2,
                color: AppColors.orange,
                backgroundColor: AppColors.border,
              ),
            ],
            const SizedBox(height: 20),
            if (hasTodayMyPosts) ...[
              _BerealFeaturedPanel(
                post: featuredPost!,
                myPosts: swipeableMyPosts,
                currentUserId: uid,
                controller: controller,
                onTap: () => onTapPost(featuredPost),
                onOpenPlace: () => onOpenPlaceFromPost(featuredPost),
                onTapPastPost: onTapPost,
              ),
              const SizedBox(height: 26),
            ],
            if (!canViewOtherPosts) ...[
              const _FeedRefreshLockCard(),
              const SizedBox(height: 18),
            ],
            for (var i = 0; i < visibleOtherPosts.length; i++) ...[
              _BerealFeedCard(
                post: visibleOtherPosts[i],
                currentUserId: uid,
                controller: controller,
                onTap: () => onTapPost(visibleOtherPosts[i]),
                onOpenPlace: () => onOpenPlaceFromPost(visibleOtherPosts[i]),
                onOpenProfile: onOpenProfile,
              ),
              if (i != visibleOtherPosts.length - 1) const SizedBox(height: 18),
            ],
          ],
        ),
      ),
    );
  }
}

class _FeedRefreshLockCard extends StatelessWidget {
  const _FeedRefreshLockCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.blackElevated.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.orangeAccent.withValues(alpha: 0.38),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.lock_clock_outlined,
              color: AppColors.orangeHighlight,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '投稿から24時間が経過しました',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '新しく投稿すると、友達や全体の投稿をまた見られます。',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BerealFeaturedPanel extends StatefulWidget {
  const _BerealFeaturedPanel({
    required this.post,
    required this.myPosts,
    required this.currentUserId,
    required this.controller,
    required this.onTap,
    required this.onOpenPlace,
    required this.onTapPastPost,
  });

  final FeedPost post;
  final List<FeedPost> myPosts;
  final String? currentUserId;
  final AppShellController controller;
  final VoidCallback onTap;
  final VoidCallback onOpenPlace;
  final ValueChanged<FeedPost> onTapPastPost;

  @override
  State<_BerealFeaturedPanel> createState() => _BerealFeaturedPanelState();
}

class _BerealFeaturedPanelState extends State<_BerealFeaturedPanel> {
  final TextEditingController _captionController = TextEditingController();
  final FocusNode _captionFocusNode = FocusNode();
  late final PageController _olderPostsController;
  bool _captionEditorOpen = false;
  bool _savingCaption = false;
  int _olderPostIndex = 0;

  FeedPost get _visiblePost {
    if (widget.myPosts.isEmpty) return widget.post;
    final index = _olderPostIndex.clamp(0, widget.myPosts.length - 1);
    return widget.myPosts[index];
  }

  FeedPost get _resolvedPost =>
      widget.controller.feedPostById(_visiblePost.id) ?? _visiblePost;

  String get _captionText => _resolvedPost.caption.trim();

  @override
  void initState() {
    super.initState();
    _captionController.text = widget.post.caption;
    _olderPostsController = PageController();
  }

  @override
  void didUpdateWidget(covariant _BerealFeaturedPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_captionEditorOpen) {
      final caption = _resolvedPost.caption;
      if (_captionController.text != caption) {
        _captionController.text = caption;
      }
    }
    if (oldWidget.myPosts.length != widget.myPosts.length ||
        (widget.myPosts.isNotEmpty &&
            oldWidget.myPosts.isNotEmpty &&
            oldWidget.myPosts.first.id != widget.myPosts.first.id)) {
      _olderPostIndex = 0;
      if (_olderPostsController.hasClients) {
        _olderPostsController.jumpToPage(0);
      }
    }
  }

  @override
  void dispose() {
    _olderPostsController.dispose();
    _captionFocusNode.dispose();
    _captionController.dispose();
    super.dispose();
  }

  void _openCaptionEditor() {
    if (_captionEditorOpen) {
      _captionFocusNode.requestFocus();
      return;
    }
    _captionController.text = _resolvedPost.caption;
    setState(() => _captionEditorOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _captionFocusNode.requestFocus();
    });
  }

  void _closeCaptionEditor() {
    if (!_captionEditorOpen) return;
    _captionFocusNode.unfocus();
    setState(() => _captionEditorOpen = false);
  }

  Future<void> _saveCaption() async {
    if (_savingCaption) return;
    final caption = _captionController.text.trim();
    setState(() => _savingCaption = true);
    try {
      await widget.controller.updatePostCaption(_resolvedPost, caption);
      _closeCaptionEditor();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _savingCaption = false);
    }
  }

  Widget _postImage({
    required FeedPost post,
    required double aspectRatio,
    bool showRatingOverlay = false,
  }) {
    final hasNetwork =
        post.imageUrl.startsWith('http://') ||
        post.imageUrl.startsWith('https://');
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              hasNetwork
                  ? Image.network(
                      post.imageUrl,
                      cacheWidth: 1200,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: AppColors.cardElevated,
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_outlined),
                      ),
                    )
                  : Container(
                      color: AppColors.cardElevated,
                      alignment: Alignment.center,
                      child: const Icon(Icons.image_outlined),
                    ),
              if (showRatingOverlay && post.rating != null)
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: _FiveStarRating(value: post.rating),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeLabel = _visiblePost.createdAt == null
        ? 'たった今'
        : _BerealFeedCard.formatTime(_visiblePost.createdAt!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: SizedBox(
            width: MediaQuery.sizeOf(context).width * 0.62,
            child: widget.myPosts.length == 1
                ? ListenableBuilder(
                    listenable: widget.controller,
                    builder: (context, _) {
                      final post = _resolvedPost;
                      return _postImage(
                        post: post,
                        aspectRatio: 0.86,
                        showRatingOverlay: true,
                      );
                    },
                  )
                : AspectRatio(
                    aspectRatio: 0.86,
                    child: PageView.builder(
                      controller: _olderPostsController,
                      itemCount: widget.myPosts.length,
                      onPageChanged: (index) {
                        setState(() {
                          _olderPostIndex = index;
                          if (!_captionEditorOpen) {
                            final post =
                                widget.controller.feedPostById(
                                  widget.myPosts[index].id,
                                ) ??
                                widget.myPosts[index];
                            _captionController.text = post.caption;
                          }
                        });
                      },
                      itemBuilder: (context, index) {
                        final post =
                            widget.controller.feedPostById(
                              widget.myPosts[index].id,
                            ) ??
                            widget.myPosts[index];
                        return _PastPostPreview(
                          post: post,
                          onTap: () => widget.onTapPastPost(post),
                        );
                      },
                    ),
                  ),
          ),
        ),
        if (widget.myPosts.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.swipe_rounded,
                size: 14,
                color: Colors.white38,
              ),
              const SizedBox(width: 6),
              Text(
                '写真を横にスワイプして確認 (${_olderPostIndex + 1}/${widget.myPosts.length})',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final caption = _captionText;
            final isEmpty = caption.isEmpty;
            return TextButton(
              onPressed: _openCaptionEditor,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                alignment: Alignment.centerLeft,
              ),
              child: Text(
                isEmpty ? '一言を追加...' : caption,
                style: TextStyle(
                  fontSize: isEmpty ? 16 : 18,
                  fontWeight: FontWeight.w800,
                  color: isEmpty ? AppColors.orangeHighlight : Colors.white,
                  decoration: isEmpty
                      ? TextDecoration.underline
                      : TextDecoration.none,
                  decorationColor: AppColors.orangeHighlight,
                ),
              ),
            );
          },
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: _captionEditorOpen
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.blackElevated.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border2),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _captionController,
                            focusNode: _captionFocusNode,
                            enabled: widget.currentUserId != null,
                            minLines: 1,
                            maxLines: 3,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _saveCaption(),
                            decoration: const InputDecoration(
                              hintText: '一言を入力...',
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed:
                              widget.currentUserId == null || _savingCaption
                              ? null
                              : _saveCaption,
                          icon: _savingCaption
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.orange,
                            foregroundColor: Colors.black,
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: _closeCaptionEditor,
                          icon: const Icon(Icons.close),
                          visualDensity: VisualDensity.compact,
                          style: IconButton.styleFrom(
                            foregroundColor: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                '${_visiblePost.placeName} · $timeLabel',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.62),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (!_visiblePost.isHomePost &&
                (_visiblePost.placeGoogleId ?? '').isNotEmpty)
              _MapShortcutButton(onTap: widget.onOpenPlace),
          ],
        ),
        const SizedBox(height: 6),
        ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            return _PostMetaLine(
              post: _resolvedPost,
              onLike: widget.currentUserId == null
                  ? null
                  : () => widget.controller.togglePostLikeForPost(_resolvedPost),
            );
          },
        ),
        ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            return _LatestCommentLine(
              post: _resolvedPost,
              onTap: widget.onTap,
            );
          },
        ),
      ],
    );
  }
}

class _PostMetaLine extends StatelessWidget {
  const _PostMetaLine({required this.post, this.onLike, this.onFavorite});

  final FeedPost post;
  final Future<void> Function()? onLike;
  final Future<void> Function()? onFavorite;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _FiveStarRating(value: post.rating),
        _InlinePostMetric(
          icon: post.likedByMe ? Icons.favorite : Icons.favorite_border,
          value: '${post.likes}',
          active: post.likedByMe,
          onTap: onLike == null ? null : () => unawaited(onLike!()),
        ),
        _InlinePostMetric(
          icon: post.isFavoritedByMe
              ? Icons.bookmark_rounded
              : Icons.bookmark_border_rounded,
          value: null,
          active: post.isFavoritedByMe,
          onTap: onFavorite == null ? null : () => unawaited(onFavorite!()),
        ),
      ],
    );
  }
}

class _FiveStarRating extends StatelessWidget {
  const _FiveStarRating({required this.value});

  final int? value;

  @override
  Widget build(BuildContext context) {
    final rating = value;
    if (rating == null || rating < 1) return const SizedBox.shrink();
    final clamped = rating.clamp(1, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            i <= clamped ? Icons.star_rounded : Icons.star_border_rounded,
            size: 17,
            color: i <= clamped
                ? AppColors.orangeHighlight
                : Colors.white.withValues(alpha: 0.36),
          ),
      ],
    );
  }
}

class _InlinePostMetric extends StatelessWidget {
  const _InlinePostMetric({
    required this.icon,
    required this.value,
    this.active = false,
    this.onTap,
  });

  final IconData icon;
  final String? value;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.orangeHighlight : Colors.white70;
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 22, color: color),
        if (value != null) ...[
          const SizedBox(width: 5),
          Text(
            value!,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ],
    );
    if (onTap == null) return child;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: child,
      ),
    );
  }
}

class _MapShortcutButton extends StatelessWidget {
  const _MapShortcutButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(
              Icons.map_outlined,
              size: 19,
              color: AppColors.orangeHighlight,
            ),
            SizedBox(width: 3),
            Text(
              '地図',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: AppColors.orangeHighlight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LatestCommentLine extends StatelessWidget {
  const _LatestCommentLine({required this.post, required this.onTap});

  final FeedPost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final comment = post.latestComment;
    if (comment == null || comment.body.trim().isEmpty) {
      if (post.comments <= 0) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Text(
            'コメント${post.comments}件を見る',
            style: TextStyle(
              color: AppColors.textSubtle.withValues(alpha: 0.85),
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: PostCommentPreview(
        comment: comment,
        totalCount: post.comments > 0 ? post.comments : 1,
        onMoreTap: onTap,
      ),
    );
  }
}

class _PastPostPreview extends StatelessWidget {
  const _PastPostPreview({required this.post, this.onTap});

  final FeedPost post;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasNetwork =
        post.imageUrl.startsWith('http://') ||
        post.imageUrl.startsWith('https://');
    final label = post.createdAt == null
        ? '自分の過去投稿'
        : _BerealFeedCard.formatTime(post.createdAt!);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            hasNetwork
                ? Image.network(
                    post.imageUrl,
                    cacheWidth: 1200,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: AppColors.blackElevated,
                      alignment: Alignment.center,
                      child: const Icon(Icons.image_outlined),
                    ),
                  )
                : Container(
                    color: AppColors.blackElevated,
                    alignment: Alignment.center,
                    child: const Icon(Icons.image_outlined),
                  ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.45),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              bottom: 12,
              right: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.black.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Text(
                      '自分の過去投稿 · $label',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (post.rating != null) ...[
                    const SizedBox(height: 6),
                    _FiveStarRating(value: post.rating),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// フィード読み込み中に表示する、脈打つプレースホルダーカード。
class _FeedSkeletonCard extends StatefulWidget {
  const _FeedSkeletonCard();

  @override
  State<_FeedSkeletonCard> createState() => _FeedSkeletonCardState();
}

class _FeedSkeletonCardState extends State<_FeedSkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = AppColors.blackElevated;
    Widget block({
      double? width,
      required double height,
      double radius = 8,
    }) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }

    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                block(width: 40, height: 40, radius: 999),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    block(width: 120, height: 12),
                    const SizedBox(height: 8),
                    block(width: 80, height: 10),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: block(height: 260, radius: 14),
            ),
            const SizedBox(height: 12),
            block(width: double.infinity, height: 12),
            const SizedBox(height: 8),
            block(width: 180, height: 12),
          ],
        ),
      ),
    );
  }
}

class _BerealFeedCard extends StatelessWidget {
  const _BerealFeedCard({
    required this.post,
    required this.currentUserId,
    required this.controller,
    required this.onTap,
    required this.onOpenPlace,
    this.onOpenProfile,
  });

  final FeedPost post;
  final String? currentUserId;
  final AppShellController controller;
  final VoidCallback onTap;
  final VoidCallback onOpenPlace;
  final ValueChanged<String>? onOpenProfile;

  static String formatTime(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt.toLocal());
    if (diff.inMinutes < 60) return '${diff.inMinutes.clamp(1, 59)}分前';
    if (diff.inHours < 24) return '${diff.inHours}時間前';
    if (diff.inDays < 7) return '${diff.inDays}日前';
    return '${createdAt.toLocal().month}/${createdAt.toLocal().day}';
  }

  @override
  Widget build(BuildContext context) {
    final uid = currentUserId ?? '';
    final isOwn = uid.isNotEmpty && post.userId == uid;
    final timeLabel = post.createdAt == null
        ? post.placeName
        : formatTime(post.createdAt!);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: onOpenProfile == null
                    ? null
                    : () => onOpenProfile!(post.userId),
                customBorder: const CircleBorder(),
                child: FriendAvatar(
                  displayName: post.userName,
                  avatarUrl:
                      FriendAvatar.networkUrl(post.userIconUrl) ??
                      FriendAvatar.networkUrl(
                        controller.socialStateForUser(post.userId)?.avatarUrl,
                      ),
                  radius: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            post.userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (isOwn) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.orange.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: AppColors.orangeAccent.withValues(
                                  alpha: 0.45,
                                ),
                              ),
                            ),
                            child: const Text(
                              'My Post',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: AppColors.orangeHighlight,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: onOpenPlace,
                                behavior: HitTestBehavior.opaque,
                                child: Text(
                                  '${post.placeName} · $timeLabel',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.62),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            if (!post.isHomePost &&
                                (post.placeGoogleId ?? '').isNotEmpty)
                              _MapShortcutButton(onTap: onOpenPlace),
                          ],
                        ),
                        const SizedBox(height: 5),
                        _PostMetaLine(
                          post: post,
                          onLike: currentUserId == null
                              ? null
                              : () => controller.togglePostLikeForPost(post),
                          onFavorite: currentUserId == null || isOwn
                              ? null
                              : () =>
                                    controller.togglePostFavoriteForPost(post),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!isOwn && currentUserId != null)
                PopupMenuButton<String>(
                  tooltip: 'その他',
                  icon: Icon(
                    Icons.menu_rounded,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                  onSelected: (value) async {
                    if (value == 'report') {
                      final reason = await showReportReasonSheet(
                        context,
                        targetLabel: post.userName,
                      );
                      if (reason == null || reason.isEmpty) return;
                      await controller.reportPost(post.id, reason);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('通報を送信しました')),
                        );
                      }
                    } else if (value == 'block') {
                      await controller.blockUser(post.userId);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${post.userName} をブロックしました')),
                        );
                      }
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem<String>(value: 'report', child: Text('通報する')),
                    PopupMenuItem<String>(
                      value: 'block',
                      child: Text('ブロックする'),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: AspectRatio(
              aspectRatio: 0.92,
              child: Image.network(
                post.imageUrl,
                cacheWidth: 680,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: AppColors.cardElevated,
                  alignment: Alignment.center,
                  child: const Icon(Icons.fastfood_outlined),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (post.caption.trim().isNotEmpty) ...[
            Text(
              post.caption,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 8),
          ],
          _LatestCommentLine(post: post, onTap: onTap),
        ],
      ),
    );
  }
}

class _PickPlaceConfirmSheet extends StatelessWidget {
  const _PickPlaceConfirmSheet({required this.pin});

  final MapPin pin;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom),
      decoration: BoxDecoration(
        color: AppColors.blackElevated.withValues(alpha: 0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.border2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'この店を選びますか？',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            pin.placeName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          if (pin.hasPostedActivity) ...[
            const SizedBox(height: 8),
            Text(
              pin.visitors.isNotEmpty
                  ? '${pin.visitors.length}人が訪問したお店'
                  : 'Who eats で訪問記録があるお店',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.orangeHighlight.withValues(alpha: 0.9),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 22),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'ここを選ぶ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
        ],
      ),
    );
  }
}

class _MapLocationAccessGate extends StatelessWidget {
  const _MapLocationAccessGate({required this.status, required this.onRequest});

  final DeviceLocationAccessStatus status;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final showSettings =
        status == DeviceLocationAccessStatus.deniedForever ||
        status == DeviceLocationAccessStatus.servicesDisabled;
    final title = switch (status) {
      DeviceLocationAccessStatus.servicesDisabled => '位置情報サービスがオフです',
      DeviceLocationAccessStatus.deniedForever => '位置情報の許可が必要です',
      DeviceLocationAccessStatus.denied => '位置情報の許可が必要です',
      _ => '位置情報を取得できません',
    };
    final message = switch (status) {
      DeviceLocationAccessStatus.servicesDisabled =>
        '端末の設定で位置情報サービスをオンにしてください。',
      DeviceLocationAccessStatus.deniedForever =>
        '設定アプリから Who eats の位置情報を「App使用中のみ許可」に変更してください。',
      DeviceLocationAccessStatus.denied => '近くのお店を地図に表示するために、位置情報の利用を許可してください。',
      _ => 'しばらくしてからもう一度お試しください。',
    };

    return AppStateView(
      type: AppStateType.permissionDenied,
      title: title,
      message: message,
      retryLabel: '位置情報を許可',
      onRetry: onRequest,
      secondaryActionLabel: showSettings ? '設定を開く' : null,
      onSecondaryAction: showSettings
          ? () => openDeviceLocationSettings()
          : null,
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
    this.onPickPlace,
  });
  final List<MapPin> mapPins;
  final AppShellController controller;
  final ValueChanged<MapPin> onPlaceTap;
  final ValueChanged<bool> onSearchExpansionChanged;
  final VoidCallback onEdgeSwipeBack;
  final ValueChanged<MapPin>? onPickPlace;

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
  final FocusNode _mapSearchFocusNode = FocusNode();
  Timer? _searchDebounce;
  Timer? _viewportRefreshDebounce;
  LatLng _lastCameraTarget = _defaultCenter;
  double _lastZoom = 14;
  int _displayTier = 2;
  bool _fetchingViewportPins = false;
  bool _pendingViewportRefresh = false;
  Map<String, Offset> _visible3dPinOffsets = {};
  int _projectionRequestSeq = 0;
  bool _isMapCameraMoving = false;
  Timer? _projectionDebounce;
  bool _searchExpanded = false;
  final MapChoroplethHelper _choropleth = MapChoroplethHelper();
  Set<Polygon> _choroplethPolygons = {};
  int _choroplethRefreshSeq = 0;

  /// マップ静止時は 30fps、パン/ズーム中は 15〜20fps 相当に下げる（HTML 側 `setTargetFps`）。
  static const int _pin3dFpsMapIdle = 30;
  static const int _pin3dFpsMapMoving = 17;
  final ValueNotifier<int> _pin3dAnimationFps = ValueNotifier<int>(
    _pin3dFpsMapIdle,
  );

  bool _didCenterOnDeviceLocation = false;

  bool _didBackfillMunicipalities = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onShellControllerUpdate);
    googleMapsLoadFailedNotifier.addListener(_onGoogleMapsLoadFailureChanged);
    _prepareMarkerIcons();
    // 地図タブを開いた時に初めて位置情報を解決する（起動時には走らせない）。
    unawaited(_resolveLocationThenBootstrap());
  }

  /// 地図表示に必要な位置情報を解決する。権限付与済みなら再タップ不要で取得し、
  /// 未許可の場合は build() が [_MapLocationAccessGate] を表示する。
  Future<void> _resolveLocationThenBootstrap() async {
    if (widget.controller.hasMapLocationAccess) {
      unawaited(_bootstrapMapData());
      return;
    }
    final granted = await widget.controller.ensureMapLocationAccess(
      requestIfNeeded: false,
    );
    if (!mounted) return;
    setState(() {});
    if (!granted) return;
    _didCenterOnDeviceLocation = false;
    unawaited(_bootstrapMapData());
    unawaited(_tryCenterOnDeviceLocation());
  }

  Future<void> _bootstrapMapData() async {
    await widget.controller.backfillMyPlaceMunicipalitiesIfNeeded();
    if (!mounted) return;
    await widget.controller.ensureMapPinsLoaded();
    if (!mounted) return;
    _scheduleChoroplethRefresh();
  }

  Future<void> _requestMapLocationAccess() async {
    final granted = await widget.controller.ensureMapLocationAccess();
    if (!mounted) return;
    setState(() {});
    if (!granted) return;
    _didCenterOnDeviceLocation = false;
    unawaited(_bootstrapMapData());
    unawaited(_tryCenterOnDeviceLocation());
  }

  void _onShellControllerUpdate() {
    if (!widget.controller.mapPinsLoaded && !widget.controller.mapPinsLoading) {
      unawaited(widget.controller.ensureMapPinsLoaded());
    }
    unawaited(_tryFocusPendingPlace());
    unawaited(_tryCenterOnDeviceLocation());
    _schedule3dOverlayProjection(preloadIcons: true);
    if (widget.controller.mapPinsLoaded) {
      _scheduleChoroplethRefresh();
    }
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
      _scheduleViewportRefresh();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[MapTab] center on device location failed: $e\n$st');
      }
      _didCenterOnDeviceLocation = false;
    }
  }

  @override
  void didUpdateWidget(covariant _MapTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isMapCameraMoving) return;
    if (_displayTier != MapDisplayConfig.tierIndividualPins) return;
    if (oldWidget.mapPins == widget.mapPins &&
        oldWidget.controller.postedPlaceGoogleIds ==
            widget.controller.postedPlaceGoogleIds) {
      return;
    }
    _schedule3dOverlayProjection(preloadIcons: true);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onShellControllerUpdate);
    googleMapsLoadFailedNotifier.removeListener(
      _onGoogleMapsLoadFailureChanged,
    );
    _pin3dAnimationFps.dispose();
    _searchDebounce?.cancel();
    _viewportRefreshDebounce?.cancel();
    _projectionDebounce?.cancel();
    _mapSearchFocusNode.dispose();
    _searchController.dispose();
    widget.onSearchExpansionChanged(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.controller.hasMapLocationAccess) {
      return _MapLocationAccessGate(
        status: widget.controller.mapLocationAccessStatus,
        onRequest: () => unawaited(_requestMapLocationAccess()),
      );
    }

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

    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        !AppConfig.hasAndroidMapsApiKey) {
      return const AppStateView(
        type: AppStateType.error,
        title: '地図を表示できません',
        message:
            'WHOEATS_ANDROID_MAPS_API_KEY が .env に設定されていません。\n'
            'Android 用 Maps SDK キーを設定してアプリを再ビルドしてください。',
      );
    }

    if (widget.controller.mapPinsLoading ||
        (!widget.controller.mapPinsLoaded &&
            widget.controller.mapPinsLoadError == null)) {
      return const AppStateView(
        type: AppStateType.loading,
        title: '地図を準備しています',
        message: '投稿ピンを読み込んでいます。',
      );
    }

    if (widget.controller.mapPinsLoadError != null && pins.isEmpty) {
      return AppStateView(
        type: AppStateType.error,
        title: '地図を読み込めませんでした',
        message: widget.controller.mapPinsLoadError!,
        onRetry: () => unawaited(widget.controller.ensureMapPinsLoaded()),
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
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
              Factory<OneSequenceGestureRecognizer>(
                () => EagerGestureRecognizer(),
              ),
            },
            onMapCreated: (controller) {
              _mapController = controller;
              unawaited(_tryCenterOnDeviceLocation());
              unawaited(_tryFocusPendingPlace());
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _schedule3dOverlayProjection(preloadIcons: true);
                _scheduleChoroplethRefresh();
              });
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
              final nextTier = MapDisplayConfig.tierForZoom(_lastZoom);
              if (nextTier != _displayTier) {
                setState(() {
                  _displayTier = nextTier;
                  if (nextTier != MapDisplayConfig.tierIndividualPins) {
                    _projectionRequestSeq++;
                    _visible3dPinOffsets = {};
                  }
                });
              }
              // 移動中の getScreenCoordinate は不正確なので 3D を隠し、
              // オレンジのマイクロドットだけ表示する。
              if (!_isMapCameraMoving) {
                _isMapCameraMoving = true;
                if (_visible3dPinOffsets.isNotEmpty) {
                  setState(() => _visible3dPinOffsets = {});
                }
              }
            },
            onCameraIdle: () async {
              _isMapCameraMoving = false;
              if (_pin3dAnimationFps.value != _pin3dFpsMapIdle) {
                _pin3dAnimationFps.value = _pin3dFpsMapIdle;
              }
              // カメラ停止直後は投影がずれることがあるので少し待つ。
              await Future<void>.delayed(const Duration(milliseconds: 50));
              if (!mounted || _isMapCameraMoving) return;
              if (_displayTier == MapDisplayConfig.tierIndividualPins) {
                _schedule3dOverlayProjection(preloadIcons: true);
              }
              _scheduleViewportRefresh();
              _scheduleChoroplethRefresh();
            },
            markers: _buildMapMarkers(context, pins),
            polygons: _choroplethPolygons,
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
        if (_showsMapSearchSuggestions)
          Positioned.fill(
            child: AbsorbPointer(
              child: Container(color: Colors.transparent),
            ),
          ),
        if (_searchExpanded)
          Positioned(
            top: topBarY,
            left: 24,
            right: 24,
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
                    focusNode: _mapSearchFocusNode,
                    onChanged: (value) {
                      setState(() {});
                      _onSearchChanged(value);
                    },
                    onSubmitted: (_) => _onSearchSubmitted(),
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
                  Material(
                    color: Colors.transparent,
                    elevation: 12,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
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
                              suggestion.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white),
                            ),
                            onTap: () => _selectSuggestion(suggestion),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
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

  bool get _showsMapSearchSuggestions =>
      _searchExpanded &&
      _searchController.text.trim().isNotEmpty &&
      widget.controller.placeSuggestions.isNotEmpty;

  LatLng _latLngFor(MapPin pin, int index) {
    if (pin.latitude != null && pin.longitude != null) {
      return LatLng(pin.latitude!, pin.longitude!);
    }
    return LatLng(35.6585 + (index * 0.003), 139.699 + (index * 0.0025));
  }

  Future<void> _openMapBottomSheet(BuildContext context, MapPin pin) async {
    if (!context.mounted) return;
    _log('openBottomSheet placeId=${pin.id} name=${pin.placeName}');
    if (widget.onPickPlace != null) {
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (ctx) => _PickPlaceConfirmSheet(pin: pin),
      );
      if (confirmed == true && context.mounted) {
        widget.onPickPlace!(pin);
      }
      return;
    }
    widget.onPlaceTap(pin);
  }

  void _onSearchSubmitted() {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) return;
    _searchDebounce?.cancel();
    widget.controller.searchPlaceSuggestions(keyword);
    setState(() {});
    _mapSearchFocusNode.unfocus();
  }

  MapPin _pinFromPlaceDetail(
    PlaceDetail detail, {
    required String fallbackPlaceName,
  }) {
    return MapPin(
      id: detail.placeId,
      placeName: detail.placeName.isNotEmpty
          ? detail.placeName
          : fallbackPlaceName,
      rating: detail.rating,
      friendComment: detail.friendComment,
      imageUrl: detail.imageUrl,
      isFriendVisited: false,
      hasPostedActivity: false,
      visitors: const [],
      latitude: detail.latitude,
      longitude: detail.longitude,
    );
  }

  Future<void> _animateAndOpenPlaceSheet(MapPin pin) async {
    await _animateToPin(pin);
    if (!mounted) return;
    _openMapBottomSheet(context, pin);
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
          isFriendVisited: false,
          hasPostedActivity: widget.controller.postedPlaceGoogleIds.contains(
            focus.placeGoogleId,
          ),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('店舗の位置を地図上に表示できませんでした')));
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
    if (!mounted || pin == null) return;
    widget.onPlaceTap(pin);
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    if (value.trim().isEmpty) {
      widget.controller.clearPlaceSuggestions();
      setState(() {});
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      final keyword = value.trim();
      if (keyword.isEmpty) {
        widget.controller.clearPlaceSuggestions();
      } else {
        widget.controller.searchPlaceSuggestions(keyword);
      }
      if (mounted) setState(() {});
    });
  }

  void _setSearchExpanded(bool expanded) {
    if (_searchExpanded == expanded) return;
    setState(() {
      _searchExpanded = expanded;
    });
    widget.onSearchExpansionChanged(expanded);
    if (expanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mapSearchFocusNode.requestFocus();
      });
    } else {
      _mapSearchFocusNode.unfocus();
      widget.controller.clearPlaceSuggestions();
    }
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    _searchController.text = suggestion.label;
    _searchController.selection = TextSelection.collapsed(
      offset: _searchController.text.length,
    );
    widget.controller.clearPlaceSuggestions();
    final detail = await widget.controller.getPlaceDetail(suggestion.placeId);
    final pin = widget.controller.mapPins.firstWhere(
      (p) => p.id == detail.placeId,
      orElse: () => _pinFromPlaceDetail(
        detail,
        fallbackPlaceName: suggestion.label,
      ),
    );
    _scheduleViewportRefresh();
    await _animateAndOpenPlaceSheet(pin);
  }

  Future<void> _refreshViewportPins() async {
    if (_fetchingViewportPins) {
      _pendingViewportRefresh = true;
      return;
    }
    _fetchingViewportPins = true;
    try {
      double? boundsMinLat;
      double? boundsMaxLat;
      double? boundsMinLng;
      double? boundsMaxLng;
      final map = _mapController;
      if (map != null) {
        try {
          final bounds = await map.getVisibleRegion();
          boundsMinLat = bounds.southwest.latitude;
          boundsMaxLat = bounds.northeast.latitude;
          boundsMinLng = bounds.southwest.longitude;
          boundsMaxLng = bounds.northeast.longitude;
        } catch (e, st) {
          if (kDebugMode) {
            debugPrint('[MapTab] getVisibleRegion failed: $e\n$st');
          }
        }
      }
      await widget.controller.refreshMapPinsForViewport(
        lat: _lastCameraTarget.latitude,
        lng: _lastCameraTarget.longitude,
        radiusMeters: _radiusMetersForZoom(_lastZoom),
        zoom: _lastZoom,
        boundsMinLat: boundsMinLat,
        boundsMaxLat: boundsMaxLat,
        boundsMinLng: boundsMinLng,
        boundsMaxLng: boundsMaxLng,
      );
      _schedule3dOverlayProjection(preloadIcons: true);
    } finally {
      _fetchingViewportPins = false;
      if (_pendingViewportRefresh) {
        _pendingViewportRefresh = false;
        unawaited(_refreshViewportPins());
      }
    }
  }

  void _scheduleViewportRefresh() {
    _viewportRefreshDebounce?.cancel();
    _viewportRefreshDebounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      unawaited(_refreshViewportPins());
    });
  }

  void _scheduleChoroplethRefresh() {
    unawaited(_refreshChoropleth());
  }

  Future<void> _refreshChoropleth() async {
    final seq = ++_choroplethRefreshSeq;
    final prefCodes = await _prefectureCodesForChoropleth();
    if (prefCodes.isEmpty) {
      _choropleth.clear();
      if (!mounted || seq != _choroplethRefreshSeq) return;
      setState(() => _choroplethPolygons = {});
      return;
    }

    await _choropleth.refresh(
      prefectureCodes: prefCodes,
      loadMetrics: widget.controller.loadCityChoroplethMetrics,
    );
    if (!mounted || seq != _choroplethRefreshSeq) return;
    _choropleth.mergeMetricsFromMapPins(widget.mapPins);
    setState(() {
      _choroplethPolygons = _choropleth.buildPolygons();
    });
  }

  Future<List<String>> _prefectureCodesForChoropleth() async {
    final map = _mapController;
    if (map != null) {
      try {
        final bounds = await map.getVisibleRegion();
        final sw = bounds.southwest;
        final ne = bounds.northeast;
        final codes = PrefectureBounds.prefectureCodesInBounds(
          minLat: sw.latitude < ne.latitude ? sw.latitude : ne.latitude,
          maxLat: sw.latitude > ne.latitude ? sw.latitude : ne.latitude,
          minLng: sw.longitude < ne.longitude ? sw.longitude : ne.longitude,
          maxLng: sw.longitude > ne.longitude ? sw.longitude : ne.longitude,
        );
        if (codes.isNotEmpty) return codes;
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('[MapTab] choropleth bounds failed: $e\n$st');
        }
      }
    }

    final centerCode = PrefectureBounds.prefectureCodeFor(
      _lastCameraTarget.latitude,
      _lastCameraTarget.longitude,
    );
    if (centerCode != null) return [centerCode];
    return const [];
  }

  void _schedule3dOverlayProjection({required bool preloadIcons}) {
    _projectionDebounce?.cancel();
    _projectionDebounce = Timer(const Duration(milliseconds: 80), () {
      if (!mounted) return;
      unawaited(
        _update3dOverlayPositionsForVisiblePins(preloadIcons: preloadIcons),
      );
    });
  }

  Offset? _mapPointToOverlayOffset(
    ScreenCoordinate point,
    Size viewSize,
    double devicePixelRatio,
  ) {
    var x = point.x.toDouble();
    var y = point.y.toDouble();
    // iOS の GMSMapView は論理 pt だが、端末によっては物理 px が返ることがある。
    if (x > viewSize.width + 4 || y > viewSize.height + 4) {
      x /= devicePixelRatio;
      y /= devicePixelRatio;
    }
    const margin = 220.0;
    if (x < -margin ||
        y < -margin ||
        x > viewSize.width + margin ||
        y > viewSize.height + margin) {
      return null;
    }
    return Offset(x, y);
  }

  bool _shouldApplyProjectionUpdate(int requestId) {
    return mounted &&
        !_isMapCameraMoving &&
        _displayTier == MapDisplayConfig.tierIndividualPins &&
        MapDisplayConfig.tierForZoom(_lastZoom) ==
            MapDisplayConfig.tierIndividualPins &&
        requestId == _projectionRequestSeq;
  }

  Future<void> _update3dOverlayPositionsForVisiblePins({
    bool preloadIcons = true,
  }) async {
    if (_isMapCameraMoving) return;
    if (_displayTier != MapDisplayConfig.tierIndividualPins) {
      if (!mounted || _visible3dPinOffsets.isEmpty) return;
      setState(() => _visible3dPinOffsets = {});
      return;
    }

    final controller = _mapController;
    if (controller == null) return;

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

    final viewSize = MediaQuery.sizeOf(context);
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final nextOffsets = <String, Offset>{};
    final postedIds = widget.controller.postedPlaceGoogleIds;
    try {
      for (int i = 0; i < pins.length; i++) {
        final pin = pins[i];
        if (!_isPostedPin(pin, postedIds)) continue;

        final latLng = _latLngFor(pin, i);
        final point = await controller.getScreenCoordinate(latLng);
        final offset = _mapPointToOverlayOffset(
          point,
          viewSize,
          devicePixelRatio,
        );
        if (offset != null) {
          nextOffsets[pin.id] = offset;
        }
      }

      if (nextOffsets.isEmpty) {
        if (kDebugMode) {
          debugPrint(
            '[MapTab] 3D overlay projection produced no on-screen posted pins '
            '(pins=${pins.length}, postedIds=${postedIds.length})',
          );
        }
        return;
      }

      final requestId = ++_projectionRequestSeq;
      if (!_shouldApplyProjectionUpdate(requestId)) return;

      setState(() {
        if (!_shouldApplyProjectionUpdate(requestId)) return;
        _visible3dPinOffsets = nextOffsets;
      });

      if (!preloadIcons) return;

      final iconUrls = <String>[];
      for (final pin in pins) {
        if (!nextOffsets.containsKey(pin.id)) continue;
        final iconUrl = _resolveMapPinIconUrl(pin);
        if (iconUrl != null) iconUrls.add(iconUrl);
      }
      if (iconUrls.isEmpty) return;

      await MapPinIconPreloader.preloadAll(iconUrls);
      if (!_shouldApplyProjectionUpdate(requestId)) return;
      setState(() {});
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[MapTab] getScreenCoordinate failed: $e\n$st');
      }
    }
  }

  List<Widget> _build3dPinOverlays(List<MapPin> pins) {
    if (_displayTier != MapDisplayConfig.tierIndividualPins ||
        _visible3dPinOffsets.isEmpty) {
      return const [];
    }
    final postedIds = widget.controller.postedPlaceGoogleIds;

    return [
      for (int i = 0; i < pins.length; i++)
        if (_visible3dPinOffsets.containsKey(pins[i].id) &&
            _isPostedPin(pins[i], postedIds))
          ..._buildSingle3dOverlayWithTapTarget(
            context,
            pins[i],
            isPostedPin: true,
          ),
    ];
  }

  /// 友達 → 自分の順。DB 署名 URL 失敗時は visitors / 友達一覧 / 自分プロフィールから補完。
  String? _resolveMapPinIconUrl(MapPin pin) {
    final cached = pin.mapPinIconUrl?.trim();
    if (cached != null && cached.isNotEmpty) return cached;

    for (final visitor in pin.visitors) {
      if (!_isMapPinFriendVisitor(visitor)) continue;
      final url = _avatarUrlForMapPinVisitor(visitor);
      if (url != null) return url;
    }

    final myAvatar = widget.controller.profileOverview?.avatarUrl.trim();
    for (final visitor in pin.visitors) {
      if (!visitor.isMe) continue;
      final url = visitor.avatarUrl?.trim();
      if (url != null && url.isNotEmpty) return url;
      if (myAvatar != null && myAvatar.isNotEmpty) return myAvatar;
    }

    return null;
  }

  bool _isMapPinFriendVisitor(PlaceVisitor visitor) {
    if (visitor.isFriend) return true;
    final social = widget.controller.socialStateForUser(visitor.userId);
    return social?.isFriend == true;
  }

  String? _avatarUrlForMapPinVisitor(PlaceVisitor visitor) {
    final fromVisitor = visitor.avatarUrl?.trim();
    if (fromVisitor != null && fromVisitor.isNotEmpty) return fromVisitor;

    final fromSocial = widget.controller
        .socialStateForUser(visitor.userId)
        ?.avatarUrl
        .trim();
    if (fromSocial != null && fromSocial.isNotEmpty) return fromSocial;

    return null;
  }

  bool _isPostedPin(MapPin pin, Set<String> postedIds) {
    return pin.hasPostedActivity || postedIds.contains(pin.id);
  }

  List<Widget> _buildSingle3dOverlayWithTapTarget(
    BuildContext context,
    MapPin pin, {
    required bool isPostedPin,
  }) {
    final offset = _visible3dPinOffsets[pin.id]!;
    final iconUrl = _resolveMapPinIconUrl(pin);
    final pinAssetPath = isPostedPin
        ? 'assets/3d_pin_posted.html'
        : 'assets/3d_pin.html';
    return [
      Positioned(
        left: offset.dx - 82,
        top: offset.dy - 146,
        width: 164,
        height: 180,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openMapBottomSheet(context, pin),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 7,
                top: 0,
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
                      initialIconUrl: iconUrl,
                      webviewBackground: Colors.transparent,
                      suppressFlutterFallback: true,
                      animationFpsListenable: _pin3dAnimationFps,
                    ),
                  ),
                ),
              ),
              const Positioned.fill(child: SizedBox.expand()),
            ],
          ),
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

  Set<Marker> _buildMapMarkers(BuildContext context, List<MapPin> pins) {
    if (_displayTier == MapDisplayConfig.tierIndividualPins) {
      final postedIds = widget.controller.postedPlaceGoogleIds;
      return {
        for (int i = 0; i < pins.length; i++)
          Marker(
            markerId: MarkerId(pins[i].id),
            position: _latLngFor(pins[i], i),
            icon: _markerIconForIndividualPin(
              pin: pins[i],
              postedIds: postedIds,
            ),
            zIndexInt: _isPostedPin(pins[i], postedIds) ? 1 : 0,
            onTap: () async => _openMapBottomSheet(context, pins[i]),
          ),
      };
    }

    final postedIds = widget.controller.postedPlaceGoogleIds;
    final activityPins = [
      for (int i = 0; i < pins.length; i++)
        if (_isPostedPin(pins[i], postedIds)) (index: i, pin: pins[i]),
    ];
    if (activityPins.isEmpty) return const {};

    final grouped = <String, List<({int index, MapPin pin})>>{};
    final cellSize = _clusterCellSizeForZoom(_lastZoom);
    for (final entry in activityPins) {
      final latLng = _latLngFor(entry.pin, entry.index);
      final row = (latLng.latitude / cellSize).floor();
      final col = (latLng.longitude / cellSize).floor();
      final key = '$row:$col';
      grouped.putIfAbsent(key, () => <({int index, MapPin pin})>[]).add(entry);
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

  Marker _buildClusterMarker(
    String key,
    List<({int index, MapPin pin})> entries,
  ) {
    var latSum = 0.0;
    var lngSum = 0.0;
    for (final entry in entries) {
      latSum += entry.pin.latitude ?? 0;
      lngSum += entry.pin.longitude ?? 0;
    }
    final visitedCount = entries.length;
    final center = LatLng(latSum / visitedCount, lngSum / visitedCount);
    final icon = _clusterIconFor(total: visitedCount, visited: visitedCount);
    final firstPin = entries.first.pin;
    return Marker(
      markerId: MarkerId('cluster_$key'),
      position: center,
      icon:
          icon ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      zIndexInt: 3,
      infoWindow: InfoWindow(
        title: '訪問記録あり: $visitedCount件',
        snippet: 'この範囲の投稿店舗: $visitedCount店',
        onTap: () => _animateToPin(firstPin),
      ),
      onTap: () => _animateToPin(firstPin),
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
      size: _displayTier == MapDisplayConfig.tierBroadClusters ? 92 : 76,
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

  BitmapDescriptor _markerIconForIndividualPin({
    required MapPin pin,
    required Set<String> postedIds,
  }) {
    final isPosted = _isPostedPin(pin, postedIds);
    if (isPosted) {
      return _visitedMarkerIcon ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    }
    return _unvisitedMarkerIcon ??
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
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
    final baseColor = visited > 0
        ? AppColors.orange
        : AppColors.gray.withValues(alpha: 0.85);

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
        center.dy - textPainter.height / 2,
      ),
    );

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
              '友達申請',
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
                  hintText: 'ユーザー名 / @user_codeで検索',
                  prefixIcon: const Icon(Icons.search, color: Colors.white70),
                  suffixIcon: _searchController.text.trim().isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () {
                            _searchController.clear();
                            widget.controller.clearUserCodeSearch();
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
          ],

          Expanded(
            child: FriendSearchPage(
              query: _searchController.text.trim(),
              incoming: widget.incoming,
              outgoing: widget.outgoing,
              candidates: widget.recommendations,
              onBack: () => setState(() => _searchByConnection = false),
              onFriendTap: _onFriendTap,
              onFollow: widget.onFollow,
              onUnfollow: widget.onUnfollow,
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
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
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
                avatarUrl: FriendAvatar.networkUrl(item.avatarUrl),
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
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 友達申請: フォロー返し・承認待ち・おすすめ候補（🔶タグ行のみモック）。
class FriendSearchPage extends StatelessWidget {
  const FriendSearchPage({
    super.key,
    required this.query,
    required this.incoming,
    required this.outgoing,
    required this.candidates,
    required this.onBack,
    required this.onFriendTap,
    required this.onFollow,
    required this.onUnfollow,
  });

  final String query;
  final List<FriendCandidate> incoming;
  final List<FriendCandidate> outgoing;
  final List<FriendCandidate> candidates;
  final VoidCallback onBack;
  final ValueChanged<FriendCandidate> onFriendTap;
  final Future<bool> Function(String userId) onFollow;
  final Future<void> Function(String userId) onUnfollow;

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = query.trim().toLowerCase();
    final q = normalizedQuery.replaceFirst('@', '');
    final recommendedCandidates = candidates;
    final remoteMatches = normalizedQuery.isEmpty
        ? const <FriendCandidate>[]
        : context.read<AppShellController>().userCodeSearchResults;
    final searchPool = <FriendCandidate>[
      ...recommendedCandidates,
      ...remoteMatches,
    ];
    final searchResults =
        normalizedQuery.isEmpty
              ? <FriendCandidate>[]
              : List<FriendCandidate>.from(
                  searchPool.where((c) {
                    final name = c.name.toLowerCase();
                    final code = c.name.toLowerCase().replaceFirst('@', '');
                    return name.startsWith(normalizedQuery) ||
                        name.contains(normalizedQuery) ||
                        code.startsWith(q) ||
                        code.contains(q);
                  }),
                )
          ..sort((a, b) => b.mutualCount.compareTo(a.mutualCount));
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
          ...incoming.map(
            (c) => _FriendCandidateRow(
              candidate: c,
              onFriendTap: onFriendTap,
              onFollow: onFollow,
              onUnfollow: onUnfollow,
            ),
          ),
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
          ...outgoing.map(
            (c) => _FriendCandidateRow(
              candidate: c,
              onFriendTap: onFriendTap,
              onFollow: onFollow,
              onUnfollow: onUnfollow,
            ),
          ),
          const SizedBox(height: 18),
        ],
        if (normalizedQuery.isNotEmpty) ...[
          const SizedBox(height: 18),
          const Text(
            '検索結果',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          if (searchResults.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '該当するユーザーがいません',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
              ),
            )
          else
            ...searchResults.map(
              (c) => _FriendCandidateRow(
                candidate: c,
                onFriendTap: onFriendTap,
                onFollow: onFollow,
                onUnfollow: onUnfollow,
              ),
            ),
        ],

        if (normalizedQuery.isEmpty) ...[
          const SizedBox(height: 18),
          const Text(
            '候補一覧',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          if (recommendedCandidates.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '候補はまだありません',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
              ),
            )
          else
            ...recommendedCandidates.map(
              (c) => _FriendCandidateRow(
                candidate: c,
                onFriendTap: onFriendTap,
                onFollow: onFollow,
                onUnfollow: onUnfollow,
              ),
            ),
        ],
      ],
    );
  }
}

class _FriendListPage extends StatelessWidget {
  const _FriendListPage({
    required this.friends,
    required this.incoming,
    required this.onFollow,
    required this.onUnfollow,
    required this.onOpenProfile,
  });

  final List<FriendCandidate> friends;
  final List<FriendCandidate> incoming;
  final Future<bool> Function(String userId) onFollow;
  final Future<void> Function(String userId) onUnfollow;
  final ValueChanged<String> onOpenProfile;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 4),
              const Text(
                '友達一覧',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        if (incoming.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Text(
              'あなたへの申請',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ...incoming.map(
            (c) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _FriendCandidateRow(
                candidate: c,
                onFriendTap: (item) => onOpenProfile(item.id),
                onFollow: onFollow,
                onUnfollow: onUnfollow,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (friends.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Text(
              '友達',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          FriendGrid(
            candidates: friends,
            onFriendTap: (c) => onOpenProfile(c.id),
          ),
        ],
        if (friends.isEmpty && incoming.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: AppStateView(
              type: AppStateType.empty,
              title: '友達がいません',
              message: 'プロフィールから友達申請を送ってみましょう。',
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
              avatarUrl: FriendAvatar.networkUrl(c.avatarUrl),
              radius: 20,
              showStatusDot: c.isFriend || c.theyFollowMe || c.mutualCount > 0,
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

class _SimpleCameraPage extends StatelessWidget {
  const _SimpleCameraPage({
    required this.onShot,
    required this.onGalleryPressed,
  });

  final VoidCallback onShot;
  final VoidCallback onGalleryPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
        child: Column(
          children: [
            const Spacer(),
            Text(
              '投稿を始める',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'カメラかギャラリーを選んでください',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSubtle),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: onShot,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('カメラ'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                onPressed: onGalleryPressed,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('ギャラリー'),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
class _CameraPage extends StatelessWidget {
  const _CameraPage({required this.onShot, required this.onGalleryPressed});
  final VoidCallback onShot;
  final VoidCallback onGalleryPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.9),
                  radius: 1.25,
                  colors: [
                    AppColors.orange.withValues(alpha: 0.20),
                    AppColors.black,
                  ],
                  stops: const [0.0, 0.75],
                ),
              ),
            ),
          ),
          Positioned(
            top: -26,
            right: -26,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.orange.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            bottom: -44,
            left: -36,
            child: Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.orangeAccent.withValues(alpha: 0.09),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Text(
                  '投稿を始める',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'カメラで新しく撮るか、ギャラリーから選んでそのまま編集へ。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSubtle,
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 430),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.cardElevated.withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.30),
                            blurRadius: 30,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _CameraChoiceTile(
                            icon: Icons.photo_camera_outlined,
                            title: 'カメラで撮る',
                            description: 'その場で撮ってすぐ投稿へ進む',
                            accent: AppColors.orange,
                            onTap: onShot,
                          ),
                          const SizedBox(height: 14),
                          _CameraChoiceTile(
                            icon: Icons.photo_library_outlined,
                            title: 'ギャラリーから選ぶ',
                            description: '過去の写真を選んで投稿に使う',
                            accent: AppColors.orangeAccent,
                            onTap: onGalleryPressed,
                          ),
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.auto_awesome,
                                  color: AppColors.orangeAccent.withValues(
                                    alpha: 0.95,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    '選んだあと、そのまま編集画面へ進みます',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '撮影後に戻らず、そのまま編集へ進めます。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textInactive,
                    height: 1.35,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraChoiceTile extends StatelessWidget {
  const _CameraChoiceTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.24),
                Colors.white.withValues(alpha: 0.03),
              ],
            ),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.2),
                ),
                child: Icon(icon, color: accent, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.68),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white.withValues(alpha: 0.72),
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
        companionAvatars: entry.companionNames,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox.expand(
        child: CalendarRecordView(
          summary: summary,
          loadDayEntries: controller.loadPostsForDay,
          onOpenPost: _openEntry,
        ),
      ),
    );
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage({
    required this.profile,
    required this.controller,
    required this.onOpenPostDetail,
    required this.onOpenProfile,
    required this.onOpenFriendList,
  });
  final ProfileOverview profile;
  final AppShellController controller;
  final ValueChanged<FeedPost> onOpenPostDetail;
  final ValueChanged<String> onOpenProfile;
  final VoidCallback onOpenFriendList;

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

  void _openThumb(
    BuildContext context,
    ProfilePostThumb thumb, {
    required bool pinned,
  }) {
    onOpenPostDetail(_postFromThumb(thumb, pinned: pinned));
  }

  @override
  Widget build(BuildContext context) {
    final initial = profile.name.isNotEmpty
        ? profile.name.characters.first.toUpperCase()
        : '?';
    final postCount = profile.recentPosts.length;
    final streakDays = controller.recordSummary?.streakDays ?? 0;

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
                        onOpenProfile: onOpenProfile,
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
                        UserCodeFormat.display(profile.userCode),
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
                child: _StatTile(label: '投稿数', value: postCount),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(label: '連続記録日数', value: streakDays),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  label: '友達',
                  value: profile.friends,
                  onTap: onOpenFriendList,
                ),
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
                              cacheWidth: 224,
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
                      '訪問した人',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Text(
                      '${pin.visitors.length} 人',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (pin.visitors.isEmpty)
                  Text(
                    '訪問した人はまだいません',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  )
                else
                  SizedBox(
                    height: 42,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: pin.visitors.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final visitor = pin.visitors[i];
                        return FriendAvatar(
                          displayName: visitor.userName,
                          avatarUrl: FriendAvatar.networkUrl(visitor.avatarUrl),
                          radius: 20,
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
                          cacheWidth: 280,
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

class _CompanionPickerSheet extends StatefulWidget {
  const _CompanionPickerSheet({
    required this.friends,
    required this.initialSelection,
  });

  final List<FriendCandidate> friends;
  final Set<String> initialSelection;

  @override
  State<_CompanionPickerSheet> createState() => _CompanionPickerSheetState();
}

class _CompanionPickerSheetState extends State<_CompanionPickerSheet> {
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.initialSelection);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.55;
    return SafeArea(
      child: SizedBox(
        height: maxHeight,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + bottomInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '一緒に食べた友達',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(_selected),
                    child: const Text('完了'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Expanded(
                child: ListView.separated(
                  itemCount: widget.friends.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  itemBuilder: (context, index) {
                    final friend = widget.friends[index];
                    final checked = _selected.contains(friend.id);
                    return CheckboxListTile(
                      value: checked,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selected.add(friend.id);
                          } else {
                            _selected.remove(friend.id);
                          }
                        });
                      },
                      secondary: FriendAvatar(
                        displayName: friend.name,
                        avatarUrl: friend.avatarUrl,
                        radius: 20,
                      ),
                      title: Text(friend.name),
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
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
  late final TextEditingController _priceController;
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
    _priceController = TextEditingController(
      text: widget.draft.priceYen == null ? '' : '${widget.draft.priceYen}',
    );
    _localImagePath = widget.draft.localImagePath;
    _photoUrl = widget.draft.photoUrl;
    _selectedPlaceGoogleId = widget.draft.placeGoogleId;
    _selectedPlaceLat = widget.draft.placeLatitude;
    _selectedPlaceLng = widget.draft.placeLongitude;
    _selectedPlaceName = widget.draft.placeName;
    _postType = widget.draft.postType;
    _visibility = PostVisibility.normalize(widget.draft.visibility);
    _rating = widget.draft.rating ?? 3;
    _companionIds.addAll(widget.draft.companionUserIds);
  }

  @override
  void dispose() {
    _placeSearchDebounce?.cancel();
    _captionController.dispose();
    _placeController.dispose();
    _priceController.dispose();
    super.dispose();
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
      priceYen: parseYenInput(_priceController.text),
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
          : suggestion.label;
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
      _placeController.text = suggestion.label;
      _selectedPlaceGoogleId = suggestion.placeId;
      _selectedPlaceLat = null;
      _selectedPlaceLng = null;
      _selectedPlaceName = suggestion.label;
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

  void _applyResolvedPlace({
    required String placeId,
    required String placeName,
    required double? latitude,
    required double? longitude,
  }) {
    _suppressPlaceChange = true;
    _placeController.text = placeName;
    _selectedPlaceGoogleId = placeId;
    _selectedPlaceLat = latitude;
    _selectedPlaceLng = longitude;
    _selectedPlaceName = placeName;
    _clearPlaceSuggestions();
    setState(() {});
    unawaited(
      Future<void>.delayed(Duration.zero, () {
        if (mounted) _suppressPlaceChange = false;
      }),
    );
  }

  Future<void> _choosePlaceFromMap(BuildContext context) async {
    if (_resolvingPlace) return;
    final picked = await showModalBottomSheet<MapPin>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.58),
      builder: (sheetContext) {
        final height = MediaQuery.sizeOf(sheetContext).height * 0.88;
        return Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            color: Colors.transparent,
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Material(
              color: const Color(0xFF09090A),
              child: SizedBox(
                height: height,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              '地図から店を選ぶ',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            color: Colors.white70,
                            onPressed: () => Navigator.of(sheetContext).pop(),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Text(
                        'ピンをタップして店名を確認し、「ここを選ぶ」で決定してください。',
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ),
                    Expanded(
                      child: _MapTab(
                        mapPins: widget.controller.mapPins,
                        controller: widget.controller,
                        onPlaceTap: (_) {},
                        onSearchExpansionChanged: (_) {},
                        onEdgeSwipeBack: () =>
                            Navigator.of(sheetContext).maybePop(),
                        onPickPlace: (pin) =>
                            Navigator.of(sheetContext).pop(pin),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() => _resolvingPlace = true);
    try {
      final detail = await widget.controller.getPlaceDetail(picked.id);
      if (!mounted) return;
      final resolvedName = detail.placeName.isNotEmpty
          ? detail.placeName
          : picked.placeName;
      _applyResolvedPlace(
        placeId: detail.placeId,
        placeName: resolvedName,
        latitude: detail.latitude,
        longitude: detail.longitude,
      );
    } catch (_) {
      if (!mounted) return;
      _applyResolvedPlace(
        placeId: picked.id,
        placeName: picked.placeName,
        latitude: picked.latitude,
        longitude: picked.longitude,
      );
    } finally {
      if (mounted) setState(() => _resolvingPlace = false);
    }
  }

  Future<void> _openCompanionPicker() async {
    final friends = widget.controller.friends;
    if (friends.isEmpty) return;
    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.blackElevated,
      builder: (sheetContext) {
        return _CompanionPickerSheet(
          friends: friends,
          initialSelection: Set<String>.from(_companionIds),
        );
      },
    );
    if (!mounted || selected == null) return;
    setState(() {
      _companionIds
        ..clear()
        ..addAll(selected);
    });
  }

  String _selectedCompanionNames() {
    final byId = {
      for (final friend in widget.controller.friends) friend.id: friend.name,
    };
    return _companionIds
        .map((id) => byId[id] ?? 'ユーザー')
        .join('、');
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('店名を選択してください')));
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
          restaurantPlaceLatitude: _postType == 'restaurant'
              ? _selectedPlaceLat
              : null,
          restaurantPlaceLongitude: _postType == 'restaurant'
              ? _selectedPlaceLng
              : null,
          caption: _captionController.text.trim().isEmpty
              ? null
              : _captionController.text.trim(),
          rating: _rating,
          priceYen: parseYenInput(_priceController.text),
          mealGroupId: widget.draft.mealGroupId,
          companionUserIds: _companionIds.toList(),
        );
        if (!context.mounted) return;
        widget.controller.clearPostDraft();
        widget.controller.clearPendingPostDraft();
        await widget.controller.refreshPendingMealTags();
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
    final actionAreaHeight = 92.0 + bottomInset;
    final suggestions = widget.controller.placeSuggestions;
    final isRestaurant = _postType == 'restaurant';
    final orangeBorder = AppColors.orange.withValues(alpha: 0.42);
    final labelStyle = TextStyle(
      fontSize: 12,
      color: AppColors.orangeAccent.withValues(alpha: 0.92),
      fontWeight: FontWeight.w700,
    );
    final segmentedStyle = ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.orange;
        return AppColors.blackElevated.withValues(alpha: 0.85);
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.black;
        return AppColors.orangeHighlight;
      }),
      side: WidgetStateProperty.all(BorderSide(color: orangeBorder)),
    );
    return PopScope(
      canPop: !_submitting,
      child: Theme(
        data: Theme.of(context).copyWith(
        sliderTheme: SliderTheme.of(context).copyWith(
          activeTrackColor: AppColors.orange,
          inactiveTrackColor: AppColors.orange.withValues(alpha: 0.22),
          thumbColor: AppColors.orangeAccent,
          overlayColor: AppColors.orange.withValues(alpha: 0.16),
        ),
        chipTheme: ChipTheme.of(context).copyWith(
          selectedColor: AppColors.orange.withValues(alpha: 0.28),
          checkmarkColor: AppColors.orangeHighlight,
          side: BorderSide(color: orangeBorder),
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.orangeHighlight,
            side: BorderSide(color: orangeBorder),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.orange,
            foregroundColor: Colors.black,
            disabledBackgroundColor: AppColors.orange.withValues(alpha: 0.35),
          ),
        ),
      ),
        child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF151517), Color(0xFF09090A)],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SizedBox(
            height:
                widget.sheetHeight ?? MediaQuery.of(context).size.height * 0.72,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, actionAreaHeight),
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              color: AppColors.orangeAccent.withValues(
                                alpha: 0.9,
                              ),
                            ),
                            onPressed: _submitting ? null : widget.onClose,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            '投稿を作成',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('種類', style: labelStyle),
                      const SizedBox(height: 6),
                      SegmentedButton<String>(
                        style: segmentedStyle,
                        segments: const [
                          ButtonSegment(value: 'restaurant', label: Text('外食')),
                          ButtonSegment(value: 'home', label: Text('自炊')),
                        ],
                        selected: {_postType},
                        onSelectionChanged: (s) {
                          setState(() => _postType = s.first);
                        },
                      ),
                      const SizedBox(height: 12),
                      Text('公開範囲', style: labelStyle),
                      const SizedBox(height: 6),
                      SegmentedButton<String>(
                        style: segmentedStyle,
                        segments: const [
                          ButtonSegment(
                            value: PostVisibility.friends,
                            label: Text('友達'),
                          ),
                          ButtonSegment(
                            value: PostVisibility.near,
                            label: Text('友達の友達'),
                          ),
                          ButtonSegment(
                            value: PostVisibility.public_,
                            label: Text('公開'),
                          ),
                        ],
                        selected: {PostVisibility.normalize(_visibility)},
                        onSelectionChanged: (s) {
                          setState(
                            () => _visibility = PostVisibility.normalize(s.first),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        PostVisibility.postEditorDescription(_visibility),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.orangeAccent.withValues(alpha: 0.75),
                        ),
                      ),
                      const SizedBox(height: 12),
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
                                        color: AppColors.gray.withValues(
                                          alpha: 0.35,
                                        ),
                                        alignment: Alignment.center,
                                        child: Icon(
                                          Icons.photo_outlined,
                                          size: 42,
                                          color: AppColors.orangeAccent.withValues(
                                            alpha: 0.85,
                                          ),
                                        ),
                                      )),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _replaceImage(ImageSource.camera),
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: const Text('再撮影'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (isRestaurant) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _placeController,
                              onChanged: _onPlaceChanged,
                              decoration: InputDecoration(
                                labelText: '店名',
                                hintText: '店名を入力',
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
                                                  Future<void>.delayed(
                                                    Duration.zero,
                                                    () {
                                                      if (mounted) {
                                                        _suppressPlaceChange =
                                                            false;
                                                      }
                                                    },
                                                  ),
                                                );
                                              },
                                            )
                                          : null),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 56,
                            child: FilledButton.tonalIcon(
                              onPressed: _resolvingPlace
                                  ? null
                                  : () => _choosePlaceFromMap(context),
                              icon: const Icon(Icons.map_outlined),
                              label: const Text('地図から選ぶ'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '入力か地図選択で店名と位置情報を入れられます。',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.orangeAccent.withValues(alpha: 0.75),
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
                            border: Border.all(color: orangeBorder),
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
                                  suggestion.label,
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
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: _captionController,
                      decoration: const InputDecoration(
                        labelText: '一言',
                        hintText: '一言を入力...',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '金額（任意）',
                        hintText: '例: 1280',
                        prefixText: '¥ ',
                        helperText: '未入力でも投稿できます',
                      ),
                    ),
                    if (AppConfig.hasSupabase) ...[
                      const SizedBox(height: 12),
                      Text('評価（1〜5）', style: labelStyle),
                      Slider(
                        value: (_rating ?? 3).toDouble(),
                        min: 1,
                        max: 5,
                        divisions: 4,
                        label: '${_rating ?? 3}',
                        onChanged: (v) => setState(() => _rating = v.round()),
                      ),
                      if (widget.controller.friends.isNotEmpty) ...[
                        OutlinedButton.icon(
                          onPressed: _openCompanionPicker,
                          icon: const Icon(Icons.person_add_alt_1_outlined),
                          label: Text(
                            _companionIds.isEmpty
                                ? 'タグづけ'
                                : 'タグづけ (${_companionIds.length})',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.orangeHighlight,
                            side: BorderSide(color: orangeBorder),
                          ),
                        ),
                        if (_companionIds.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            '選択: ${_selectedCompanionNames()}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.orangeAccent.withValues(
                                alpha: 0.75,
                              ),
                            ),
                          ),
                        ],
                      ] else ...[
                        Text(
                          '友達を追加すると、一緒に食べた人をタグできます',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.orangeAccent.withValues(
                              alpha: 0.75,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    minimum: const EdgeInsets.only(bottom: 12),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFF09090A).withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: orangeBorder),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: SizedBox(
                          height: 48,
                          child: FilledButton(
                            onPressed:
                                (_submitting ||
                                    (isRestaurant &&
                                        _selectedPlaceGoogleId == null))
                                ? null
                                : () => _onSubmitPressed(context),
                            child: _submitting
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
                                  )
                                : const Text('投稿する'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _PostEditResult {
  const _PostEditResult({
    required this.caption,
    required this.rating,
    required this.priceYen,
  });

  final String caption;
  final int rating;
  final int? priceYen;
}

class _PostEditBottomSheet extends StatefulWidget {
  const _PostEditBottomSheet({required this.post});

  final FeedPost post;

  @override
  State<_PostEditBottomSheet> createState() => _PostEditBottomSheetState();
}

class _PostEditBottomSheetState extends State<_PostEditBottomSheet> {
  late final TextEditingController _captionController;
  late final TextEditingController _priceController;
  late int _rating;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController(text: widget.post.caption);
    _priceController = TextEditingController(
      text: widget.post.priceYen == null ? '' : '${widget.post.priceYen}',
    );
    _rating = widget.post.rating ?? 3;
  }

  @override
  void dispose() {
    _captionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    Navigator.of(context).pop(
      _PostEditResult(
        caption: _captionController.text.trim(),
        rating: _rating,
        priceYen: parseYenInput(_priceController.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '投稿を編集',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _captionController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '一言',
              hintText: '一言を入力...',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _priceController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '金額（任意）',
              hintText: '例: 1280',
              prefixText: '¥ ',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '評価（1〜5）',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          Slider(
            value: _rating.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            label: '$_rating',
            onChanged: _saving ? null : (v) => setState(() => _rating = v.round()),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存する'),
          ),
        ],
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
    this.onOpenProfile,
  });

  final FeedPost post;
  final AppShellController controller;
  final VoidCallback onClose;
  final ValueChanged<FeedPost>? onPostUpdated;
  final ValueChanged<String>? onOpenProfile;

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

  Future<void> _loadComments({bool expand = false}) async {
    setState(() => _commentsLoading = true);
    final list = await controller.loadPostComments(_post.id);
    if (!mounted) return;
    setState(() {
      _comments = list;
      _commentsLoading = false;
      if (expand || list.length > 1) {
        _commentsExpanded = true;
      }
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

  Future<void> _openComments() async {
    if (_commentsExpanded && _comments.isNotEmpty) return;
    if (_comments.isEmpty) {
      await _loadComments(expand: true);
      return;
    }
    setState(() => _commentsExpanded = true);
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
        GestureDetector(
          onTap: _openComments,
          behavior: HitTestBehavior.opaque,
          child: Text(
            'コメント$count件を見る',
            style: TextStyle(
              color: AppColors.textSubtle.withValues(alpha: 0.85),
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ];
    }

    if (!_commentsExpanded && count > 1) {
      return [
        PostCommentPreview(
          comment: preview,
          totalCount: count,
          onMoreTap: _openComments,
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
        updated.isPinnedOnMyProfile ? 'プロフィールにピン留めしました' : 'ピン留めを外しました',
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

  Future<void> _openPostEditor() async {
    if (_actionBusy || !_isOwnPost) return;
    final result = await showModalBottomSheet<_PostEditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.blackElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _PostEditBottomSheet(post: _post),
    );
    if (result == null || !mounted) return;
    setState(() => _actionBusy = true);
    try {
      final updated = await controller.updatePostDetails(
        _post,
        caption: result.caption,
        rating: result.rating,
        priceYen: result.priceYen,
      );
      if (!mounted) return;
      setState(() => _post = updated);
      widget.onPostUpdated?.call(updated);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('投稿を更新しました')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新に失敗しました: $e')));
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

  Future<void> _reportPost() async {
    if (_actionBusy || _isOwnPost) return;
    final reason = await showReportReasonSheet(
      context,
      targetLabel: _post.userName,
    );
    if (reason == null || reason.isEmpty) return;
    setState(() => _actionBusy = true);
    try {
      await controller.reportPost(_post.id, reason);
      if (!mounted) return;
      _showSnack(context, '通報を送信しました');
    } catch (e) {
      if (mounted) _showSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _blockAuthor() async {
    if (_actionBusy || _isOwnPost) return;
    setState(() => _actionBusy = true);
    try {
      await controller.blockUser(_post.userId);
      if (!mounted) return;
      _showSnack(context, '${_post.userName} をブロックしました');
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
        updated.isFavoritedByMe ? 'お気に入りに追加しました' : 'お気に入りを外しました',
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
    final iconUrl =
        FriendAvatar.networkUrl(_post.userIconUrl) ??
        FriendAvatar.networkUrl(
          controller.socialStateForUser(_post.userId)?.avatarUrl,
        );

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
                      InkWell(
                        onTap: widget.onOpenProfile == null
                            ? null
                            : () => widget.onOpenProfile!.call(_post.userId),
                        customBorder: const CircleBorder(),
                        child: FriendAvatar(
                          displayName: _post.userName,
                          avatarUrl: iconUrl,
                          radius: 18,
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
                          tooltip: _post.isFavoritedByMe ? 'お気に入りを外す' : 'お気に入り',
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
                          tooltip: '投稿を編集',
                          onPressed: _actionBusy ? null : _openPostEditor,
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: Colors.white70,
                          ),
                        ),
                      if (_isOwnPost)
                        IconButton(
                          tooltip: '投稿を削除',
                          onPressed: _actionBusy ? null : _confirmDeletePost,
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                        ),
                      if (!_isOwnPost && controller.currentUserId != null)
                        PopupMenuButton<String>(
                          tooltip: 'その他',
                          icon: const Icon(Icons.menu_rounded),
                          onSelected: (value) {
                            if (value == 'report') {
                              unawaited(_reportPost());
                            } else if (value == 'block') {
                              unawaited(_blockAuthor());
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem<String>(
                              value: 'report',
                              child: Text('通報する'),
                            ),
                            PopupMenuItem<String>(
                              value: 'block',
                              child: Text('ブロックする'),
                            ),
                          ],
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
                              child: Row(
                                children: [
                                  if (_post.isHomePost)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.orange.withValues(
                                          alpha: 0.35,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: const Text(
                                        '自炊',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  if (_post.priceYen != null) ...[
                                    if (_post.isHomePost) const SizedBox(width: 10),
                                    Text(
                                      formatYen(_post.priceYen),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_post.rating != null) ...[
                        const SizedBox(height: 8),
                        _FiveStarRating(value: _post.rating),
                      ],
                      if (!_post.isHomePost) ...[
                        const SizedBox(height: 10),
                        _PostPlaceLinksRow(
                          placeName: place?.placeName ?? _post.placeName,
                          hasWebsite:
                              ((place?.websiteUrl ?? '').trim().isNotEmpty) ||
                              ((place?.googleMapsUrl ?? '').trim().isNotEmpty),
                          onOpenWebsite: () => _openWebsite(context, place),
                          onOpenGoogleMaps: () =>
                              _openGoogleMaps(context, place),
                        ),
                        const SizedBox(height: 10),
                      ],
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.blackElevated.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.border2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '一言',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.orangeHighlight,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _post.caption.trim().isEmpty
                                  ? '一言を追加...'
                                  : _post.caption,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                height: 1.25,
                              ),
                            ),
                          ],
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
                          const SizedBox(width: 6),
                          Text(
                            'コメント',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w700,
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

class _PostPlaceLinksRow extends StatelessWidget {
  const _PostPlaceLinksRow({
    required this.placeName,
    required this.hasWebsite,
    required this.onOpenWebsite,
    required this.onOpenGoogleMaps,
  });

  final String placeName;
  final bool hasWebsite;
  final VoidCallback onOpenWebsite;
  final VoidCallback onOpenGoogleMaps;

  @override
  Widget build(BuildContext context) {
    final name = placeName.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(
          Icons.storefront_outlined,
          size: 16,
          color: AppColors.orange,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            name.isEmpty ? '店舗情報' : name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
        ),
        if (hasWebsite) ...[
          const SizedBox(width: 6),
          _CompactPlaceButton(
            icon: Icons.language,
            label: 'サイト',
            onTap: onOpenWebsite,
          ),
        ],
        const SizedBox(width: 6),
        _CompactPlaceButton(
          icon: Icons.map_outlined,
          label: '地図',
          onTap: onOpenGoogleMaps,
        ),
      ],
    );
  }
}

class _CompactPlaceButton extends StatelessWidget {
  const _CompactPlaceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.orangeHighlight,
        side: BorderSide(
          color: AppColors.orange.withValues(alpha: 0.45),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: const Size(0, 28),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, this.onTap});
  final String label;
  final int value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Text(
                '$value',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(label),
            ],
          ),
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

int calculateNotificationBadgeCount({
  required int unreadNotificationCount,
  int pendingMealTagCount = 0,
}) {
  return unreadNotificationCount + pendingMealTagCount;
}

void _showNotificationSheet(
  BuildContext context, {
  required AppShellController controller,
  required List<AppNotification> notifications,
  required List<PendingMealTag> pendingMealTags,
  ValueChanged<String>? onOpenProfile,
  ValueChanged<FeedPost>? onOpenPostDetail,
  void Function(PendingMealTag tag)? onOpenMealTag,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.blackElevated,
    builder: (sheetContext) => ListView(
      children: [
        const ListTile(
          title: Text('通知', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('いいね、コメント、友達申請、一緒の食事など'),
        ),
        if (pendingMealTags.isEmpty && notifications.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Text('まだ通知はありません。'),
          )
        else ...[
          ...pendingMealTags.map(
            (tag) => ListTile(
              leading: FriendAvatar(
                displayName: tag.inviterName,
                avatarUrl: tag.inviterIconUrl,
                radius: 22,
              ),
              title: const Text(
                '一緒の食事の記録',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${tag.inviterName}さんと${tag.placeName} · タップして投稿',
                style: const TextStyle(color: AppColors.textSubtle),
              ),
              onTap: onOpenMealTag == null
                  ? null
                  : () => onOpenMealTag(tag),
            ),
          ),
          ...notifications.map(
            (n) => ListTile(
              leading: FriendAvatar(
                displayName: n.actorLabel,
                avatarUrl: n.actorIconUrl,
                radius: 22,
              ),
              title: Text(
                n.title,
                style: TextStyle(
                  fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700,
                ),
              ),
              subtitle: _buildNotificationSubtitle(n),
              onTap: () => unawaited(
                _handleNotificationTap(
                  sheetContext,
                  controller: controller,
                  notification: n,
                  onOpenProfile: onOpenProfile,
                  onOpenPostDetail: onOpenPostDetail,
                  onOpenMealTag: onOpenMealTag,
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

Future<void> _handleNotificationTap(
  BuildContext context, {
  required AppShellController controller,
  required AppNotification notification,
  ValueChanged<String>? onOpenProfile,
  ValueChanged<FeedPost>? onOpenPostDetail,
  void Function(PendingMealTag tag)? onOpenMealTag,
}) async {
  Navigator.of(context).pop();

  final eventType = notification.eventType ?? '';
  switch (eventType) {
    case 'meal_tag':
      final postId = notification.postId;
      if (postId != null && postId.isNotEmpty && onOpenMealTag != null) {
        await controller.refreshPendingMealTags();
        PendingMealTag? tag;
        for (final pending in controller.pendingMealTags) {
          if (pending.sourcePostId == postId) {
            tag = pending;
            break;
          }
        }
        if (!context.mounted) return;
        if (tag != null) {
          onOpenMealTag(tag);
          return;
        }
      }
      break;
    case 'like':
    case 'comment':
      final postId = notification.postId;
      if (postId != null &&
          postId.isNotEmpty &&
          onOpenPostDetail != null) {
        final post = await controller.loadFeedPostById(postId);
        if (!context.mounted) return;
        if (post != null) {
          onOpenPostDetail(post);
          return;
        }
      }
      break;
    case 'friend_request':
    case 'friend_accepted':
      final userId = notification.actorUserId ?? notification.friendId;
      if (userId != null && userId.isNotEmpty && onOpenProfile != null) {
        onOpenProfile(userId);
        return;
      }
      break;
  }

  final fallbackUserId = notification.actorUserId ?? notification.friendId;
  if (fallbackUserId != null &&
      fallbackUserId.isNotEmpty &&
      onOpenProfile != null) {
    onOpenProfile(fallbackUserId);
  }
}

Widget _buildNotificationSubtitle(AppNotification notification) {
  final timestamp = notification.createdAt != null
      ? ' ・ ${_formatNotificationTime(notification.createdAt!)}'
      : '';
  return Text(
    '${notification.body}$timestamp',
    style: const TextStyle(color: AppColors.textSubtle),
  );
}

String _formatNotificationTime(DateTime createdAt) {
  final now = DateTime.now();
  final diff = now.difference(createdAt.toLocal());
  if (diff.inMinutes < 1) return 'たった今';
  if (diff.inHours < 1) return '${diff.inMinutes}分前';
  if (diff.inDays < 1) return '${diff.inHours}時間前';
  if (diff.inDays < 7) return '${diff.inDays}日前';
  return '${createdAt.month}/${createdAt.day}';
}
