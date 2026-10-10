import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Android: a foreground service with a visible notification keeps location updates
  /// alive when the screen is off or the app is in the background (this is the
  /// Play-Store-accepted way). iOS: background location mode with the blue indicator.
  static LocationSettings settings() {
    if (_isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        intervalDuration: const Duration(seconds: 5),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Route tracking is on',
          notificationText: 'Location is used for check-in and check-out at client sites.',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    if (_isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 5,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    }
    return const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5);
  }

  static Stream<Position> positions() =>
      Geolocator.getPositionStream(locationSettings: settings());
}
