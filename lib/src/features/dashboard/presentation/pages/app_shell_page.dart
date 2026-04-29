import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/supabase/post_submit_service.dart';
import '../../../../core/supabase/profile_icon_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/app_entities.dart';
import '../controllers/app_shell_controller.dart';
import '../widgets/food_pin_3d_viewer.dart';

class AppShellPage extends StatelessWidget {
  const AppShellPage({super.key});

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
          _HomePage(controller: controller),
          _FriendsPage(candidates: controller.friendCandidates),
          _CameraPage(onShot: () => _onCameraPressed(context, controller)),
          _RecordPage(summary: controller.recordSummary!),
          _ProfilePage(profile: controller.profileOverview!, controller: controller),
        ];

        return Scaffold(
          extendBody: true,
          body: pages[controller.bottomIndex],
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: NavigationBar(
                height: 62,
                selectedIndex: controller.bottomIndex,
                backgroundColor: AppColors.black,
                indicatorColor: Colors.transparent,
                onDestinationSelected: (index) {
                  if (index == 2) {
                    _onCameraPressed(context, controller);
                    return;
                  }
                  controller.changeBottomIndex(index);
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    label: 'ホーム',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.people_alt_outlined),
                    label: '友達',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.camera_alt),
                    label: '撮影',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.calendar_month_outlined),
                    label: '記録',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    label: 'プロフィール',
                  ),
                ],
              ),
            ),
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
      final loc = await controller.ensureDeviceLocation();
      final file = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        imageQuality: 88,
      );
      if (file == null) return;
      MapPin? nearest;
      if (loc != null) {
        nearest = await controller.resolvePlacePinFromCoordinate(loc.lat, loc.lng);
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.blackElevated,
      builder: (_) => _PostEditorSheet(
        draft: controller.postDraft!,
        controller: controller,
      ),
    );
  }
}

class _HomePage extends StatefulWidget {
  const _HomePage({required this.controller});
  final AppShellController controller;

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  late final PageController _pageController = PageController(
    initialPage: widget.controller.homeTabIndex,
  );
  bool _hideHomeTabSwitcher = false;

