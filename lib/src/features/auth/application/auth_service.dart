import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_line_sdk/flutter_line_sdk.dart';
import 'package:http/http.dart' as http;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/supabase/user_profile_sync.dart';

/// LINE / Apple ネイティブ認証をどの画面から開いたか（Edge で新規作成可否を分岐）。
enum NativeAuthFlow {
  /// ログイン画面: 既存のみ。未登録ならエラー。
  login,

  /// 新規登録画面: 未登録ならユーザー作成。
  signup,
}

/// pedal_share と同様: Edge が `otp_type: magiclink` を返しても verify は [OtpType.email]。
OtpType _nativeOtpType(dynamic raw) {
  if (raw?.toString() == 'signup') return OtpType.signup;
  return OtpType.email;
}

/// Email is already registered on this Supabase project (e.g. another app).
class EmailAlreadyRegisteredException implements Exception {
  const EmailAlreadyRegisteredException();
}

class NativeAuthResponse {
  const NativeAuthResponse({
    required this.authResponse,
    required this.isNewUser,
  });

  final AuthResponse authResponse;
  final bool isNewUser;
}

class AuthService {
  AuthService({http.Client? client})
    : _client = client ?? http.Client(),
      _supabase = Supabase.instance.client;

  final http.Client _client;
  final SupabaseClient _supabase;

  User? get currentUser => _supabase.auth.currentUser;

  Stream<User?> get authStateChanges {
    return _supabase.auth.onAuthStateChange.map((event) => event.session?.user);
  }

  void _debugLogAuthRedirect(String label) {
    if (kDebugMode) {
      debugPrint(
        '[AuthService] $label → authRedirectUrl=${AppConfig.authRedirectUrl}',
      );
    }
  }

