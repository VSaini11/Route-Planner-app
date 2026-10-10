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
    return Scaffold(
      appBar: AppBar(title: const Text('Tap the client location')),
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
                  color: kBlue.withValues(alpha: 0.15),
                  borderColor: kBlue,
                  borderStrokeWidth: 2,
                ),
              ]),
            if (pt != null)
              MarkerLayer(markers: [
                Marker(
                  point: pt,
                  width: 48,
                  height: 48,
                  alignment: Alignment.topCenter,
                  child: const Icon(Icons.location_on, color: kRed, size: 48),
                ),
              ]),
            const RichAttributionWidget(
              alignment: AttributionAlignment.bottomLeft,
              attributions: [TextSourceAttribution('© OpenStreetMap contributors')],
            ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 100,
          child: FloatingActionButton(
            heroTag: 'myloc',
            onPressed: _myLocation,
            child: const Icon(Icons.my_location),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 24,
          child: FilledButton.icon(
            onPressed: pt == null ? null : () => Navigator.pop(context, pt),
            icon: const Icon(Icons.check),
            label: Text(pt == null ? 'Tap the map to choose' : 'Use this location'),
          ),
        ),
      ]),
    );
  }
}