  @override
  void didUpdateWidget(covariant _HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_pageController.hasClients &&
        _pageController.page?.round() != widget.controller.homeTabIndex) {
      _pageController.animateToPage(
        widget.controller.homeTabIndex,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Stack(
      children: [
        Positioned.fill(
          child: PageView(
            controller: _pageController,
            physics: controller.homeTabIndex == 1
                ? const NeverScrollableScrollPhysics()
                : const _HighVelocityPagePhysics(),
            onPageChanged: (index) {
              controller.changeHomeTab(index);
              if (index != 1 && _hideHomeTabSwitcher) {
                setState(() {
                  _hideHomeTabSwitcher = false;
                });
              }
            },
            children: [
              _FeedTab(feed: controller.feed),
              _MapTab(
                mapPins: controller.mapPins,
                controller: controller,
                onSearchExpansionChanged: (expanded) {
                  if (!mounted) return;
                  setState(() {
                    _hideHomeTabSwitcher = expanded;
                  });
                },
                onEdgeSwipeBack: () {
                  setState(() {
                    _hideHomeTabSwitcher = false;
                  });
                  controller.changeHomeTab(0);
                  _pageController.animateToPage(
                    0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                  );
                },
              ),
            ],
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: IconButton(
                    icon: const Icon(Icons.notifications_none),
                    onPressed: () => _showNotificationSheet(
                      context,
                      controller.notifications,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.black.withValues(alpha: 0.8),
                      minimumSize: const Size(46, 46),
                      fixedSize: const Size(46, 46),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
              if (!_hideHomeTabSwitcher)
                Transform.translate(
                  offset: const Offset(0, -40),
                  child: _HomeTabSwitcher(
                    selectedIndex: controller.homeTabIndex,
                    onChanged: (target) {
                      controller.changeHomeTab(target);
                      _pageController.animateToPage(
                        target,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HighVelocityPagePhysics extends PageScrollPhysics {
  const _HighVelocityPagePhysics({super.parent});

  @override
  _HighVelocityPagePhysics applyTo(ScrollPhysics? ancestor) {
    return _HighVelocityPagePhysics(parent: buildParent(ancestor));
  }

  // Require a deliberate, fast swipe for page changes.
  @override
  double get minFlingDistance => 44.0;

  @override
  double get minFlingVelocity => 2400.0;

  @override
  double get dragStartDistanceMotionThreshold => 28.0;
}

class _HomeTabSwitcher extends StatelessWidget {
  const _HomeTabSwitcher({
    required this.selectedIndex,
    required this.onChanged,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SegmentedButton<int>(
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          backgroundColor: AppColors.black.withValues(alpha: 0.8),
          selectedBackgroundColor: AppColors.black.withValues(alpha: 0.8),
          foregroundColor: AppColors.white,
          selectedForegroundColor: AppColors.orange,
          side: BorderSide(color: AppColors.white.withValues(alpha: 0.22)),
        ),
        segments: const [
          ButtonSegment(value: 0, label: Text('投稿')),
          ButtonSegment(value: 1, label: Text('マップ')),
        ],
        selected: {selectedIndex},
        onSelectionChanged: (values) => onChanged(values.first),
      ),
    );
  }
}

class _FeedTab extends StatelessWidget {
  const _FeedTab({required this.feed});
  final List<FeedPost> feed;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 130, 16, 120),
      itemCount: feed.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final post = feed[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '@${post.userName}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    post.imageUrl,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  post.placeName,
                  style: const TextStyle(color: Colors.orangeAccent),
                ),
                Text(post.caption),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.favorite_border, size: 18),
                    const SizedBox(width: 4),
                    Text('${post.likes}'),
                    const SizedBox(width: 12),
                    const Icon(Icons.chat_bubble_outline, size: 18),
                    const SizedBox(width: 4),
                    Text('${post.comments}'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MapTab extends StatefulWidget {
  const _MapTab({
    required this.mapPins,
    required this.controller,
    required this.onSearchExpansionChanged,
    required this.onEdgeSwipeBack,
  });
  final List<MapPin> mapPins;
  final AppShellController controller;
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
  final ValueNotifier<int> _pin3dAnimationFps =
      ValueNotifier<int>(_pin3dFpsMapIdle);

  bool _didCenterOnDeviceLocation = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onShellControllerUpdate);
    _prepareMarkerIcons();
  }

  void _onShellControllerUpdate() {
    unawaited(_tryCenterOnDeviceLocation());
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
              _refreshViewportPins();
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
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
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
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.62)),
                    border: InputBorder.none,
                    prefixIcon: const Icon(Icons.search, color: Colors.white70),
                    suffixIcon: _searchController.text.trim().isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, color: Colors.white70),
                            onPressed: () {
                              _searchController.clear();
                              widget.controller.clearPlaceSuggestions();
                              setState(() {});
                              _applyKeywordFilter(null);
                            },
                          )
                        : IconButton(
                            icon: const Icon(Icons.keyboard_arrow_up, color: Colors.white70),
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
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: widget.controller.placeSuggestions.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
                    itemBuilder: (context, index) {
                      final suggestion = widget.controller.placeSuggestions[index];
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.56,
        minChildSize: 0.34,
        maxChildSize: 0.78,
        snap: true,
        snapSizes: const [0.56, 0.72],
        expand: false,
        builder: (context, scrollController) => _MapPlaceSheet(
          pin: pin,
          detailFuture: widget.controller.getPlaceDetail(pin.id),
          scrollController: scrollController,
        ),
      ),
    );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('該当する店舗が見つかりませんでした')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('候補に一致する店舗が見つかりませんでした')),
      );
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
            isPostedPin: postedIds.contains(pins[i].id) || pins[i].isFriendVisited,
          ),
    ];
  }

  List<Widget> _buildSingle3dOverlayWithTapTarget(
    BuildContext context,
    MapPin pin, {
    required bool isPostedPin,
  }) {
    final offset = _visible3dPinOffsets[pin.id]!;
    final pinAssetPath = isPostedPin ? 'assets/3d_pin_posted.html' : 'assets/3d_pin.html';
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
            icon: _microMarkerIcon ??
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
        snippet:
            visitedCount > 0 ? '来店ユーザーあり: $visitedCount 件' : '来店ユーザー情報なし',
      ),
    );
  }

