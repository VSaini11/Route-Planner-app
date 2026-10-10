import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../core/geo.dart';
import '../data/models/route_plan.dart';
import '../providers.dart';
import 'background_geofence_service.dart';
import 'geofence_engine.dart';
import 'location_service.dart';
import 'notification_service.dart';

class TrackingState {
  final Position? position;
  final bool active;
  final String? error;
  const TrackingState({this.position, this.active = false, this.error});
}

/// Listens to GPS, publishes the live location, and performs automatic
/// check-in / check-out when the worker enters / leaves a stop's radius.
/// Uses background foreground task so it works continuously even when app is closed.
class TrackingNotifier extends Notifier<TrackingState> {
  StreamSubscription<Position>? _sub;
  final _engine = GeofenceEngine();
  DateTime _lastPublish = DateTime.fromMillisecondsSinceEpoch(0);
  RoutePlan? _plan;
  String _workerName = 'Worker';

  @override
  TrackingState build() {
    ref.onDispose(() {
      _sub?.cancel();
      _stopBackgroundTask();
    });
    return const TrackingState();
  }

  Future<void> _startBackgroundTask(RoutePlan? plan, String workerName) async {
    if (kIsWeb) return;
    try {
      await FlutterForegroundTask.saveData(key: 'routeId', value: plan?.id ?? '');
      await FlutterForegroundTask.saveData(key: 'workerId', value: plan?.workerId ?? '');
      await FlutterForegroundTask.saveData(key: 'workerName', value: workerName);

      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'visits',
          channelName: 'Check-in and check-out',
          channelDescription: 'Monitors client site arrivals and departures in the background.',
          channelImportance: NotificationChannelImportance.HIGH,
          priority: NotificationPriority.HIGH,
        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: true,
          playSound: false,
        ),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.repeat(5000),
          autoRunOnBoot: true,
          autoRunOnMyPackageReplaced: true,
          allowWakeLock: true,
          allowWifiLock: true,
        ),
      );

      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.restartService();
      } else {
        await FlutterForegroundTask.startService(
          serviceId: 256,
          notificationTitle: 'FieldRoute is active',
          notificationText: 'Tracking location for automated check-in and check-out.',
          callback: backgroundTaskCallback,
        );
      }

      FlutterForegroundTask.sendDataToTask({
        'routeId': plan?.id,
        'workerId': plan?.workerId,
        'workerName': workerName,
      });
    } catch (e) {
      debugPrint('Error starting background task: $e');
    }
  }

  Future<void> _stopBackgroundTask() async {
    if (kIsWeb) return;
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (_) {}
  }

  Future<void> start(RoutePlan? plan, String workerName) async {
    _plan = plan;
    _workerName = workerName;
    if (_sub != null) return;
    _engine.reset();
    
    await _startBackgroundTask(plan, workerName);

    try {
      final p = await Geolocator.getCurrentPosition();
      _onPosition(p);
    } catch (_) {}
    _sub = LocationService.positions().listen(
      _onPosition,
      onError: (Object e) => state = TrackingState(position: state.position, error: '$e'),
    );
    state = TrackingState(position: state.position, active: true);
  }

  void updatePlan(RoutePlan? plan) {
    _plan = plan;
    if (!kIsWeb && plan != null) {
      FlutterForegroundTask.sendDataToTask({
        'routeId': plan.id,
        'workerId': plan.workerId,
        'workerName': _workerName,
      });
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _plan = null;
    _engine.reset();
    await _stopBackgroundTask();
    state = const TrackingState();
  }

  Future<void> _onPosition(Position p) async {
    state = TrackingState(position: p, active: true);
    final plan = _plan;
    if (plan == null) return;
    final repo = ref.read(routeRepoProvider);

    // Live location for the admin map (every 10 s is plenty and saves battery/cost).
    final now = DateTime.now();
    if (now.difference(_lastPublish).inSeconds >= 10) {
      _lastPublish = now;
      repo.publishLocation(plan.workerId, _workerName, p).catchError((Object _) {});
    }

    final stopsAsync = ref.read(stopsProvider(plan.id));
    final stops = stopsAsync.valueOrNull;
    if (stops == null || stops.isEmpty) return;

    for (final e in _engine.evaluate(p, stops)) {
      try {
        if (e.type == GeofenceType.enter) {
          debugPrint('>>> GEOFENCE ENTER: Checking in to ${e.stop.name}');
          await repo.checkIn(plan.id, e.stop.id, fixTime(p.timestamp),
              lat: p.latitude, lng: p.longitude, accuracy: p.accuracy, auto: true);
          await NotificationService.instance
              .showLocal('Checked in', 'You arrived at ${e.stop.name}');
        } else {
          debugPrint('>>> GEOFENCE EXIT: Checking out of ${e.stop.name}');
          final worked = await repo.checkOut(plan.id, e.stop.id, fixTime(p.timestamp), auto: true);
          await NotificationService.instance.showLocal(
              'Checked out',
              worked == null
                  ? 'You left ${e.stop.name}'
                  : 'You left ${e.stop.name}. Worked ${fmtDuration(worked)}');
        }
      } catch (err, st) {
        debugPrint('>>> GEOFENCE ACTION ERROR: $err\n$st');
      }
    }
  }
}

final trackingProvider = NotifierProvider<TrackingNotifier, TrackingState>(TrackingNotifier.new);
