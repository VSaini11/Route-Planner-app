import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../core/geo.dart';
import '../../core/theme.dart';
import '../../data/models/route_plan.dart';
import '../../data/models/route_stop.dart';
import '../../providers.dart';
import '../../services/routing_service.dart';
import '../../services/tracking.dart';
import 'route_map_card.dart';
import 'stop_card.dart';

class MyRouteScreen extends ConsumerStatefulWidget {
  final bool permissionsOk;
  final Future<void> Function() onAskPermissions;
  const MyRouteScreen({super.key, required this.permissionsOk, required this.onAskPermissions});

  @override
  ConsumerState<MyRouteScreen> createState() => _MyRouteScreenState();
}

class _MyRouteScreenState extends ConsumerState<MyRouteScreen> {
  String _filter = 'all'; // all | pending | done
  bool _showMap = true;

  @override
  Widget build(BuildContext context) {
    final date = ref.watch(selectedDateProvider);
    final planAsync = ref.watch(routeProvider(dateKey(date)));
    final position = ref.watch(trackingProvider).position;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DateBar(date: date),
          const SizedBox(height: 14),
          if (!widget.permissionsOk) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kRed.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: kRed.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.location_off_rounded, color: kRed, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('GPS Permission Required',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: kRed)),
                        Text('Required for geofence check-ins & route tracking.',
                            style: TextStyle(fontSize: 11.5)),
                      ],
                    ),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: kRed,
                      minimumSize: const Size(70, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: widget.onAskPermissions,
                    child: const Text('Allow', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          ...planAsync.when(
            loading: () => [
              const Padding(
                padding: EdgeInsets.all(60),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
              )
            ],
            error: (e, _) => [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text('Error: $e', style: const TextStyle(color: kRed)),
              )
            ],
            data: (plan) => plan == null ? [_empty(context)] : _content(context, plan, position),
          ),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 80),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.alt_route_rounded, size: 48, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 16),
          const Text('No Route Assigned', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('You will receive a real-time notification once dispatched.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
        ]),
      );

  List<Widget> _content(BuildContext context, RoutePlan plan, Position? position) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stops = ref.watch(stopsProvider(plan.id)).valueOrNull ?? <RouteStop>[];
    final pointsWithMe = <LatLng>[
      if (position != null) LatLng(position.latitude, position.longitude),
      ...stops.map((s) => LatLng(s.lat, s.lng)),
    ];
    final key = pointsWithMe
        .map((s) => '${s.latitude.toStringAsFixed(4)},${s.longitude.toStringAsFixed(4)}')
        .join(';');
    final geo = pointsWithMe.length >= 2
        ? (ref.watch(routeGeometryProvider(key)).valueOrNull ??
            RouteGeometry.straight(pointsWithMe))
        : RouteGeometry.straight(pointsWithMe);

    // leg(i) = distance from stop i-1 to stop i
    double? leg(int i) => (i == 0 || i - 1 >= geo.legMeters.length) ? null : geo.legMeters[i - 1];

    var remaining = 0.0;
    for (var i = 1; i < stops.length; i++) {
      if (!stops[i].isDone) remaining += leg(i) ?? 0;
    }
    final doneCount = stops.where((s) => s.isDone).length;
    final pct = stops.isEmpty ? 0 : (doneCount * 100 / stops.length).round();

    final shown = stops.where((s) {
      if (_filter == 'pending') return !s.isDone;
      if (_filter == 'done') return s.isDone;
      return true;
    }).toList();

    return [
      if (_showMap && stops.isNotEmpty)
        RouteMapCard(
          stops: stops,
          geometry: geo,
          position: position,
          onOptimize: () => _optimize(plan, stops, position),
        ),
      if (_showMap && stops.isNotEmpty) const SizedBox(height: 14),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _FilterPill('All (${stops.length})', _filter == 'all', () => setState(() => _filter = 'all')),
          const SizedBox(width: 8),
          _FilterPill('Pending (${stops.length - doneCount})', _filter == 'pending',
              () => setState(() => _filter = 'pending')),
          const SizedBox(width: 8),
          _FilterPill('Done ($doneCount)', _filter == 'done', () => setState(() => _filter = 'done')),
          const SizedBox(width: 14),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onPressed: () => setState(() => _showMap = !_showMap),
            icon: Icon(_showMap ? Icons.visibility_off_outlined : Icons.map_outlined, size: 16),
            label: Text(_showMap ? 'Hide Map' : 'Show Map', style: const TextStyle(fontSize: 12)),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _Stat(Icons.route_rounded, kPrimary, 'TOTAL ROUTE', fmtKm(geo.totalMeters))),
        const SizedBox(width: 8),
        Expanded(child: _Stat(Icons.task_alt_rounded, kGreen, 'PROGRESS', '$doneCount/${stops.length} ($pct%)')),
        const SizedBox(width: 8),
        Expanded(child: _Stat(Icons.local_shipping_outlined, kAmber, 'REMAINING', fmtKm(remaining))),
      ]),
      const SizedBox(height: 20),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('ITINERARY TIMELINE',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 0.8,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          Text('${shown.length} STOPS',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
        ],
      ),
      const SizedBox(height: 12),
      for (final s in shown)
        _TimelineRow(
          number: stops.indexOf(s) + 1,
          isDone: s.isDone,
          isCheckedIn: s.isCheckedIn,
          isLast: identical(s, shown.last),
          child: StopCard(
            key: ValueKey(s.id),
            routeId: plan.id,
            stop: s,
            number: stops.indexOf(s) + 1,
            legMeters: leg(stops.indexOf(s)),
            position: position,
          ),
        ),
    ];
  }

  Future<void> _optimize(RoutePlan plan, List<RouteStop> stops, Position? position) async {
    final locked = stops.where((s) => s.isDone || s.isCheckedIn).toList();
    final pending = stops.where((s) => s.status == 'pending').toList();
    if (pending.length < 2) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Nothing to optimize')));
      return;
    }
    final LatLng start = locked.isNotEmpty
        ? LatLng(locked.last.lat, locked.last.lng)
        : (position != null
            ? LatLng(position.latitude, position.longitude)
            : LatLng(pending.first.lat, pending.first.lng));
    final order = nearestNeighborOrder(start, pending.map((s) => LatLng(s.lat, s.lng)).toList());
    final ids = [...locked.map((s) => s.id), ...order.map((i) => pending[i].id)];
    await ref.read(routeRepoProvider).updateOrder(plan.id, ids);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Route optimized with AI sequence ✓')));
    }
  }
}

