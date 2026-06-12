import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// 地図 3D ピン用: ネットワークアイコンを data URL に変換してキャッシュ。
abstract final class MapPinIconPreloader {
  static final Map<String, String> _dataUrlCache = {};

  static Future<String?> resolveDataUrl(String? url) async {
    final trimmed = url?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('data:')) return trimmed;

    final cached = _dataUrlCache[trimmed];
    if (cached != null) return cached;

    try {
      final response = await http.get(Uri.parse(trimmed));
      if (response.statusCode != 200) return trimmed;
      final mime = _mimeFromBytes(response.bodyBytes);
      final dataUrl =
          'data:$mime;base64,${base64Encode(response.bodyBytes)}';
      _dataUrlCache[trimmed] = dataUrl;
      return dataUrl;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[MapPinIconPreloader] preload failed: $e\n$st');
      }
      return trimmed;
    }
  }

  static Future<void> preloadAll(Iterable<String> urls) async {
    final unique = urls.map((u) => u.trim()).where((u) => u.isNotEmpty).toSet();
    if (unique.isEmpty) return;
    await Future.wait(unique.map(resolveDataUrl));
  }

  static String _mimeFromBytes(List<int> bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }
}
