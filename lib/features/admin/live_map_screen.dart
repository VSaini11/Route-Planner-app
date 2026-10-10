import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme.dart';
import '../../data/models/live_worker.dart';
import '../../providers.dart';

import '../common/realistic_car_marker.dart';

/// Admin sees every active worker as a car on the map, updated live.
class LiveMapScreen extends ConsumerStatefulWidget {
  const LiveMapScreen({super.key});
  @override
  ConsumerState<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends ConsumerState<LiveMapScreen> {
  final _c = MapController();
  bool _ready = false;
  bool _fitted = false;

  void _fit(List<LiveWorker> list) {
    if (!_ready || list.isEmpty) return;
    if (list.length == 1) {
      _c.move(LatLng(list.first.lat, list.first.lng), 15);
    } else {
      _c.fitCamera(CameraFit.coordinates(
        coordinates: list.map((w) => LatLng(w.lat, w.lng)).toList(),
        padding: const EdgeInsets.all(60),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(liveWorkersProvider).valueOrNull ?? <LiveWorker>[];

    if (!_fitted && _ready && list.isNotEmpty) {
      _fitted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fit(list));
    }

    return Column(children: [
      Expanded(
        child: FlutterMap(
          mapController: _c,
          options: MapOptions(
            initialCenter: const LatLng(28.6139, 77.2090),
            initialZoom: 10,
            onMapReady: () {
              _ready = true;
              if (mounted) setState(() {});
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.yourcompany.fieldroute',
            ),
            MarkerLayer(markers: [
              for (final w in list)
                Marker(
                  point: LatLng(w.lat, w.lng),
                  width: 100,
                  height: 90,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
                        ),
                        child: Text(
                          w.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11.5, fontWeight: FontWeight.w800, color: kNavy),
                        ),
                      ),
                      const SizedBox(height: 2),
                      RealisticCarMarker(
                        heading: w.heading,
                        size: 50,
                        isLive: !w.isStale,
                      ),
                    ],
                  ),
                ),
            ]),
            const RichAttributionWidget(
              alignment: AttributionAlignment.bottomLeft,
              attributions: [TextSourceAttribution('© OpenStreetMap contributors')],
            ),
          ],
        ),
      ),
      SizedBox(
        height: 150,
        child: list.isEmpty
            ? const Center(child: Text('No worker is sharing location right now'))
            : ListView(
                children: [
                  for (final w in list)
                    ListTile(
                      dense: true,
                      leading: Icon(Icons.circle, size: 14, color: w.isStale ? Colors.grey : kGreen),
                      title: Text(w.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(_ago(w.updatedAt)),
                      trailing: const Icon(Icons.my_location, size: 18),
                      onTap: () {
                        if (_ready) _c.move(LatLng(w.lat, w.lng), 16);
                      },
                    ),
                ],
              ),
      ),
    ]);
  }

  String _ago(DateTime? t) {
    if (t == null) return 'unknown';
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return 'updated just now';
    if (d.inMinutes < 60) return 'updated ${d.inMinutes} min ago';
    return 'updated ${d.inHours} h ago';
  }
}