class _DateBar extends ConsumerWidget {
  final DateTime date;
  const _DateBar({required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now();
    final isToday = dateKey(date) == dateKey(today);
    final isTomorrow = dateKey(date) == dateKey(today.add(const Duration(days: 1)));
    final notifier = ref.read(selectedDateProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('ASSIGNED SHIFT DATE',
                style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: kPrimary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isToday ? 'TODAY' : DateFormat('EEE').format(date).toUpperCase(),
                style: const TextStyle(color: kPrimary, fontWeight: FontWeight.w900, fontSize: 10.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          DateFormat('EEEE, d MMMM yyyy').format(date),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.3),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          _DateChip(label: 'Today', selected: isToday, onSelected: () => notifier.state = DateTime.now()),
          _DateChip(
              label: 'Tomorrow',
              selected: isTomorrow,
              onSelected: () => notifier.state = DateTime.now().add(const Duration(days: 1))),
          ActionChip(
            avatar: const Icon(Icons.calendar_month_outlined, size: 16),
            label: const Text('Calendar Picker', style: TextStyle(fontSize: 12)),
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (d != null) notifier.state = d;
            },
          ),
        ]),
      ]),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _DateChip({required this.label, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterPill(this.label, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? kPrimary
              : (isDark ? const Color(0xFF131D2E) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? kPrimary : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _Stat(this.icon, this.color, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900))),
      ]),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final int number;
  final bool isDone;
  final bool isCheckedIn;
  final bool isLast;
  final Widget child;
  const _TimelineRow({
    required this.number,
    required this.isDone,
    required this.isCheckedIn,
    required this.isLast,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDone ? kGreen : (isCheckedIn ? kPrimary : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)));

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            width: 36,
            child: Column(children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDone
                        ? [kGreen, const Color(0xFF059669)]
                        : isCheckedIn
                            ? [kPrimary, const Color(0xFF2563EB)]
                            : [isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0), isDark ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    if (isDone || isCheckedIn)
                      BoxShadow(
                        color: (isDone ? kGreen : kPrimary).withValues(alpha: 0.4),
                        blurRadius: 6,
                      ),
                  ],
                ),
                child: Center(
                  child: isDone
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : Text(
                          '$number',
                          style: TextStyle(
                            color: isCheckedIn ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF475569)),
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: color,
                  ),
                ),
            ]),
          ),
          const SizedBox(width: 8),
          Expanded(child: child),
        ]),
      ),
    );
  }
}
