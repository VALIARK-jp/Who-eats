import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class DeviceLatLng {
  const DeviceLatLng({required this.lat, required this.lng});

  final double lat;
  final double lng;
}

/// Returns null if services are off, permission denied, or lookup fails.
Future<DeviceLatLng?> readDeviceLatLng() async {
  if (kIsWeb) return null;
  try {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 18),
      ),
    );
    return DeviceLatLng(lat: pos.latitude, lng: pos.longitude);
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('[DeviceLocation] readDeviceLatLng failed: $e\n$st');
    }
    return null;
  }
}
