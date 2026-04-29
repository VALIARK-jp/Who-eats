import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/theme/app_theme.dart';

/// WebView + `assets/3d_pin.html` で Three.js 3D ピンを表示する。
///
/// `loadFlutterAsset` は `file://` 相当で開くため、HTML 内の CDN script は
/// iOS/Android で読めないことが多い。`assets/three.min.js` を同梱して相対参照する。
class FoodPin3DViewer extends StatefulWidget {
  const FoodPin3DViewer({
    super.key,
    this.width,
    this.height,
    this.assetPath = 'assets/3d_pin.html',
    this.initialIconAsset,
    this.initialIconUrl,
    this.webviewBackground = Colors.transparent,
    this.animationFpsListenable,
  });

  final double? width;
  final double? height;
  final String assetPath;
  final String? initialIconAsset;
  final String? initialIconUrl;
  final Color webviewBackground;

  /// マップ操作時などに FPS を下げる。未指定なら HTML 既定（30fps）。
  final ValueListenable<int>? animationFpsListenable;

  @override
  State<FoodPin3DViewer> createState() => _FoodPin3DViewerState();
}

class _FoodPin3DViewerState extends State<FoodPin3DViewer> {
  late final WebViewController _controller;
  final Completer<void> _pageReadyCompleter = Completer<void>();
  String? _loadError;
  int? _lastPushedFps;

  @override
  void initState() {
    super.initState();
    widget.animationFpsListenable?.addListener(_onAnimationFpsChanged);
    _controller = WebViewController()
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
            if (kDebugMode) {
              debugPrint(
                '[FoodPin3DViewer] ${error.errorType} ${error.description}',
              );
            }
            if (mounted) {
              setState(() {
                _loadError = error.description;
              });
            }
          },
        ),
      )
      ..setOnConsoleMessage((JavaScriptConsoleMessage message) {
        if (kDebugMode) {
          debugPrint('[FoodPin3DViewer console] ${message.message}');
        }
      });
    unawaited(_loadAsset());
  }

  @override
  void didUpdateWidget(covariant FoodPin3DViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animationFpsListenable != widget.animationFpsListenable) {
      oldWidget.animationFpsListenable?.removeListener(_onAnimationFpsChanged);
      widget.animationFpsListenable?.addListener(_onAnimationFpsChanged);
      _lastPushedFps = null;
      unawaited(_pushTargetFpsToWebView());
    }
    if (oldWidget.initialIconAsset != widget.initialIconAsset ||
        oldWidget.initialIconUrl != widget.initialIconUrl) {
      unawaited(_injectInitialIconIfNeeded());
    }
  }

  @override
  void dispose() {
    widget.animationFpsListenable?.removeListener(_onAnimationFpsChanged);
    super.dispose();
  }

  void _onAnimationFpsChanged() {
    unawaited(_pushTargetFpsToWebView());
  }

  Future<void> _pushTargetFpsToWebView() async {
    final listenable = widget.animationFpsListenable;
    if (listenable == null) return;
    final fps = listenable.value;
    if (_lastPushedFps == fps) return;
    try {
      await _waitForPageReady();
      if (!mounted) return;
      await _controller.runJavaScript(
        'window.setTargetFps && window.setTargetFps($fps);',
      );
      _lastPushedFps = fps;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[FoodPin3DViewer] setTargetFps failed: $e\n$st');
      }
    }
  }

  Future<void> _loadAsset() async {
    try {
      await _controller.loadFlutterAsset(widget.assetPath);
      await _waitForPageReady();
      await _injectInitialIconIfNeeded();
      await _pushTargetFpsToWebView();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[FoodPin3DViewer] loadFlutterAsset failed: $e\n$st');
      }
      if (mounted) {
        setState(() {
          _loadError = e.toString();
        });
      }
    }
  }

  Future<void> _waitForPageReady() async {
    if (_pageReadyCompleter.isCompleted) return;
    await _pageReadyCompleter.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {},
    );
  }

  Future<void> _injectInitialIconIfNeeded() async {
    final iconUrl = widget.initialIconUrl;
    if (iconUrl != null && iconUrl.isNotEmpty) {
      try {
        await _waitForPageReady();
        await _controller.runJavaScript(
          'window.updateIcon && window.updateIcon(${jsonEncode(iconUrl)});',
        );
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
      // iOS WebKit can fail evaluating very long JS strings.
      // Send the base64 payload in chunks then compose on the JS side.
      const chunkSize = 8000;
      await _controller.runJavaScript('window.__whoEatsIconChunks = [];');
      for (int i = 0; i < base64.length; i += chunkSize) {
        final end = math.min(i + chunkSize, base64.length);
        final chunk = base64.substring(i, end);
        await _controller.runJavaScript(
          'window.__whoEatsIconChunks.push(${jsonEncode(chunk)});',
        );
      }
      await _controller.runJavaScript('''
        (function() {
          var b64 = (window.__whoEatsIconChunks || []).join('');
          if (b64 && window.updateIcon) {
            window.updateIcon('data:image/jpeg;base64,' + b64);
          }
          window.__whoEatsIconChunks = [];
        })();
      ''');
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[FoodPin3DViewer] inject icon failed: $e\n$st');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height ?? 300,
      child: Stack(
        fit: StackFit.expand,
        children: [
          WebViewWidget(controller: _controller),
          if (_loadError != null)
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
