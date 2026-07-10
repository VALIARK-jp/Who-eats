import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class DeviceLatLng {
  const DeviceLatLng({required this.lat, required this.lng});

  final double lat;
  final double lng;
}

enum DeviceLocationAccessStatus {
  granted,
  servicesDisabled,
  denied,
  deniedForever,
  unavailable,
}

class DeviceLocationAccessResult {
  const DeviceLocationAccessResult({
    required this.status,
    this.location,
  });

  final DeviceLocationAccessStatus status;
  final DeviceLatLng? location;

  bool get isGranted =>
      status == DeviceLocationAccessStatus.granted && location != null;
}

Future<DeviceLocationAccessResult> resolveDeviceLocationAccess({
  bool requestIfNeeded = true,
}) async {
  try {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const DeviceLocationAccessResult(
        status: DeviceLocationAccessStatus.servicesDisabled,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && requestIfNeeded) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      return const DeviceLocationAccessResult(
        status: DeviceLocationAccessStatus.denied,
      );
    }
    if (permission == LocationPermission.deniedForever) {
      return const DeviceLocationAccessResult(
        status: DeviceLocationAccessStatus.deniedForever,
      );
    }

    // まず端末キャッシュ（最後の既知位置）を即座に返し、地図表示の待ちを消す。
    // 実測は呼び出し側が必要に応じて別途行う。
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        return DeviceLocationAccessResult(
          status: DeviceLocationAccessStatus.granted,
          location: DeviceLatLng(
            lat: lastKnown.latitude,
            lng: lastKnown.longitude,
          ),
        );
      }
    } catch (_) {
      // 取得できない環境（初回・iOS の一部）では実測にフォールバックする。
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 18),
      ),
    );
    return DeviceLocationAccessResult(
      status: DeviceLocationAccessStatus.granted,
      location: DeviceLatLng(lat: pos.latitude, lng: pos.longitude),
    );
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('[DeviceLocation] resolveDeviceLocationAccess failed: $e\n$st');
    }
    return const DeviceLocationAccessResult(
      status: DeviceLocationAccessStatus.unavailable,
    );
  }
}

Future<void> openDeviceLocationSettings() async {
  final opened = await Geolocator.openLocationSettings();
  if (opened) return;
  await Geolocator.openAppSettings();
}

/// Returns null if services are off, permission denied, or lookup fails.
Future<DeviceLatLng?> readDeviceLatLng() async {
  final result = await resolveDeviceLocationAccess(requestIfNeeded: true);
  return result.location;
}
