import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../../../core/theme/app_theme.dart';
import 'food_pin_dev_placeholder.dart';
import 'map_pin_icon_preloader.dart';

/// iOS/Android: WebView + `assets/3d_pin.html` で Three.js 3D ピンを表示。
///
/// Web（`flutter run -d chrome`）および Android で WebView が使えない場合は
/// [FoodPinDevPlaceholder] にフォールバックする。
class FoodPin3DViewer extends StatefulWidget {
  const FoodPin3DViewer({
    super.key,
    this.width,
    this.height,
    this.assetPath = 'assets/3d_pin.html',
    this.initialIconAsset,
    this.initialIconUrl,
    this.webviewBackground = Colors.transparent,
    this.suppressFlutterFallback = false,
    this.animationFpsListenable,
  });

  final double? width;
  final double? height;
  final String assetPath;
  final String? initialIconAsset;
  final String? initialIconUrl;
  final Color webviewBackground;

  /// true のとき [FoodPinDevPlaceholder] を出さない（地図オーバーレイ向け）。
  /// 3D 読み込み中/失敗時はマーカーのオレンジ丸だけ残す。
  final bool suppressFlutterFallback;

  /// マップ操作時などに FPS を下げる。未指定なら HTML 既定（30fps）。Web では未使用。
  final ValueListenable<int>? animationFpsListenable;

  bool get _isPostedPin => assetPath.contains('posted');

  @override
  State<FoodPin3DViewer> createState() => _FoodPin3DViewerState();
}

