import 'dart:async';

import 'package:geolocator/geolocator.dart';

class LocationService {
  const LocationService();

  Future<bool> requestPermissionIfNeeded() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<Position?> tryGetCurrentPosition() async {
    return _tryGetPosition(
      accuracy: LocationAccuracy.low,
      timeLimit: const Duration(seconds: 5),
    );
  }

  Future<Position?> tryGetFreshPosition() async {
    return _tryGetPosition(
      accuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 12),
    );
  }

  Future<Position?> _tryGetPosition({
    required LocationAccuracy accuracy,
    required Duration timeLimit,
  }) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          timeLimit: timeLimit,
        ),
      );
    } on TimeoutException {
      return Geolocator.getLastKnownPosition();
    } catch (_) {
      return Geolocator.getLastKnownPosition();
    }
  }
}
