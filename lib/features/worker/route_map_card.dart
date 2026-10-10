import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme.dart';
import '../../data/models/route_stop.dart';
import '../../services/routing_service.dart';
import '../common/realistic_car_marker.dart';

/// OpenStreetMap with: planned route line, numbered stops, the admin's geofence
/// circle around each stop (radius in real metres), and the worker's live car marker.
class RouteMapCard extends StatefulWidget {
  final List<RouteStop> stops;
  final RouteGeometry geometry;
  final Position? position;
  final VoidCallback onOptimize;

  const RouteMapCard({
    super.key,
    required this.stops,
    required this.geometry,
    required this.position,
    required this.onOptimize,
  });

  @override
  State<RouteMapCard> createState() => _RouteMapCardState();
}

class _RouteMapCardState extends State<RouteMapCard> {
  final _c = MapController();
  bool _ready = false;
  String _lastKey = '';

  String get _key => widget.stops.map((s) => s.id).join(',');

  @override
  void didUpdateWidget(RouteMapCard old) {
    super.didUpdateWidget(old);
    if (_ready && _key != _lastKey) {
      _lastKey = _key;
      _fit();
    }
  }

  LatLng? get _me {
    final p = widget.position;
    return p == null ? null : LatLng(p.latitude, p.longitude);
  }

  void _fit() {
    final pts = <LatLng>[
      ...widget.stops.map((s) => LatLng(s.lat, s.lng)),
      if (_me != null) _me!,
    ];
    if (pts.isEmpty) return;
    if (pts.length == 1) {
      _c.move(pts.first, 15);
      return;
    }
    _c.fitCamera(CameraFit.coordinates(
      coordinates: pts,
      padding: const EdgeInsets.fromLTRB(48, 48, 48, 96),
    ));
  }

  void _zoom(double delta) {
    if (!_ready) return;
    final cam = _c.camera;
    _c.move(cam.center, (cam.zoom + delta).clamp(3.0, 19.0));
  }

  double _getHeading(LatLng me) {
    if (widget.position != null && widget.position!.heading > 0) {
      return widget.position!.heading;
    }
    if (widget.stops.isNotEmpty) {
      final target = LatLng(widget.stops.first.lat, widget.stops.first.lng);
      final dLng = (target.longitude - me.longitude) * (math.pi / 180.0);
      final lat1 = me.latitude * (math.pi / 180.0);
      final lat2 = target.latitude * (math.pi / 180.0);
      final y = math.sin(dLng) * math.cos(lat2);
      final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
      final brng = math.atan2(y, x) * (180.0 / math.pi);
      return (brng + 360) % 360;
    }
    return 0;
  }

  Color _stopColor(RouteStop s) =>
      s.isDone ? kGreen : (s.isCheckedIn ? kPrimary : kNavy);

  @override
  Widget build(BuildContext context) {
    final me = _me;
    final acc = widget.position?.accuracy ?? 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: SizedBox(
          height: 380,
          child: Stack(children: [
            FlutterMap(
              mapController: _c,
              options: MapOptions(
                initialCenter: me ??
                    (widget.stops.isNotEmpty
                        ? LatLng(widget.stops.first.lat, widget.stops.first.lng)
                        : const LatLng(28.6139, 77.2090)),
                initialZoom: 12,
                interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                onMapReady: () {
                  _ready = true;
                  _lastKey = _key;
                  _fit();
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.yourcompany.fieldroute',
                ),
                // Geofence circle around each stop, sized by the admin's radius.
                CircleLayer(circles: [
                  for (final s in widget.stops)
                    CircleMarker(
                      point: LatLng(s.lat, s.lng),
                      radius: s.radiusM,
                      useRadiusInMeter: true,
                      color: _stopColor(s).withValues(alpha: 0.15),
                      borderColor: _stopColor(s),
                      borderStrokeWidth: 2,
                    ),
                ]),
                PolylineLayer(polylines: [
                  // Underlay casing line
                  Polyline(
                    points: widget.geometry.points,
                    strokeWidth: 8,
                    color: const Color(0xFF0F172A).withValues(alpha: 0.8),
                    borderStrokeWidth: 2,
                    borderColor: Colors.white,
                  ),
                  // Glowing active navigation route line
                  Polyline(
                    points: widget.geometry.points,
                    strokeWidth: 5,
                    color: const Color(0xFF3B82F6),
                  ),
                ]),
                MarkerLayer(markers: [
                  for (var i = 0; i < widget.stops.length; i++)
                    Marker(
                      point: LatLng(widget.stops[i].lat, widget.stops[i].lng),
                      width: 44,
                      height: 44,
                      child: _Pin(number: i + 1, color: _stopColor(widget.stops[i])),
                    ),
                ]),
                if (me != null) ...[
                  CircleLayer(circles: [
                    CircleMarker(
                      point: me,
                      radius: acc.clamp(5, 80),
                      useRadiusInMeter: true,
                      color: kPrimary.withValues(alpha: 0.12),
                      borderColor: kPrimary.withValues(alpha: 0.4),
                      borderStrokeWidth: 1.5,
                    ),
                  ]),
                  MarkerLayer(markers: [
                    Marker(
                      point: me,
                      width: 64,
                      height: 64,
                      child: RealisticCarMarker(heading: _getHeading(me), size: 64),
                    ),
                  ]),
                ],
                const RichAttributionWidget(
                  alignment: AttributionAlignment.bottomRight,
                  attributions: [TextSourceAttribution('© OpenStreetMap contributors')],
                ),
              ],
            ),
            Positioned(
              top: 14,
              right: 14,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
                  ],
                ),
                child: Column(children: [
                  IconButton(
                    icon: const Icon(Icons.add_rounded, size: 20),
                    onPressed: () => _zoom(1),
                  ),
                  Container(
                    height: 1,
                    width: 28,
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_rounded, size: 20),
                    onPressed: () => _zoom(-1),
                  ),
                ]),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 24,
              child: Row(children: [
                Expanded(
                  child: _MapButton(
                    icon: Icons.directions_car_filled_rounded,
                    label: 'Focus Vehicle',
                    onTap: me == null || !_ready ? null : () => _c.move(me, 16),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MapButton(
                    icon: Icons.crop_free_rounded,
                    label: 'Fit Route',
                    onTap: _ready ? _fit : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MapButton(
                    icon: Icons.auto_awesome_rounded,
                    label: 'AI Optimize',
                    primary: true,
                    onTap: widget.onOptimize,
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool primary;
  final VoidCallback? onTap;
  const _MapButton({required this.icon, required this.label, this.primary = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: FittedBox(child: Text(label)),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        backgroundColor: primary
            ? kPrimary
            : (isDark ? const Color(0xFF0F172A).withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.95)),
        foregroundColor: primary ? Colors.white : (isDark ? Colors.white : kNavy),
        elevation: 4,
        shadowColor: Colors.black38,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5),
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  final int number;
  final Color color;
  const _Pin({required this.number, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(blurRadius: 8, color: Colors.black45, offset: Offset(0, 3)),
          ],
        ),
        child: Text('$number',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
      );
}
