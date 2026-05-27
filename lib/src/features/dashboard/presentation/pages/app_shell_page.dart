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
import '../widgets/profile_food_grid.dart';
import '../widgets/app_state_view.dart';
import 'profile_settings_page.dart';

class AppShellPage extends StatefulWidget {
  const AppShellPage({super.key});

  @override
  State<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends State<AppShellPage> {
  MapPin? _activePlaceSheetPin;
  bool _postEditorOpen = false;
  FeedPost? _activePostDetail;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    if (AppConfig.hasSupabase) {
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
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

  void _openFriendsPage(List<FriendCandidate> candidates) {
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
          body: _FriendsPage(candidates: candidates),
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
            onOpenPlace: _openPlaceSheet,
            onOpenPostDetail: _openPostDetail,
            onOpenFriends: () => _openFriendsPage(controller.friendCandidates),
          ),
          _MapTab(
            mapPins: controller.mapPins,
            controller: controller,
            onPlaceTap: _openPlaceSheet,
            onSearchExpansionChanged: (_) {},
            onEdgeSwipeBack: () {},
          ),
          _CameraPage(onShot: () => _onCameraPressed(context, controller)),
          _RecordPage(summary: controller.recordSummary!),
          _ProfilePage(
            profile: controller.profileOverview!,
            controller: controller,
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
                  child: PostDetailPage(
                    post: _activePostDetail!,
                    controller: controller,
                    onClose: _closePostDetail,
                  ),
                ),
            ],
          ),
          bottomNavigationBar: FloatingBottomNav(
            selectedIndex: controller.bottomIndex,
            onTabSelected: (index) => controller.changeBottomIndex(index),
            onCameraPressed: () => controller.changeBottomIndex(2),
          ),
        );
      },
    );
  }

  Future<void> _onCameraPressed(
    BuildContext context,
    AppShellController controller,
  ) async {
    if (AppConfig.hasSupabase) {
      // 位置取得は時間がかかることがある。先にやるとカメラタブの真っ黒画面のまま長く待つことになるので、
      // 先にカメラ／ピッカーを開き、撮影後に位置と最寄り店を解決する。
      final file = await ImagePicker().pickImage(
        source: ImageSource.camera,
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
          placeName: nearest?.placeName ?? '最寄り店を取得できませんでした',
          note: '',
          withWho: '',
        ),
      );
    } else {
      await controller.openCameraFlow();
    }

    if (!context.mounted || controller.postDraft == null) return;
    // 撮影後もタブ2のままだと画面全体が黒ベースのままなので、編集シートはホーム上に載せる。
    controller.changeBottomIndex(0);
    await Future<void>.delayed(Duration.zero);
    if (!context.mounted || controller.postDraft == null) return;
    _openPostEditor();
  }
}

class _HomePage extends StatefulWidget {
  const _HomePage({
    required this.controller,
    required this.onOpenPlace,
    required this.onOpenPostDetail,
    required this.onOpenFriends,
  });
  final AppShellController controller;
  final ValueChanged<MapPin> onOpenPlace;
  final ValueChanged<FeedPost> onOpenPostDetail;
  final VoidCallback onOpenFriends;

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Stack(
      children: [
        _FeedTab(feed: controller.feed, onTapPost: widget.onOpenPostDetail),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.people_outline),
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
          ),
        ),
      ],
    );
  }
}

class _FeedTab extends StatelessWidget {
  const _FeedTab({required this.feed, required this.onTapPost});
  final List<FeedPost> feed;
  final ValueChanged<FeedPost> onTapPost;

  @override
  Widget build(BuildContext context) {
    if (feed.isEmpty) {
      return AppStateView(
        type: AppStateType.empty,
        title: '投稿がまだありません',
        message: '撮影して、みんなの「おすすめ」を広げよう。',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 120, 16, 120),
      itemCount: feed.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final post = feed[index];
        return FoodPostCard(post: post, onTap: () => onTapPost(post));
      },
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
  BitmapDescriptor? _microMarkerIcon;
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
    unawaited(_tryCenterOnDeviceLocation());
  }

  void _onGoogleMapsLoadFailureChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _tryCenterOnDeviceLocation() async {
    if (_didCenterOnDeviceLocation) return;
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
    final controller = _mapController;
    if (controller == null) return;
    final pins = widget.controller.mapPins;
    if (pins.isEmpty) return;
    final target = pins.firstWhere(
      (p) => p.latitude != null && p.longitude != null,
      orElse: () => pins.first,
    );
    final lat = target.latitude;
    final lng = target.longitude;
    if (lat == null || lng == null) return;
    final nextZoom = _lastZoom < 15 ? 15.0 : _lastZoom;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(lat, lng), zoom: nextZoom),
      ),
    );
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
        if (_visible3dPinOffsets.containsKey(pins[i].id))
          ..._buildSingle3dOverlayWithTapTarget(
            context,
            pins[i],
            isPostedPin:
                postedIds.contains(pins[i].id) || pins[i].isFriendVisited,
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
            icon:
                _microMarkerIcon ??
                BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueOrange,
                ),
            zIndexInt: 1,
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
        title: 'この範囲に ${pins.length} 店',
        snippet: visitedCount > 0 ? '来店ユーザーあり: $visitedCount 件' : '来店ユーザー情報なし',
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
    final microBytes = await _drawMicroDotBytes(size: 8);
    if (!mounted) return;
    setState(() {
      _microMarkerIcon = BitmapDescriptor.bytes(microBytes);
    });
  }

  Future<Uint8List> _drawMicroDotBytes({required int size}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final width = size.toDouble();
    final center = Offset(width / 2, width / 2);
    canvas.drawCircle(
      center,
      width * 0.26,
      Paint()..color = AppColors.orange.withValues(alpha: 0.67),
    );
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

    final glowPaint = Paint()
      ..color = orange.withValues(alpha: 0.24)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawCircle(center, width * 0.36, glowPaint);

    final corePaint = Paint()
      ..color = orange
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, width * 0.26, corePaint);

    canvas.drawCircle(center, width * 0.22, Paint()..color = Colors.white);

    final textPainter = TextPainter(
      text: TextSpan(
        text: '$total',
        style: TextStyle(
          color: AppColors.blackElevated,
          fontSize: width * 0.2,
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

    final avatarDots = visited.clamp(0, 8);
    for (int i = 0; i < avatarDots; i++) {
      final theta = (2 * pi / avatarDots) * i - pi / 2;
      final dotCenter = Offset(
        center.dx + cos(theta) * width * 0.33,
        center.dy + sin(theta) * width * 0.33,
      );
      canvas.drawCircle(dotCenter, width * 0.05, Paint()..color = Colors.white);
      canvas.drawCircle(dotCenter, width * 0.038, Paint()..color = orange);
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
  const _FriendsPage({required this.candidates});
  final List<FriendCandidate> candidates;

  @override
  State<_FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<_FriendsPage> {
  bool _searchByConnection = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onFriendTap(FriendCandidate c) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${c.name} のプロフィールは未実装（MVP）')));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.candidates.isEmpty) {
      return SafeArea(
        child: AppStateView(
          type: AppStateType.empty,
          title: '友達がいません',
          message: 'まずはつながって、おすすめを広げよう。',
        ),
      );
    }
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(40, 40),
                  ),
                ),
                Expanded(
                  child: Text(
                    '友達',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                ),
                if (_searchByConnection)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () =>
                        setState(() => _searchByConnection = false),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
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

          if (!_searchByConnection)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
            ),

          const SizedBox(height: 12),

          Expanded(
            child: _searchByConnection
                ? FriendSearchPage(
                    candidates: widget.candidates,
                    onBack: () => setState(() => _searchByConnection = false),
                    onFriendTap: _onFriendTap,
                  )
                : FriendGrid(
                    candidates: widget.candidates,
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
        final showDot = item.isFollowing || item.mutualCount > 0;
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

/// 「からむで探す」検索UI（MVP: candidates の mock を並べる）
class FriendSearchPage extends StatelessWidget {
  const FriendSearchPage({
    super.key,
    required this.candidates,
    required this.onBack,
    required this.onFriendTap,
  });

  final List<FriendCandidate> candidates;
  final VoidCallback onBack;
  final ValueChanged<FriendCandidate> onFriendTap;

  @override
  Widget build(BuildContext context) {
    final recommendedTags = const ['グルメ', 'カフェ巡り', 'ラーメン', '焼肉', 'スイーツ', 'ランチ'];

    final sorted = [...candidates]
      ..sort((a, b) => b.mutualCount.compareTo(a.mutualCount));

    final top = sorted.take(4).toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
              final showDot = c.isFollowing || c.mutualCount > 0;
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
          (c) => InkWell(
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
                    showStatusDot: c.isFollowing || c.mutualCount > 0,
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
                          '共通友達 ${c.mutualCount}人',
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
                    onPressed: () => onFriendTap(c),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.orange,
                      foregroundColor: Colors.black,
                      shape: const StadiumBorder(),
                    ),
                    child: Text(c.isFollowing ? 'フォロー中' : 'フォロー'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CameraPage extends StatelessWidget {
  const _CameraPage({required this.onShot});
  final VoidCallback onShot;

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
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordPage extends StatelessWidget {
  const _RecordPage({required this.summary});
  final RecordSummary summary;

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: CalendarRecordView(summary: summary));
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage({required this.profile, required this.controller});
  final ProfileOverview profile;
  final AppShellController controller;

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
                      builder: (context) => ProfileSettingsPage(controller: controller),
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
                child: _StatTile(label: 'フォロー', value: profile.following),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(label: 'フォロワー', value: profile.followers),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('ピン留めしたご飯', style: TextStyle(fontWeight: FontWeight.w900)),
          ProfileFoodGrid(urls: profile.pinnedShots),
          const SizedBox(height: 12),
          const Text('投稿一覧', style: TextStyle(fontWeight: FontWeight.w900)),
          ProfileFoodGrid(urls: profile.recentShots),
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
  String _postType = 'restaurant';
  String _visibility = 'friends';
  bool _submitting = false;
  String? _selectedPlaceGoogleId;
  double? _selectedPlaceLat;
  double? _selectedPlaceLng;

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController(text: widget.draft.note);
    _placeController = TextEditingController(text: widget.draft.placeName);
    _selectedPlaceGoogleId = widget.draft.placeGoogleId;
    _selectedPlaceLat = widget.draft.placeLatitude;
    _selectedPlaceLng = widget.draft.placeLongitude;
  }

  @override
  void dispose() {
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

  Future<void> _submit(BuildContext context) async {
    if (_submitting) return;
    if (AppConfig.hasSupabase) {
      final path = widget.draft.localImagePath;
      if (path == null || path.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('カメラで撮影した写真が必要です')));
        return;
      }
      setState(() => _submitting = true);
      try {
        await PostSubmitService().submitPhotoPost(
          imageFile: File(path),
          postType: _postType,
          visibility: _visibility,
          restaurantPlaceGoogleId: _selectedPlaceGoogleId,
          restaurantPlaceName: _placeController.text.trim(),
          restaurantPlaceLatitude: _selectedPlaceLat,
          restaurantPlaceLongitude: _selectedPlaceLng,
          caption: _captionController.text.trim().isEmpty
              ? null
              : _captionController.text.trim(),
        );
        if (!context.mounted) return;
        widget.controller.clearPostDraft();
        await widget.controller.initialize();
        if (!context.mounted) return;
        widget.onClose();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('投稿しました')));
      } catch (e) {
        if (!context.mounted) return;
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
                      child: widget.draft.localImagePath != null
                          ? Image.file(
                              File(widget.draft.localImagePath!),
                              fit: BoxFit.cover,
                            )
                          : Image.network(
                              widget.draft.photoUrl,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _placeController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: '店名（現在地から最寄り）',
                    ),
                  ),
                  if (_selectedPlaceGoogleId == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        '位置情報または最寄り店の解決に失敗したため、投稿できません。',
                        style: TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                    ),
                  TextField(
                    controller: _captionController,
                    decoration: InputDecoration(
                      labelText: 'キャプション',
                      hintText: widget.draft.note,
                    ),
                  ),
                  TextField(
                    decoration: InputDecoration(
                      labelText: '誰といるか',
                      hintText: widget.draft.withWho,
                    ),
                  ),
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
class PostDetailPage extends StatelessWidget {
  const PostDetailPage({
    super.key,
    required this.post,
    required this.controller,
    required this.onClose,
  });

  final FeedPost post;
  final AppShellController controller;
  final VoidCallback onClose;

  Future<void> _openWebsite(BuildContext context, PlaceDetail? place) async {
    final raw = (((place?.websiteUrl ?? '').trim().isNotEmpty
            ? place?.websiteUrl
            : place?.googleMapsUrl) ??
        '').trim();
    final uri = Uri.tryParse(raw);
    if (raw.isEmpty || uri == null || !uri.hasScheme) {
      _showSnack(context, '店舗サイトが見つかりません');
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) _showSnack(context, '店舗サイトを開けませんでした');
  }

  Future<void> _openGoogleMaps(BuildContext context, PlaceDetail? place) async {
    final placeName = place?.placeName ?? post.placeName;
    final placeId = post.placeGoogleId ?? place?.placeId ?? '';
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final placeFuture = (post.placeGoogleId ?? '').isNotEmpty
        ? controller.getPlaceDetail(post.placeGoogleId!)
        : Future<PlaceDetail?>.value(null);
    final iconUrl = post.userIconUrl ?? '';
    final hasNetworkIcon =
        iconUrl.isNotEmpty &&
        (iconUrl.startsWith('http://') || iconUrl.startsWith('https://'));
    final initial = post.userName.isNotEmpty
        ? post.userName[0].toUpperCase()
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
                          '@${post.userName}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.more_vert,
                          color: Colors.white70,
                        ),
                        onPressed: () {},
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
                              post.imageUrl,
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
                                    place?.placeName ?? post.placeName,
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
                                      const Icon(
                                        Icons.star,
                                        size: 16,
                                        color: AppColors.orangeAccent,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '★ ${(place?.rating ?? 4.5).toStringAsFixed(1)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
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
                        fallbackPlaceName: post.placeName,
                        onOpenWebsite: () => _openWebsite(context, place),
                        onOpenGoogleMaps: () => _openGoogleMaps(context, place),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        post.caption,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Icon(
                            Icons.favorite_border,
                            size: 18,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${post.likes}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
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
                            '${post.comments}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FriendAvatarStack(
                        avatarDisplays: post.friendAvatars,
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
              const Icon(Icons.storefront_outlined, size: 18, color: AppColors.orange),
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
                    color: place!.openNow! ? AppColors.orangeHighlight : Colors.white70,
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
