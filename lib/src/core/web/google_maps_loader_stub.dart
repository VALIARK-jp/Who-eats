import 'package:flutter/foundation.dart';

bool googleMapsLoaded = true;
bool googleMapsLoadFailed = false;
String? googleMapsLoadErrorMessage;
final ValueNotifier<bool> googleMapsLoadFailedNotifier = ValueNotifier<bool>(false);

Future<void> loadGoogleMapsScript(String apiKey) async {
  googleMapsLoaded = true;
  googleMapsLoadFailed = false;
  googleMapsLoadErrorMessage = null;
  googleMapsLoadFailedNotifier.value = false;
}
