import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

/// メール確認・PKCE のディープリンク（Panda Talk 同型）。
class ValiarkDeeplinkHandler {
  ValiarkDeeplinkHandler._();

  static bool _started = false;
  static final Set<String> _sessionUrlHandled = {};

  static bool isAuthCallbackUri(Uri? uri) {
    if (uri == null) return false;
    if (!_isOurAuthHost(uri)) return false;
    final hasPkceCode = uri.queryParameters.containsKey('code');
    final hasImplicitToken =
        uri.fragment.contains('access_token') ||
        uri.fragment.contains('error_description');
    return hasPkceCode || hasImplicitToken;
  }

  static bool _isOurAuthHost(Uri uri) {
    final configured = Uri.tryParse(AppConfig.authRedirectUrl);
    if (configured != null &&
        uri.scheme == configured.scheme &&
        (configured.host.isEmpty || uri.host == configured.host)) {
      return true;
    }
    return uri.toString().contains('login-callback');
  }

  static Future<void> _consumeAuthUri(Uri uri) async {
    if (!isAuthCallbackUri(uri)) return;

    final key = uri.toString();
    if (!_sessionUrlHandled.add(key)) {
      debugPrint('[ValiarkDeeplink] skip duplicate session uri');
      return;
    }

    try {
      await Supabase.instance.client.auth.getSessionFromUrl(uri);
      debugPrint('[ValiarkDeeplink] getSessionFromUrl ok');
    } catch (e, st) {
      _sessionUrlHandled.remove(key);
      debugPrint('[ValiarkDeeplink] getSessionFromUrl failed: $e\n$st');
    }
  }

  static void handleOnce() {
    if (_started) return;
    _started = true;

    final appLinks = AppLinks();

    appLinks.getInitialLink().then((Uri? uri) async {
      if (!isAuthCallbackUri(uri)) return;
      await _consumeAuthUri(uri!);
    });

    appLinks.uriLinkStream.listen((Uri? uri) async {
      if (!isAuthCallbackUri(uri)) return;
      await _consumeAuthUri(uri!);
    });
  }
}
