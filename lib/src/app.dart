import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/dashboard/data/datasources/mock_dashboard_data_source.dart';
import 'features/dashboard/data/datasources/remote/google_places_data_source.dart';
import 'features/dashboard/data/datasources/remote/map_api_data_source.dart';
import 'features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'features/dashboard/domain/usecases/dashboard_usecases.dart';
import 'features/dashboard/presentation/controllers/app_shell_controller.dart';
import 'features/dashboard/presentation/pages/app_shell_page.dart';

class WhoEatsApp extends StatelessWidget {
  const WhoEatsApp({super.key});

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
        getFriendCandidatesUseCase: GetFriendCandidatesUseCase(repository),
        getRecordSummaryUseCase: GetRecordSummaryUseCase(repository),
        getProfileOverviewUseCase: GetProfileOverviewUseCase(repository),
        getNotificationsUseCase: GetNotificationsUseCase(repository),
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
        home: AppConfig.hasSupabase
            ? const AuthGate(child: AppShellPage())
            : const AppShellPage(),
      ),
    );
  }
}