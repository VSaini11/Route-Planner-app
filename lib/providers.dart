import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'data/models/live_worker.dart';
import 'data/models/route_plan.dart';
import 'data/models/route_stop.dart';
import 'data/models/user_profile.dart';
import 'data/repositories/route_repo.dart';
import 'services/routing_service.dart';

final authStateProvider =
    StreamProvider<User?>((ref) => FirebaseAuth.instance.authStateChanges());

final profileProvider = StreamProvider<UserProfile?>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(null);
  return FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots().map((s) {
    if (!s.exists) return null;
    final d = s.data();
    if (d == null) return null;
    return UserProfile(user.uid, (d['name'] ?? 'User') as String, (d['role'] ?? 'worker') as String);
  });
});

final routeRepoProvider = Provider((ref) => RouteRepo());

/// The date shown on the My Route screen.
final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

/// Route of the signed-in worker for a given yyyy-MM-dd.
final routeProvider = StreamProvider.family<RoutePlan?, String>((ref, date) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(null);
  return ref.watch(routeRepoProvider).watchRoute(user.uid, date);
});

/// Route of any worker by workerId and date (for Admin)
final workerRouteProvider = StreamProvider.family<RoutePlan?, ({String workerId, String date})>((ref, arg) {
  return ref.watch(routeRepoProvider).watchRoute(arg.workerId, arg.date);
});

final stopsProvider = StreamProvider.family<List<RouteStop>, String>(
    (ref, routeId) => ref.watch(routeRepoProvider).watchStops(routeId));

final workersProvider = StreamProvider<List<UserProfile>>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .where('role', isEqualTo: 'worker')
      .snapshots()
      .map((q) => q.docs
          .map((d) => UserProfile(d.id, (d['name'] ?? 'Worker') as String, 'worker'))
          .toList());
});

final liveWorkersProvider = StreamProvider<List<LiveWorker>>(
    (ref) => ref.watch(routeRepoProvider).watchLiveWorkers());

/// Road geometry for a list of stops. Key format: "lat,lng;lat,lng;..."
/// (a String key so Riverpod can cache by value).
final routeGeometryProvider = FutureProvider.family<RouteGeometry, String>((ref, key) {
  final pts = key
      .split(';')
      .where((e) => e.isNotEmpty)
      .map((e) {
        final p = e.split(',');
        return LatLng(double.parse(p[0]), double.parse(p[1]));
      })
      .toList();
  return RoutingService.drivingRoute(pts);
});
