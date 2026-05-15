import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// メール確認・PKCE のディープリンク取りこぼし対策（cold-start / foreground）。
class ValiarkDeeplinkHandler {
  ValiarkDeeplinkHandler._();

  static bool _started = false;

  static bool isAuthCallbackUri(Uri? uri) {
    if (uri == null) return false;
    final s = uri.toString();
    if (uri.scheme == 'io.valiark.auth') return true;
    if (s.contains('login-callback')) return true;
    return false;
  }

  static Future<void> _consumeAuthUri(Uri uri) async {
    try {
      await Supabase.instance.client.auth.getSessionFromUrl(uri);
      debugPrint('[ValiarkDeeplink] getSessionFromUrl ok');
    } catch (e, st) {
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
