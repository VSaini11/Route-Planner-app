import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../models/live_worker.dart';
import '../models/new_stop.dart';
import '../models/route_plan.dart';
import '../models/route_stop.dart';

class RouteRepo {
  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _stop(String routeId, String stopId) =>
      _db.collection('routes').doc(routeId).collection('stops').doc(stopId);

  // ---------- reading ----------
  Stream<RoutePlan?> watchRoute(String workerId, String date) => _db
      .collection('routes')
      .where('workerId', isEqualTo: workerId)
      .where('date', isEqualTo: date)
      .limit(1)
      .snapshots()
      .map((q) => q.docs.isEmpty ? null : RoutePlan.fromDoc(q.docs.first));

  Stream<List<RouteStop>> watchStops(String routeId) => _db
      .collection('routes')
      .doc(routeId)
      .collection('stops')
      .orderBy('order')
      .snapshots()
      .map((q) => q.docs.map(RouteStop.fromDoc).toList());

  Stream<List<LiveWorker>> watchLiveWorkers() => _db
      .collection('liveLocations')
      .snapshots()
      .map((q) => q.docs.map(LiveWorker.fromDoc).toList());

  // ---------- admin: create a route ----------
  Future<void> createRoute({
    required String workerId,
    required String workerName,
    required String date,
    required List<NewStop> stops,
  }) async {
    final routeRef = _db.collection('routes').doc();
    final batch = _db.batch();
    batch.set(routeRef, {
      'workerId': workerId,
      'workerName': workerName,
      'date': date,
      'createdAt': FieldValue.serverTimestamp(),
    });
    for (var i = 0; i < stops.length; i++) {
      final s = stops[i];
      batch.set(routeRef.collection('stops').doc(), {
        'order': i,
        'name': s.name,
        'lat': s.lat,
        'lng': s.lng,
        'radiusM': s.radiusM,
        'target': s.target,
        'notes': '',
        'status': 'pending',
        'tasks': s.tasks.map((t) => t.toMap()).toList(),
      });
    }
    // A Cloud Function watches this collection and sends the push notification.
    batch.set(_db.collection('notifyQueue').doc(), {
      'toUid': workerId,
      'title': 'New route for $date',
      'body': '${stops.length} stops assigned to you',
      'time': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> sendCustomNotification({
    required String? toUid, // null means broadcast to all workers
    required String title,
    required String body,
    DateTime? sendAt,
  }) async {
    final timeVal = sendAt != null ? Timestamp.fromDate(sendAt) : FieldValue.serverTimestamp();
    if (toUid != null) {
      await _db.collection('notifyQueue').add({
        'toUid': toUid,
        'title': title,
        'body': body,
        'time': timeVal,
        'sendAt': sendAt != null ? Timestamp.fromDate(sendAt) : null,
        'delivered': false,
      });
    } else {
      final workersSnap = await _db.collection('users').where('role', isEqualTo: 'worker').get();
      final batch = _db.batch();
      for (final doc in workersSnap.docs) {
        batch.set(_db.collection('notifyQueue').doc(), {
          'toUid': doc.id,
          'title': title,
          'body': body,
          'time': timeVal,
          'sendAt': sendAt != null ? Timestamp.fromDate(sendAt) : null,
          'delivered': false,
        });
      }
      await batch.commit();
    }
  }

  Future<void> deleteRoute(String routeId) async {
    final stopsSnap = await _db.collection('routes').doc(routeId).collection('stops').get();
    final batch = _db.batch();
    for (final doc in stopsSnap.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_db.collection('routes').doc(routeId));
    await batch.commit();
  }

  Future<void> updateOrder(String routeId, List<String> orderedIds) async {
    final batch = _db.batch();
    for (var i = 0; i < orderedIds.length; i++) {
      batch.update(_stop(routeId, orderedIds[i]), {'order': i});
    }
    await batch.commit();
  }

  // ---------- worker: check in / out ----------
  /// Idempotent: does nothing unless the stop is still `pending`.
  Future<void> checkIn(
    String routeId,
    String stopId,
    DateTime at, {
    required double lat,
    required double lng,
    required double accuracy,
    required bool auto,
  }) async {
    final ref = _stop(routeId, stopId);
    await _db.runTransaction((tx) async {
      final s = await tx.get(ref);
      if (s.data()?['status'] != 'pending') return;
      tx.update(ref, {
        'status': 'checkedin',
        'checkInAt': Timestamp.fromDate(at),
        'checkInServerAt': FieldValue.serverTimestamp(),
        'checkInLat': lat,
        'checkInLng': lng,
        'checkInAccuracy': accuracy,
        'checkInAuto': auto,
      });
    });
  }

  /// Idempotent: does nothing unless the stop is `checkedin`. Returns the worked time.
  Future<Duration?> checkOut(
    String routeId,
    String stopId,
    DateTime at, {
    bool auto = false,
  }) async {
    final ref = _stop(routeId, stopId);
    Duration? worked;
    await _db.runTransaction((tx) async {
      final s = await tx.get(ref);
      final m = s.data();
      if (m == null || m['status'] != 'checkedin') return;
      final inAt = (m['checkInAt'] as Timestamp).toDate();
      final out = at.isBefore(inAt) ? inAt : at;
      final w = out.difference(inAt);
      worked = w;
      tx.update(ref, {
        'status': 'done',
        'checkOutAt': Timestamp.fromDate(out),
        'checkOutServerAt': FieldValue.serverTimestamp(),
        'workedMinutes': w.inSeconds / 60.0,
        'checkOutAuto': auto,
      });
    });
    return worked;
  }

  // ---------- worker: tasks, notes, photos ----------
  Future<void> setTask(String routeId, String stopId, int index,
      {bool? done, String? photoUrl}) async {
    final ref = _stop(routeId, stopId);
    await _db.runTransaction((tx) async {
      final s = await tx.get(ref);
      final list = ((s.data()?['tasks'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (index >= list.length) return;
      if (done != null) list[index]['done'] = done;
      if (photoUrl != null) list[index]['photoUrl'] = photoUrl;
      tx.update(ref, {'tasks': list});
    });
  }

  Future<void> saveNotes(String routeId, String stopId, String notes) =>
      _stop(routeId, stopId).update({'notes': notes});

  Future<String> uploadProof(String routeId, String stopId, XFile file) async {
    final bytes = await file.readAsBytes();
    final base64String = base64Encode(bytes);
    return 'data:image/jpeg;base64,$base64String';
  }

  // ---------- live location ----------
  Future<void> publishLocation(String uid, String name, Position p) =>
      _db.collection('liveLocations').doc(uid).set({
        'name': name,
        'lat': p.latitude,
        'lng': p.longitude,
        'accuracy': p.accuracy,
        'heading': p.heading,
        'speed': p.speed,
        'updatedAt': FieldValue.serverTimestamp(),
      });
}
