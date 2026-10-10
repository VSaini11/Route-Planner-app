import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../core/geo.dart';

class RouteGeometry {
  final List<LatLng> points; // the line drawn on the map
  final double totalMeters;
  final List<double> legMeters; // distance between consecutive stops (length = stops - 1)
  final bool roads; // false = straight-line fallback

  const RouteGeometry({
    required this.points,
    required this.totalMeters,
    required this.legMeters,
    required this.roads,
  });

  factory RouteGeometry.straight(List<LatLng> stops) {
    final legs = <double>[];
    for (var i = 1; i < stops.length; i++) {
      legs.add(distLatLng(stops[i - 1], stops[i]));
    }
    return RouteGeometry(
      points: stops,
      totalMeters: legs.fold(0.0, (a, b) => a + b),
      legMeters: legs,
      roads: false,
    );
  }
}

class RoutingService {
  /// Road route through the stops using the public OSRM demo server.
  /// Good for development and small teams. For production, self-host OSRM or use
  /// OpenRouteService / Mapbox / Google Directions and change only this method.
  /// Never throws: falls back to straight lines if the request fails.
  static Future<RouteGeometry> drivingRoute(List<LatLng> stops) async {
    if (stops.length < 2) return RouteGeometry.straight(stops);
    try {
      final coords = stops.map((p) => '${p.longitude},${p.latitude}').join(';');
      final uri = Uri.parse(
          'https://router.project-osrm.org/route/v1/driving/$coords?overview=full&geometries=geojson');
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return RouteGeometry.straight(stops);

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final routes = json['routes'] as List?;
      if (routes == null || routes.isEmpty) return RouteGeometry.straight(stops);

      final r = routes.first as Map<String, dynamic>;
      final line = (r['geometry']['coordinates'] as List)
          .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
      final legs = (r['legs'] as List)
          .map((l) => ((l as Map)['distance'] as num).toDouble())
          .toList();
      return RouteGeometry(
        points: line,
        totalMeters: (r['distance'] as num).toDouble(),
        legMeters: legs,
        roads: true,
      );
    } catch (_) {
      return RouteGeometry.straight(stops);
    }
  }
}
