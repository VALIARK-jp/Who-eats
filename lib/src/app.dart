import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
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
        home: AppConfig.hasSupabase ? const _AuthGate() : const AppShellPage(),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = supabase.auth.currentSession;
        if (session != null) {
          return const AppShellPage();
        }
        return const _EmailAuthPage();
      },
    );
  }
}

class _EmailAuthPage extends StatefulWidget {
  const _EmailAuthPage();

  @override
  State<_EmailAuthPage> createState() => _EmailAuthPageState();
}

class _EmailAuthPageState extends State<_EmailAuthPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _showMessage('メールアドレスとパスワードを入力してください');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _showMessage('メールアドレスとパスワードを入力してください');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );
      _showMessage('登録しました。確認メールが必要な場合は受信箱を確認してください。');
    } on AuthException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Who eats Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _isLoading ? null : _signIn,
                    child: const Text('ログイン'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _signUp,
                    child: const Text('新規登録'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}