  BitmapDescriptor? _clusterIconFor({required int total, required int visited}) {
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

    final glowPaint =
        Paint()
          ..color = orange.withValues(alpha: 0.24)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawCircle(center, width * 0.36, glowPaint);

    final corePaint =
        Paint()
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

class _FriendsPage extends StatelessWidget {
  const _FriendsPage({required this.candidates});
  final List<FriendCandidate> candidates;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const ListTile(
            title: Text(
              '友達',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: InputDecoration(
                hintText: '@user_codeで検索',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: candidates.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.92,
              ),
              itemBuilder: (context, index) {
                final item = candidates[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 24,
                          child: Text(item.name.substring(0, 1).toUpperCase()),
                        ),
                        const SizedBox(height: 8),
                        Text(item.name),
                        Text(
                          '共通の友達 ${item.mutualCount}人',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.tonal(
                          onPressed: () {},
                          child: Text(item.isFollowing ? 'フォロー中' : 'フォロー'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
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
          alignment: Alignment.bottomCenter,
          padding: const EdgeInsets.only(bottom: 48),
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 3),
              shape: BoxShape.circle,
            ),
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
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '記録',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(31, (index) {
                  final day = '${index + 1}';
                  final active = summary.monthlyShots.contains(day);
                  return CircleAvatar(
                    radius: 14,
                    backgroundColor: active
                        ? Colors.orange
                        : AppColors.gray,
                    child: Text(day, style: const TextStyle(fontSize: 11)),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              title: const Text('連続投稿日数'),
              trailing: Text(
                '${summary.streakDays}日',
                style: const TextStyle(color: Colors.orangeAccent),
              ),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('平均カロリー'),
              trailing: Text('${summary.caloriesAvg} kcal'),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('平均タンパク質'),
              trailing: Text('${summary.proteinAvg} g'),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI提案',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(summary.aiSuggestion),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage({required this.profile, required this.controller});
  final ProfileOverview profile;
  final AppShellController controller;

  Future<void> _editIcon(BuildContext context) async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 86,
    );
    if (file == null) return;
    try {
      await ProfileIconService().uploadAndSaveProfileIcon(File(file.path));
      await controller.initialize();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('プロフィールアイコンを更新しました')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('アイコン更新に失敗しました: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'プロフィール',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundImage: profile.avatarUrl.isNotEmpty
                    ? NetworkImage(profile.avatarUrl)
                    : null,
                child: profile.avatarUrl.isEmpty
                    ? Text(profile.name.substring(0, 1).toUpperCase())
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('@${profile.name}')),
              OutlinedButton(
                onPressed: () => _editIcon(context),
                child: const Text('アイコン編集'),
              ),
            ],
          ),
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
          const Text('ピン留めしたご飯', style: TextStyle(fontWeight: FontWeight.w700)),
          _PhotoGrid(urls: profile.pinnedShots),
          const SizedBox(height: 12),
          const Text('投稿一覧', style: TextStyle(fontWeight: FontWeight.w700)),
          _PhotoGrid(urls: profile.recentShots),
        ],
      ),
    );
  }
}

class _MapPlaceSheet extends StatelessWidget {
  const _MapPlaceSheet({
    required this.pin,
    required this.detailFuture,
    required this.scrollController,
  });
  final MapPin pin;
  final Future<PlaceDetail> detailFuture;
  final ScrollController scrollController;

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
                  child: Center(
                    child: Text('店舗詳細の取得に失敗しました'),
                  ),
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
                              icon: const Icon(Icons.close, color: Colors.white70),
                              onPressed: () => Navigator.of(context).pop(),
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
                  itemCount: pin.friendAvatars.isEmpty ? 1 : pin.friendAvatars.length,
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
              const Text('みんなの投稿', style: TextStyle(fontWeight: FontWeight.w700)),
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
                ...detail.posts.take(3).map(
                  (post) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.blackElevated.withValues(alpha: 0.67),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        if (post.imageUrl != null && post.imageUrl!.isNotEmpty)
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
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                post.comment,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white70),
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
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ],
    );
  }
}

class _PostEditorSheet extends StatefulWidget {
  const _PostEditorSheet({required this.draft, required this.controller});
  final PostDraft draft;
  final AppShellController controller;

  @override
  State<_PostEditorSheet> createState() => _PostEditorSheetState();
}

class _PostEditorSheetState extends State<_PostEditorSheet> {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('カメラで撮影した写真が必要です')),
        );
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
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('投稿しました')),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('投稿に失敗しました: $e')),
        );
      } finally {
        if (mounted) setState(() => _submitting = false);
      }
      return;
    }
    if (!context.mounted) return;
    Navigator.pop(context);
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
        height: MediaQuery.of(context).size.height * 0.72,
        child: Stack(
          children: [
            Positioned.fill(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                children: [
                  const Text(
                    '新しい投稿',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
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
                          PopupMenuItem(
                            value: 'friends',
                            child: Text('友だちのみ'),
                          ),
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
                  onPressed: (_submitting ||
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