class _FoodPin3DViewerState extends State<FoodPin3DViewer> {
  WebViewController? _controller;
  final Completer<void> _pageReadyCompleter = Completer<void>();
  String? _loadError;
  int? _lastPushedFps;
  bool _readyToShow = false;
  bool _useFlutterFallback = false;
  String? _resolvedIconUrl;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      if (widget.suppressFlutterFallback) return;
      _readyToShow = true;
      _useFlutterFallback = true;
      return;
    }
    widget.animationFpsListenable?.addListener(_onAnimationFpsChanged);
    _controller = _createWebViewController();
    unawaited(_loadAsset());
  }

  WebViewController _createWebViewController() {
    final params = _isAndroid
        ? AndroidWebViewControllerCreationParams()
        : const PlatformWebViewControllerCreationParams();

    final controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(widget.webviewBackground)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (!_pageReadyCompleter.isCompleted) {
              _pageReadyCompleter.complete();
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (error.isForMainFrame == false) return;
            if (kDebugMode) {
              debugPrint(
                '[FoodPin3DViewer] ${error.errorType} ${error.description}',
              );
            }
            _activateFlutterFallback(
              reason: error.description,
            );
          },
        ),
      )
      ..setOnConsoleMessage((JavaScriptConsoleMessage message) {
        if (kDebugMode) {
          debugPrint('[FoodPin3DViewer console] ${message.message}');
        }
      });

    if (controller.platform is AndroidWebViewController) {
      final androidController = controller.platform as AndroidWebViewController;
      if (kDebugMode) {
        AndroidWebViewController.enableDebugging(true);
      }
      unawaited(androidController.setBackgroundColor(Colors.transparent));
    }

    return controller;
  }

  void _activateFlutterFallback({required String reason}) {
    if (!mounted || _useFlutterFallback) return;
    if (widget.suppressFlutterFallback) {
      if (kDebugMode) {
        debugPrint(
          '[FoodPin3DViewer] map overlay: skip 2D fallback ($reason)',
        );
      }
      setState(() {
        _loadError = reason;
        _readyToShow = false;
      });
      return;
    }
    if (kDebugMode) {
      debugPrint('[FoodPin3DViewer] fallback to Flutter pin: $reason');
    }
    setState(() {
      _useFlutterFallback = true;
      _loadError = reason;
      _readyToShow = true;
    });
  }

  @override
  void didUpdateWidget(covariant FoodPin3DViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (kIsWeb || _useFlutterFallback) return;
    if (oldWidget.animationFpsListenable != widget.animationFpsListenable) {
      oldWidget.animationFpsListenable?.removeListener(_onAnimationFpsChanged);
      widget.animationFpsListenable?.addListener(_onAnimationFpsChanged);
      _lastPushedFps = null;
      unawaited(_pushTargetFpsToWebView());
    }
    if (oldWidget.initialIconAsset != widget.initialIconAsset ||
        oldWidget.initialIconUrl != widget.initialIconUrl) {
      unawaited(_reloadIcon());
    }
  }

  @override
  void dispose() {
    widget.animationFpsListenable?.removeListener(_onAnimationFpsChanged);
    super.dispose();
  }

  Future<void> _reloadIcon() async {
    if (!mounted || _useFlutterFallback) return;
    await _prepareIconUrl();
    await _injectInitialIconIfNeeded();
    await _pushTargetFpsToWebView();
    if (!mounted) return;
    if (!_readyToShow) {
      setState(() => _readyToShow = true);
    }
  }

  void _onAnimationFpsChanged() {
    unawaited(_pushTargetFpsToWebView());
  }

  Future<void> _pushTargetFpsToWebView() async {
    final controller = _controller;
    if (controller == null || _useFlutterFallback) return;
    final listenable = widget.animationFpsListenable;
    if (listenable == null) return;
    final fps = listenable.value;
    if (_lastPushedFps == fps) return;
    try {
      await _waitForPageReady();
      if (!mounted || _useFlutterFallback) return;
      await controller.runJavaScript(
        'window.setTargetFps && window.setTargetFps($fps);',
      );
      _lastPushedFps = fps;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[FoodPin3DViewer] setTargetFps failed: $e\n$st');
      }
    }
  }

  Future<void> _prepareIconUrl() async {
    final raw = widget.initialIconUrl?.trim();
    if (raw == null || raw.isEmpty) {
      _resolvedIconUrl = null;
      return;
    }
    _resolvedIconUrl = await MapPinIconPreloader.resolveDataUrl(raw);
  }

  Future<void> _loadAsset() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await _prepareIconUrl();
      await controller.loadFlutterAsset(widget.assetPath);
      await _waitForPageReady();
      if (!mounted || _useFlutterFallback) return;

      if (_isAndroid && !await _isWebPinRendererReady()) {
        _activateFlutterFallback(
          reason: 'Three.js renderer did not initialize on Android',
        );
        return;
      }

      await _pushTargetFpsToWebView();
      if (!mounted || _useFlutterFallback) return;
      setState(() => _readyToShow = true);
      await _injectInitialIconIfNeeded();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[FoodPin3DViewer] loadFlutterAsset failed: $e\n$st');
      }
      if (_isAndroid) {
        _activateFlutterFallback(reason: e.toString());
      } else if (mounted) {
        setState(() {
          _loadError = e.toString();
          _readyToShow = true;
        });
      }
    }
  }

  Future<bool> _isWebPinRendererReady() async {
    final controller = _controller;
    if (controller == null) return false;
    try {
      final ready = await controller.runJavaScriptReturningResult(
        'typeof THREE !== "undefined"',
      );
      return ready == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _waitForPageReady() async {
    if (_pageReadyCompleter.isCompleted) return;
    await _pageReadyCompleter.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        if (_isAndroid) {
          _activateFlutterFallback(reason: 'WebView page load timed out');
        }
      },
    );
  }

  Future<void> _waitForIconTextureReady() async {
    final controller = _controller;
    if (controller == null || _useFlutterFallback) return;
    for (var attempt = 0; attempt < 120; attempt++) {
      if (!mounted || _useFlutterFallback) return;
      try {
        final ready = await controller.runJavaScriptReturningResult(
          'window.__iconTextureReady === true',
        );
        if (ready == true) return;
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
  }

  Future<void> _injectInitialIconIfNeeded() async {
    final controller = _controller;
    if (controller == null || _useFlutterFallback) return;

    final iconUrl = _resolvedIconUrl;
    if (iconUrl != null && iconUrl.isNotEmpty) {
      try {
        await _waitForPageReady();
        await controller.runJavaScript(
          'window.updateIcon && window.updateIcon(${jsonEncode(iconUrl)});',
        );
        await _waitForIconTextureReady();
        return;
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('[FoodPin3DViewer] inject icon url failed: $e\n$st');
        }
      }
    }

    final iconAsset = widget.initialIconAsset;
    if (iconAsset == null || iconAsset.isEmpty) return;
    try {
      final bytes = await rootBundle.load(iconAsset);
      final base64 = base64Encode(bytes.buffer.asUint8List());
      const chunkSize = 8000;
      await controller.runJavaScript('window.__whoEatsIconChunks = [];');
      for (int i = 0; i < base64.length; i += chunkSize) {
        final end = math.min(i + chunkSize, base64.length);
        final chunk = base64.substring(i, end);
        await controller.runJavaScript(
          'window.__whoEatsIconChunks.push(${jsonEncode(chunk)});',
        );
      }
      await controller.runJavaScript('''
        (function() {
          var b64 = (window.__whoEatsIconChunks || []).join('');
          if (b64 && window.updateIcon) {
            window.updateIcon('data:image/jpeg;base64,' + b64);
          }
          window.__whoEatsIconChunks = [];
        })();
      ''');
      await _waitForIconTextureReady();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[FoodPin3DViewer] inject icon failed: $e\n$st');
      }
    }
  }

  Widget _buildWebView(WebViewController controller) {
    if (_isAndroid) {
      return WebViewWidget.fromPlatformCreationParams(
        params: AndroidWebViewWidgetCreationParams(
          controller: controller.platform,
          displayWithHybridComposition: true,
        ),
      );
    }
    return WebViewWidget(controller: controller);
  }

  Widget _buildFallbackPin() {
    return FoodPinDevPlaceholder(
      width: widget.width,
      height: widget.height,
      isPostedPin: widget._isPostedPin,
      initialIconAsset: widget.initialIconAsset,
      initialIconUrl: widget.initialIconUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_useFlutterFallback && !widget.suppressFlutterFallback) {
      return _buildFallbackPin();
    }

    final controller = _controller;
    if (controller == null) {
      return SizedBox(width: widget.width, height: widget.height ?? 300);
    }

    if (widget.suppressFlutterFallback && !_readyToShow) {
      return SizedBox(width: widget.width, height: widget.height ?? 300);
    }

    return SizedBox(
      width: widget.width,
      height: widget.height ?? 300,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: _readyToShow ? 1 : 0,
            child: _buildWebView(controller),
          ),
          if (_loadError != null && !widget.suppressFlutterFallback)
            ColoredBox(
              color: AppColors.blackElevated,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    '3Dの読み込みに失敗しました\n$_loadError',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
