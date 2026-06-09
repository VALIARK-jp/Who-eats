// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html';

import 'package:flutter/foundation.dart';

bool googleMapsLoaded = false;
bool googleMapsLoadFailed = false;
String? googleMapsLoadErrorMessage;
final ValueNotifier<bool> googleMapsLoadFailedNotifier = ValueNotifier<bool>(
  false,
);

void _setLoadFailure(String message) {
  googleMapsLoaded = false;
  googleMapsLoadFailed = true;
  googleMapsLoadErrorMessage = message;
  googleMapsLoadFailedNotifier.value = true;
}

Future<void>? _loadingFuture;

Future<void> loadGoogleMapsScript(String apiKey) async {
  if (document.querySelector('script[data-whoeats-google-maps]') != null) {
    if (_loadingFuture != null) {
      await _loadingFuture;
    }
    if (!googleMapsLoadFailed) {
      googleMapsLoaded = true;
      googleMapsLoadErrorMessage = null;
      googleMapsLoadFailedNotifier.value = false;
    }
    return;
  }

  final completer = Completer<void>();
  final script = ScriptElement()
    ..type = 'text/javascript'
    ..async = true
    ..defer = true
    ..src =
        'https://maps.googleapis.com/maps/api/js?key=${Uri.encodeComponent(apiKey)}&libraries=places'
    ..dataset['whoeatsGoogleMaps'] = 'true';

  script.onError.listen((event) {
    if (!completer.isCompleted) {
      _setLoadFailure('Google Maps JavaScript failed to load.');
      completer.completeError(
        StateError('Google Maps JavaScript failed to load.'),
      );
    }
  });
  script.onLoad.listen((event) {
    if (!googleMapsLoadFailed) {
      googleMapsLoaded = true;
      googleMapsLoadFailed = false;
      googleMapsLoadErrorMessage = null;
      googleMapsLoadFailedNotifier.value = false;
    }
    if (!completer.isCompleted) {
      completer.complete();
    }
  });

  document.head?.append(script);
  _loadingFuture = completer.future.timeout(
    const Duration(seconds: 12),
    onTimeout: () {
      _setLoadFailure('Google Maps JavaScript load timed out.');
      throw TimeoutException('Google Maps JavaScript load timed out.');
    },
  );

  try {
    await _loadingFuture;
  } finally {
    _loadingFuture = null;
  }
}
