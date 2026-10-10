import 'dart:math';

import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

double _rad(double d) => d * pi / 180;

/// Great-circle distance in metres.
double haversineM(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000.0;
  final dLat = _rad(lat2 - lat1);
  final dLon = _rad(lon2 - lon1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
  return 2 * r * asin(min(1.0, sqrt(a)));
}

double distLatLng(LatLng a, LatLng b) =>
    haversineM(a.latitude, a.longitude, b.latitude, b.longitude);

/// Greedy nearest-neighbour ordering. Returns indices into [pts].
List<int> nearestNeighborOrder(LatLng start, List<LatLng> pts) {
  final left = List<int>.generate(pts.length, (i) => i);
  final out = <int>[];
  var cur = start;
  while (left.isNotEmpty) {
    left.sort((a, b) => distLatLng(cur, pts[a]).compareTo(distLatLng(cur, pts[b])));
    final next = left.removeAt(0);
    out.add(next);
    cur = pts[next];
  }
  return out;
}

/// GPS fix time is the exact satellite timestamp when the user arrived at the location.
DateTime fixTime(DateTime? t) {
  if (t == null) return DateTime.now();
  return t;
}

String fmtKm(double m) => m < 1000 ? '${m.round()} m' : '${(m / 1000).toStringAsFixed(1)} km';

String fmtDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  return h > 0 ? '${h}h ${m.toString().padLeft(2, '0')}m' : '${m}m';
}

String dateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

String fmtTime(DateTime? d) => d == null ? '--:--' : DateFormat('HH:mm').format(d);
