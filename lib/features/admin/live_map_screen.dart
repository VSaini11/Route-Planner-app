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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!_fitted && _ready && list.isNotEmpty) {
      _fitted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fit(list));
    }

    return Column(children: [
      Expanded(
        child: Stack(
          children: [
            FlutterMap(
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
                      width: 110,
                      height: 96,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: w.isStale ? Colors.grey : kPrimary,
                                width: 1.5,
                              ),
                              boxShadow: const [
                                BoxShadow(blurRadius: 8, color: Colors.black26, offset: Offset(0, 3)),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: w.isStale ? Colors.grey : kGreen,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    w.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : kNavy,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          RealisticCarMarker(
                            heading: w.heading,
                            size: 52,
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
            if (list.isNotEmpty)
              Positioned(
                top: 14,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: kGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${list.where((w) => !w.isStale).length} ACTIVE WORKERS',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      Container(
        height: 160,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            ),
          ),
        ),
        child: list.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.radar_outlined, size: 32, color: Theme.of(context).colorScheme.outline),
                    const SizedBox(height: 8),
                    const Text('No workers broadcasting location right now',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (_, i) {
                  final w = list[i];
                  return Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF131D2E) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (w.isStale ? Colors.grey : kGreen).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.directions_car_filled_rounded,
                            size: 16, color: w.isStale ? Colors.grey : kGreen),
                      ),
                      title: Text(w.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      subtitle: Text(_ago(w.updatedAt), style: const TextStyle(fontSize: 12)),
                      trailing: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: kPrimary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.my_location_rounded, size: 16, color: kPrimary),
                      ),
                      onTap: () {
                        if (_ready) _c.move(LatLng(w.lat, w.lng), 16);
                      },
                    ),
                  );
                },
              ),
      ),
    ]);
  }

  String _ago(DateTime? t) {
    if (t == null) return 'unknown';
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return 'Signal: Live (now)';
    if (d.inMinutes < 60) return 'Signal: ${d.inMinutes}m ago';
    return 'Signal: ${d.inHours}h ago';
  }
}
