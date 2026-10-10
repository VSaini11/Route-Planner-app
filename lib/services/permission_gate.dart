import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Asks for location (foreground, then background) and notifications.
///
/// Google Play requires a "prominent disclosure" screen BEFORE the system
/// permission prompt for background location. The two dialogs below are that disclosure.
class PermissionGate {
  static Future<bool> ensure(BuildContext context) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (!context.mounted) return false;
      await _info(context, 'Turn on location',
          'Please switch on Location (GPS) in your phone settings.', 'Open settings',
          () async {
        await Geolocator.openLocationSettings();
      });
      return false;
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      if (!context.mounted) return false;
      final ok = await _disclosure(
        context,
        title: 'Location access',
        body: 'FieldRoute uses your location to show your route on the map and to '
            'check you in and out when you arrive at and leave a client site. '
            'Your manager can see your live location while your route is active.',
      );
      if (ok != true) return false;
      perm = await Geolocator.requestPermission();
    }

    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      if (!context.mounted) return false;
      await _info(context, 'Location is off for this app',
          'Open app settings and allow Location so check-in works.', 'Open app settings',
          () async {
        await openAppSettings();
      });
      return false;
    }

    // Android 11+ and iOS: "Allow all the time" is requested separately.
    if (!kIsWeb && perm == LocationPermission.whileInUse) {
      final bg = await Permission.locationAlways.status;
      if (!bg.isGranted && context.mounted) {
        final ok = await _disclosure(
          context,
          title: 'Allow location all the time',
          body: 'FieldRoute collects location data in the background, even when the app is '
              'closed or not in use, so that check-in and check-out at client sites and your '
              'worked hours are recorded accurately. On the next screen choose '
              '"Allow all the time".',
        );
        if (ok == true) await Permission.locationAlways.request();
      }
    }

    if (!kIsWeb) await Permission.notification.request();
    return true;
  }

  static Future<bool?> _disclosure(BuildContext context,
      {required String title, required String body}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.location_on_rounded, size: 36),
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not now')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  static Future<void> _info(BuildContext context, String title, String body, String action,
      Future<void> Function() onAction) {
    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
            onPressed: () async {
              Navigator.pop(context);
              await onAction();
            },
            child: Text(action),
          ),
        ],
      ),
    );
  }
}
