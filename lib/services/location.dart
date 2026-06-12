import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Provides the device GPS position. After the first successful fix a
/// position stream keeps [position] updated so distances stay current.
class LocationService {
  LocationService._();

  static final ValueNotifier<Position?> position = ValueNotifier(null);
  static StreamSubscription<Position>? _sub;

  static Future<bool> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    return p == LocationPermission.always ||
        p == LocationPermission.whileInUse;
  }

  /// Requests permission if needed and returns the current position,
  /// or null when location is unavailable or denied.
  static Future<Position?> locate() async {
    try {
      if (!await _ensurePermission()) return null;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      position.value = pos;
      _startStream();
      return pos;
    } catch (_) {
      return null;
    }
  }

  static void _startStream() {
    _sub ??= Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((p) => position.value = p, onError: (_) {});
  }

  /// Distance in meters from the last known position to (lat, lng),
  /// or null when no fix is available yet.
  static double? distanceTo(double lat, double lng) {
    final pos = position.value;
    if (pos == null) return null;
    return Geolocator.distanceBetween(pos.latitude, pos.longitude, lat, lng);
  }

  static String formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} 公尺';
    return '${(meters / 1000).toStringAsFixed(1)} 公里';
  }
}
