import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';
import 'core/push/push_notification_service.dart';
import 'core/supabase/user_profile_sync.dart';
import 'core/supabase/valiark_deeplink_handler.dart';
import 'core/theme/app_theme.dart';
import 'features/dashboard/data/datasources/mock_dashboard_data_source.dart';
import 'features/dashboard/data/datasources/remote/google_places_data_source.dart';
import 'features/dashboard/data/datasources/remote/map_api_data_source.dart';
import 'features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'features/dashboard/domain/usecases/dashboard_usecases.dart';
import 'features/dashboard/presentation/controllers/app_shell_controller.dart';
import 'features/auth/presentation/auth_shell_page.dart';

class WhoEatsApp extends StatefulWidget {
  const WhoEatsApp({super.key});

  @override
  State<WhoEatsApp> createState() => _WhoEatsAppState();
}

class _WhoEatsAppState extends State<WhoEatsApp> {
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ValiarkDeeplinkHandler.handleOnce();
      if (AppConfig.hasSupabase) {
        unawaited(_bootstrapStaleSession());
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          unawaited(
            PushNotificationService.instance.onAuthChanged(session.user.id),
          );
        }
        _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((
          AuthState data,
        ) {
          if (data.session != null) {
            unawaited(syncCurrentUserProfile());
            unawaited(
              PushNotificationService.instance.onAuthChanged(
                data.session!.user.id,
              ),
            );
          } else {
            unawaited(PushNotificationService.instance.onAuthChanged(null));
          }
        });
      }
    });
  }

  Future<void> _bootstrapStaleSession() async {
    final auth = Supabase.instance.client.auth;
    final session = auth.currentSession;
    if (session == null || !session.isExpired) return;
    try {
      await auth.refreshSession();
    } catch (e, st) {
      debugPrint(
        'WhoEatsApp: refreshSession failed, clearing local session: $e\n$st',
      );
      await auth.signOut(scope: SignOutScope.local);
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final googlePlacesDataSource = AppConfig.hasGooglePlacesApi
        ? GooglePlacesDataSource(apiKey: AppConfig.googleMapsWebApiKey)
        : null;
    final mapApiDataSource = AppConfig.hasMapApi
        ? MapApiDataSource(
            pinsEndpoint: AppConfig.mapPinsApiUrl,
            placeDetailEndpointTemplate: AppConfig.placeDetailApiTemplate,
          )
        : null;
    final repository = DashboardRepositoryImpl(
      dataSource: MockDashboardDataSource(),
      mapApiDataSource: mapApiDataSource,
      googlePlacesDataSource: googlePlacesDataSource,
    );

    return ChangeNotifierProvider(
      create: (_) => AppShellController(
        getHomeFeedUseCase: GetHomeFeedUseCase(repository),
        getMapPinsUseCase: GetMapPinsUseCase(repository),
        getFriendsUseCase: GetFriendsUseCase(repository),
        getFriendRecommendationsUseCase: GetFriendRecommendationsUseCase(
          repository,
        ),
        getIncomingFriendRequestsUseCase: GetIncomingFriendRequestsUseCase(
          repository,
        ),
        getOutgoingPendingFollowsUseCase: GetOutgoingPendingFollowsUseCase(
          repository,
        ),
        followUserUseCase: FollowUserUseCase(repository),
        unfollowUserUseCase: UnfollowUserUseCase(repository),
        togglePostLikeUseCase: TogglePostLikeUseCase(repository),
        getPostCommentsUseCase: GetPostCommentsUseCase(repository),
        createPostCommentUseCase: CreatePostCommentUseCase(repository),
        deletePostCommentUseCase: DeletePostCommentUseCase(repository),
        searchUsersByCodeUseCase: SearchUsersByCodeUseCase(repository),
        softDeletePostUseCase: SoftDeletePostUseCase(repository),
        updatePostCaptionUseCase: UpdatePostCaptionUseCase(repository),
        getPostsForDayUseCase: GetPostsForDayUseCase(repository),
        getFeedPostByIdUseCase: GetFeedPostByIdUseCase(repository),
        getUserPublicProfileUseCase: GetUserPublicProfileUseCase(repository),
        blockUserUseCase: BlockUserUseCase(repository),
        unblockUserUseCase: UnblockUserUseCase(repository),
        getPendingMealTagsUseCase: GetPendingMealTagsUseCase(repository),
        getRecordSummaryUseCase: GetRecordSummaryUseCase(repository),
        getProfileOverviewUseCase: GetProfileOverviewUseCase(repository),
        getProfilePostThumbsUseCase: GetProfilePostThumbsUseCase(repository),
        getFavoritePostsUseCase: GetFavoritePostsUseCase(repository),
        setProfilePostPinnedUseCase: SetProfilePostPinnedUseCase(repository),
        togglePostFavoriteUseCase: TogglePostFavoriteUseCase(repository),
        getNotificationsUseCase: GetNotificationsUseCase(repository),
        markAllNotificationsReadUseCase: MarkAllNotificationsReadUseCase(
          repository,
        ),
        createPostDraftUseCase: CreatePostDraftUseCase(repository),
        getPlaceDetailUseCase: GetPlaceDetailUseCase(repository),
        searchMapPinsUseCase: SearchMapPinsUseCase(repository),
        searchMapPinsAroundUseCase: SearchMapPinsAroundUseCase(repository),
        autocompletePlacesUseCase: AutocompletePlacesUseCase(repository),
        resolvePlacePinFromCoordinateUseCase:
            ResolvePlacePinFromCoordinateUseCase(repository),
      )..initialize(),
      child: MaterialApp(
        title: 'Who eats',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const AuthShellPage(),
      ),
    );
  }
}
