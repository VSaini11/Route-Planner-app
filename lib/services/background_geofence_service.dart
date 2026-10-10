import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

import '../core/geo.dart';
import '../firebase_options.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
void backgroundTaskCallback() {
  FlutterForegroundTask.setTaskHandler(BackgroundGeofenceTaskHandler());
}

class BackgroundGeofenceTaskHandler extends TaskHandler {
  StreamSubscription<Position>? _locSub;
  String? _routeId;
  String? _workerId;
  String? _workerName;
  DateTime _lastLiveLocUpdate = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      }
    } catch (_) {}

    // Load initial stored route / stop data if any
    final savedRouteId = await FlutterForegroundTask.getData<String>(key: 'routeId');
    final savedWorkerId = await FlutterForegroundTask.getData<String>(key: 'workerId');
    final savedWorkerName = await FlutterForegroundTask.getData<String>(key: 'workerName');

    _routeId = savedRouteId;
    _workerId = savedWorkerId;
    _workerName = savedWorkerName ?? 'Worker';
    
    _initLocationStream();
  }

  void _initLocationStream() {
    _locSub?.cancel();
    _locSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((p) => _processPosition(p));
  }

  @override
  void onReceiveData(Object data) {
    if (data is Map<String, dynamic>) {
      if (data.containsKey('routeId')) _routeId = data['routeId'] as String?;
      if (data.containsKey('workerId')) _workerId = data['workerId'] as String?;
      if (data.containsKey('workerName')) _workerName = data['workerName'] as String?;
    }
  }

  Future<void> _processPosition(Position p) async {
    final routeId = _routeId;
    final workerId = _workerId;
    if (routeId == null || workerId == null) return;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      }
      final db = FirebaseFirestore.instance;

      // Update live worker location every 10s
      final now = DateTime.now();
      if (now.difference(_lastLiveLocUpdate).inSeconds >= 10) {
        _lastLiveLocUpdate = now;
        db.collection('liveLocations').doc(workerId).set({
          'workerId': workerId,
          'workerName': _workerName ?? 'Worker',
          'lat': p.latitude,
          'lng': p.longitude,
          'accuracy': p.accuracy,
          'heading': p.heading,
          'speed': p.speed,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).catchError((Object _) {});
      }

      // Check geofences against stops in Firestore
      final stopsSnap = await db.collection('routes').doc(routeId).collection('stops').get();
      for (final doc in stopsSnap.docs) {
        final data = doc.data();
        final status = data['status'] as String? ?? 'pending';
        final stopLat = (data['lat'] as num?)?.toDouble() ?? 0.0;
        final stopLng = (data['lng'] as num?)?.toDouble() ?? 0.0;
        final radiusM = (data['radiusM'] as num?)?.toDouble() ?? 80.0;
        final name = data['name'] as String? ?? 'Stop';

        final dist = haversineM(p.latitude, p.longitude, stopLat, stopLng);

        // Auto Check-in when entering radius
        if (status == 'pending' && dist <= radiusM && p.accuracy <= 100) {
          final stopRef = doc.reference;
          await db.runTransaction((tx) async {
            final fresh = await tx.get(stopRef);
            if (fresh.data()?['status'] == 'pending') {
              tx.update(stopRef, {
                'status': 'checkedin',
                'checkInAt': Timestamp.fromDate(DateTime.now()),
                'checkInServerAt': FieldValue.serverTimestamp(),
                'checkInLat': p.latitude,
                'checkInLng': p.longitude,
                'checkInAccuracy': p.accuracy,
                'checkInAuto': true,
              });
            }
          });

          await NotificationService.instance.showLocal(
            'Checked in',
            'You arrived at $name',
          );
        }
        // Auto Check-out when leaving radius
        else if (status == 'checkedin') {
          final exitRadius = radiusM + (radiusM * 0.15).clamp(15.0, 60.0);
          if (dist > exitRadius && p.accuracy <= 100) {
            final stopRef = doc.reference;
            Duration? worked;
            await db.runTransaction((tx) async {
              final fresh = await tx.get(stopRef);
              final m = fresh.data();
              if (m != null && m['status'] == 'checkedin') {
                final inAt = (m['checkInAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                final out = DateTime.now();
                final w = out.isBefore(inAt) ? Duration.zero : out.difference(inAt);
                worked = w;
                tx.update(stopRef, {
                  'status': 'done',
                  'checkOutAt': Timestamp.fromDate(out),
                  'checkOutServerAt': FieldValue.serverTimestamp(),
                  'workedMinutes': w.inSeconds / 60.0,
                  'checkOutAuto': true,
                });
              }
            });

            if (worked != null) {
              await NotificationService.instance.showLocal(
                'Checked out',
                'You left $name. Worked ${fmtDuration(worked!)}',
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Background tracking error: $e');
    }
  }

  Future<void> _checkPendingNotifications() async {
    final workerId = _workerId;
    if (workerId == null) return;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      }
      final db = FirebaseFirestore.instance;
      final now = DateTime.now();

      // Query notifications targeted to this worker that haven't been delivered
      final snap = await db
          .collection('notifyQueue')
          .where('toUid', isEqualTo: workerId)
          .where('delivered', isEqualTo: false)
          .get();

      for (final doc in snap.docs) {
        final d = doc.data();
        final sendAt = (d['sendAt'] as Timestamp?)?.toDate();
        final time = (d['time'] as Timestamp?)?.toDate() ?? now;

        // If scheduled time has arrived or was immediate
        final due = sendAt == null ? time.isBefore(now.add(const Duration(seconds: 10))) : sendAt.isBefore(now);
        if (due) {
          await doc.reference.update({'delivered': true, 'deliveredAt': FieldValue.serverTimestamp()});
          await NotificationService.instance.showLocal(
            (d['title'] ?? 'Notification') as String,
            (d['body'] ?? '') as String,
          );
        }
      }
    } catch (e) {
      debugPrint('Background notification check error: $e');
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _checkPendingNotifications();
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _locSub?.cancel();
    _locSub = null;
  }
}
