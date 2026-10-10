import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme.dart';

/// Admin taps the map to choose the client site; the circle previews the check-in radius.
class LocationPickerScreen extends StatefulWidget {
  final LatLng? initial;
  final double radiusM;
  const LocationPickerScreen({super.key, this.initial, required this.radiusM});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _c = MapController();
  LatLng? _point;

  @override
  void initState() {
    super.initState();
    _point = widget.initial;
  }

  Future<void> _myLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      final p = await Geolocator.getCurrentPosition();
      final ll = LatLng(p.latitude, p.longitude);
      _c.move(ll, 16);
      setState(() => _point = ll);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final pt = _point;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location on Map', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      ),
      body: Stack(children: [
        FlutterMap(
          mapController: _c,
          options: MapOptions(
            initialCenter: widget.initial ?? const LatLng(28.6139, 77.2090),
            initialZoom: widget.initial != null ? 16 : 11,
            onTap: (_, ll) => setState(() => _point = ll),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.yourcompany.fieldroute',
            ),
            if (pt != null)
              CircleLayer(circles: [
                CircleMarker(
                  point: pt,
                  radius: widget.radiusM,
                  useRadiusInMeter: true,
                  color: kPrimary.withValues(alpha: 0.18),
                  borderColor: kPrimary,
                  borderStrokeWidth: 2,
                ),
              ]),
            if (pt != null)
              MarkerLayer(markers: [
                Marker(
                  point: pt,
                  width: 52,
                  height: 52,
                  alignment: Alignment.topCenter,
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 4)),
                      ],
                    ),
                    child: const Icon(Icons.location_on_rounded, color: kRed, size: 48),
                  ),
                ),
              ]),
            const RichAttributionWidget(
              alignment: AttributionAlignment.bottomLeft,
              attributions: [TextSourceAttribution('© OpenStreetMap contributors')],
            ),
          ],
        ),
        Positioned(
          top: 14,
          left: 14,
          right: 14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              ),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.touch_app_rounded, color: kPrimary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    pt == null
                        ? 'Tap anywhere on the map to place site marker'
                        : 'GPS: ${pt.latitude.toStringAsFixed(5)}, ${pt.longitude.toStringAsFixed(5)} (${widget.radiusM.round()}m)',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 100,
          child: FloatingActionButton(
            heroTag: 'myloc',
            backgroundColor: isDark ? const Color(0xFF131D2E) : Colors.white,
            foregroundColor: kPrimary,
            elevation: 4,
            onPressed: _myLocation,
            child: const Icon(Icons.my_location_rounded),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 24,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: pt == null
                  ? null
                  : const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                    ),
              boxShadow: pt == null
                  ? null
                  : [
                      BoxShadow(
                        color: kPrimary.withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: pt == null ? Colors.grey.withValues(alpha: 0.3) : Colors.transparent,
                shadowColor: Colors.transparent,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: pt == null ? null : () => Navigator.pop(context, pt),
              icon: Icon(Icons.check_rounded, color: pt == null ? Colors.grey : Colors.white),
              label: Text(
                pt == null ? 'Tap the map to set coordinate' : 'Confirm & Use Selected Coordinate',
                style: TextStyle(
                  color: pt == null ? Colors.grey : Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