  /// Supabase Edge（`verify_jwt` 既定）通過用。`--no-verify-jwt` デプロイ時は不要だが付与しても害はない。
  Map<String, String> get _edgeFunctionHeaders => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
    'apikey': AppConfig.supabaseAnonKey,
  };

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user != null) {
        final provider = user.appMetadata['provider'] as String?;
        final treatAsEmail = provider == 'email' || provider == null;
        if (treatAsEmail && user.emailConfirmedAt == null) {
          await signOut();
          throw Exception('メールアドレスが確認されていません。受信トレイを確認してください。');
        }
        // panda_profiles sync runs from PandaTalkApp ref.listen (avoid awaiting
        // localhost Worker here — real devices hang).
      }
      return response;
    } on http.ClientException catch (e) {
      debugPrint('signInWithEmail network: $e');
      throw Exception('ネットワーク接続に問題があります。インターネット接続を確認してください。');
    } on AuthException catch (error) {
      throw Exception(_authMessage(error));
    }
  }

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      _debugLogAuthRedirect('signUpWithEmail');
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'displayName': displayName, 'name': displayName},
        emailRedirectTo: AppConfig.authRedirectUrl,
      );
      return response;
    } on http.ClientException catch (e) {
      debugPrint('signUpWithEmail network: $e');
      throw Exception('ネットワーク接続に問題があります。インターネット接続を確認してください。');
    } on AuthException catch (error) {
      if (_emailAlreadyRegistered(error)) {
        throw const EmailAlreadyRegisteredException();
      }
      throw Exception(_authMessage(error));
    }
  }

  Future<NativeAuthResponse> signInWithLine({
    NativeAuthFlow flow = NativeAuthFlow.login,
  }) async {
    try {
      final result = await LineSDK.instance.login();
      final accessToken = result.accessToken.value;
      if (accessToken.isEmpty) {
        throw Exception('LINE認証がキャンセルされました');
      }

      final flowParam = flow == NativeAuthFlow.login ? 'login' : 'signup';
      if (kDebugMode) {
        debugPrint('[AuthService] line-auth-native flow=$flowParam');
      }

      final response = await _client.post(
        Uri.parse('${AppConfig.supabaseFunctionsUrl}/line-auth-native'),
        headers: _edgeFunctionHeaders,
        body: jsonEncode({'accessToken': accessToken, 'flow': flowParam}),
      );
      final nativeResponse = await _verifyNativeOtp(response);

      try {
        final profile = await LineSDK.instance.getProfile();
        await _supabase.auth.updateUser(
          UserAttributes(
            data: {
              'displayName': profile.displayName,
              'name': profile.displayName,
              'photoURL': profile.pictureUrl,
              'statusMessage': profile.statusMessage,
            },
          ),
        );
      } catch (e, st) {
        assert(() {
          debugPrint(
            '[AuthService] LINE profile/metadata update skipped: $e\n$st',
          );
          return true;
        }());
      }

      return nativeResponse;
    } on PlatformException catch (error) {
      if (error.code == 'CANCEL') {
        throw Exception('LINE認証がキャンセルされました');
      }
      if (error.code == 'AUTHENTICATION_AGENT_ERROR') {
        throw Exception('LINE認証エラーが発生しました。もう一度お試しください');
      }
      throw Exception('LINE認証に失敗しました: ${error.message ?? error.code}');
    } on AuthException catch (error) {
      throw Exception(_authMessage(error));
    }
  }

  Future<NativeAuthResponse> signInWithApple({
    NativeAuthFlow flow = NativeAuthFlow.login,
  }) async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final identityToken = appleCredential.identityToken;
      if (identityToken == null || identityToken.isEmpty) {
        throw Exception(
          'Apple のサインイン情報を取得できませんでした。'
          'Xcode の Runner で Sign in with Apple を有効にし、'
          'Apple Developer の App ID（com.valiark.whoeats）でも Sign in with Apple をオンにしてください。',
        );
      }

      final flowParam = flow == NativeAuthFlow.login ? 'login' : 'signup';
      if (kDebugMode) {
        debugPrint('[AuthService] apple-auth-native flow=$flowParam');
      }

      final response = await _client.post(
        Uri.parse('${AppConfig.supabaseFunctionsUrl}/apple-auth-native'),
        headers: _edgeFunctionHeaders,
        body: jsonEncode({
          'flow': flowParam,
          'identityToken': identityToken,
          'authorizationCode': appleCredential.authorizationCode,
          'email': appleCredential.email,
          'givenName': appleCredential.givenName,
          'familyName': appleCredential.familyName,
        }),
      );
      final nativeResponse = await _verifyNativeOtp(response);

      final displayName = _appleDisplayName(appleCredential);
      if (displayName != null) {
        try {
          await _supabase.auth.updateUser(
            UserAttributes(
              data: {
                'displayName': displayName,
                'name': displayName,
                'givenName': appleCredential.givenName,
                'familyName': appleCredential.familyName,
              },
            ),
          );
        } catch (e, st) {
          assert(() {
            debugPrint('[AuthService] Apple metadata update skipped: $e\n$st');
            return true;
          }());
        }
      }

      return nativeResponse;
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        throw Exception('Apple認証がキャンセルされました');
      }
      if (error.code == AuthorizationErrorCode.failed) {
        throw Exception('Apple認証に失敗しました。もう一度お試しください');
      }
      if (error.code == AuthorizationErrorCode.invalidResponse) {
        throw Exception('Apple認証のレスポンスが無効です');
      }
      if (error.code == AuthorizationErrorCode.notHandled) {
        throw Exception('Apple認証が処理できませんでした');
      }
      if (error.code == AuthorizationErrorCode.unknown) {
        throw Exception('Apple認証中に不明なエラーが発生しました');
      }
      throw Exception('Apple認証に失敗しました: ${error.message}');
    } on AuthException catch (error) {
      throw Exception(_authMessage(error));
    }
  }

  /// Supabase Auth の Google プロバイダー（OAuth + PKCE）。ブラウザで認証後、
  /// [AppConfig.authRedirectUrl] へ戻り [ValiarkDeeplinkHandler] がセッションを確立する。
  Future<void> signInWithGoogle() async {
    try {
      _debugLogAuthRedirect('signInWithGoogle');
      final launched = await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: AppConfig.authRedirectUrl,
      );
      if (!launched) {
        throw Exception('Google認証画面を開けませんでした');
      }
    } on http.ClientException catch (e) {
      debugPrint('signInWithGoogle network: $e');
      throw Exception('ネットワーク接続に問題があります。インターネット接続を確認してください。');
    } on AuthException catch (error) {
      throw Exception(_authMessage(error));
    } on PlatformException catch (error) {
      throw Exception('Google認証を開始できませんでした: ${error.message ?? error.code}');
    }
  }

  Future<void> signOut() async {
    final provider = _supabase.auth.currentUser?.appMetadata['provider'];
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint('signOut failed: $e');
      try {
        await _supabase.auth.signOut();
      } catch (e2) {
        debugPrint('signOut retry failed: $e2');
        rethrow;
      }
    }
    if (provider == 'line') {
      try {
        await LineSDK.instance.logout();
      } catch (error) {
        debugPrint('LINE logout failed: $error');
      }
    }
  }

  /// Alias for [requestPasswordReset].
  Future<void> resetPassword(String email) => requestPasswordReset(email);

  /// Opens in-app password update flow via [AppConfig.authRedirectUrl].
  Future<void> requestPasswordReset(String email) async {
    try {
      _debugLogAuthRedirect('requestPasswordReset');
      await _supabase.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: AppConfig.authRedirectUrl,
      );
    } on http.ClientException catch (e) {
      debugPrint('requestPasswordReset network: $e');
      throw Exception('ネットワーク接続に問題があります。インターネット接続を確認してください。');
    } on AuthException catch (error) {
      throw Exception(_authMessage(error));
    }
  }

  /// Resend signup confirmation for the current session user (e.g. after signUp, before confirm).
  Future<void> resendEmailVerification() async {
    final user = _supabase.auth.currentUser;
    if (user?.email == null) return;
    try {
      _debugLogAuthRedirect('resendEmailVerification');
      await _supabase.auth.resend(
        type: OtpType.signup,
        email: user!.email!,
        emailRedirectTo: AppConfig.authRedirectUrl,
      );
    } on http.ClientException catch (e) {
      debugPrint('resendEmailVerification network: $e');
      throw Exception('ネットワーク接続に問題があります。インターネット接続を確認してください。');
    } on AuthException catch (error) {
      throw Exception(_authMessage(error));
    }
  }

  /// Resend signup confirmation email (requires address only).
  Future<void> resendSignupEmail(String email) async {
    try {
      _debugLogAuthRedirect('resendSignupEmail');
      await _supabase.auth.resend(
        type: OtpType.signup,
        email: email.trim(),
        emailRedirectTo: AppConfig.authRedirectUrl,
      );
    } on http.ClientException catch (e) {
      debugPrint('resendSignupEmail network: $e');
      throw Exception('ネットワーク接続に問題があります。インターネット接続を確認してください。');
    } on AuthException catch (error) {
      throw Exception(_authMessage(error));
    }
  }

  /// [whoeats_users] 行の最低限を用意（詳細は [ProfileSetupPage]）。
  Future<void> ensureUserProfileRow() async {
    await syncCurrentUserProfile();
  }

  Future<NativeAuthResponse> _verifyNativeOtp(http.Response response) async {
    if (response.statusCode != 200) {
      if (kDebugMode) {
        debugPrint(
          '[AuthService] native auth HTTP ${response.statusCode}: ${response.body}',
        );
      }
      throw Exception(_nativeAuthError(response));
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final hashedToken = data['hashed_token'] as String?;
    if (hashedToken == null || hashedToken.isEmpty) {
      throw Exception('認証トークンの取得に失敗しました');
    }

    final otpType = _nativeOtpType(data['otp_type']);

    try {
      // token_hash の /verify では GoTrue が type + token_hash 以外を拒否する。
      final verifyResponse = await _supabase.auth.verifyOTP(
        tokenHash: hashedToken,
        type: otpType,
      );
      final session = _supabase.auth.currentSession ?? verifyResponse.session;
      if (session == null) {
        throw Exception('セッションの取得に失敗しました');
      }

      return NativeAuthResponse(
        authResponse: AuthResponse(session: session, user: session.user),
        isNewUser: data['is_new_user'] as bool? ?? false,
      );
    } on AuthException catch (error, st) {
      if (kDebugMode) {
        debugPrint(
          '[AuthService] verifyOTP failed: ${error.message} (code=${error.code})\n$st',
        );
      }
      throw Exception(_authMessage(error));
    }
  }

  String _nativeAuthError(http.Response response) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final code = data['error']?.toString();
      final details = data['details']?.toString();
      if (code == 'account_not_found' &&
          details != null &&
          details.isNotEmpty) {
        return details;
      }
      if (code == 'identity_conflict' &&
          details != null &&
          details.isNotEmpty) {
        return details;
      }
      final error = data['error'] ?? '認証に失敗しました';
      return details == null ? '$error' : '$error: $details';
    } catch (_) {
      return response.body.isEmpty ? '認証に失敗しました' : response.body;
    }
  }

  /// User-facing message for a Supabase [AuthException] (e.g. email auth UI).
  String handleAuthException(AuthException e) => _authMessage(e);

  bool _emailAlreadyRegistered(AuthException error) {
    final message = error.message.toLowerCase();
    return message.contains('already registered') ||
        message.contains('already been registered') ||
        message.contains('user already exists') ||
        message.contains('email address is already registered');
  }

  String _authMessage(AuthException error) {
    final message = error.message.toLowerCase();

    if (message.contains('clientexception') ||
        message.contains('socketexception') ||
        message.contains('failed host lookup') ||
        message.contains('no address associated with hostname') ||
        message.contains('network is unreachable') ||
        message.contains('connection refused') ||
        message.contains('connection timed out')) {
      return 'ネットワーク接続に問題があります。インターネット接続を確認してください。';
    }

    switch (error.code) {
      case 'user_not_found':
        return '入力されたメールアドレスのユーザーは見つかりませんでした。';
      case 'invalid_credentials':
      case 'invalid_grant':
        return 'メールアドレスまたはパスワードが違います';
      case 'email_exists':
        return 'このメールアドレスはすでに登録済みです。ログインをお試しください。';
      case 'weak_password':
        return 'パスワードはより強力なものにしてください（例：8文字以上）。';
      case 'invalid_email':
        return '有効なメールアドレス形式で入力してください。';
      case '429':
        return 'リクエストが多すぎます。しばらく時間をおいてから再度お試しください。';
      case 'access_token_expired':
      case 'jwt_expired':
        return 'セッションの有効期限が切れました。再度ログインしてください。';
      default:
        break;
    }

    if (message.contains('invalid login credentials')) {
      return 'メールアドレスまたはパスワードが違います';
    }
    if (message.contains('already registered') ||
        message.contains('already been registered')) {
      return 'このメールアドレスはすでに登録されています';
    }
    if (message.contains('email not confirmed')) {
      return 'メールアドレスが確認されていません。受信トレイを確認してください。';
    }
    return error.message;
  }

  String? _appleDisplayName(AuthorizationCredentialAppleID credential) {
    if (credential.givenName != null && credential.familyName != null) {
      return '${credential.familyName} ${credential.givenName}';
    }
    return credential.familyName ?? credential.givenName;
  }
}
