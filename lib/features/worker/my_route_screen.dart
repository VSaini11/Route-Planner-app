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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DateBar(date: date),
          const SizedBox(height: 12),
          if (!widget.permissionsOk) ...[
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.location_off),
                title: const Text('Location permission needed'),
                subtitle: const Text('Check-in and your live location will not work without it.'),
                trailing: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(80, 40)),
                  onPressed: widget.onAskPermissions,
                  child: const Text('Allow'),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          ...planAsync.when(
            loading: () => [const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))],
            error: (e, _) => [Center(child: Text('$e'))],
            data: (plan) => plan == null ? [_empty(context)] : _content(context, plan, position),
          ),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(children: [
          Icon(Icons.route_outlined, size: 72, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          const Text('No route planned for this date', style: TextStyle(fontSize: 18)),
          const Text('You will get a notification when your manager assigns one.'),
        ]),
      );

  List<Widget> _content(BuildContext context, RoutePlan plan, Position? position) {
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
      Row(children: [
        _FilterChip('All (${stops.length})', _filter == 'all', () => setState(() => _filter = 'all')),
        const SizedBox(width: 8),
        _FilterChip('Pending (${stops.length - doneCount})', _filter == 'pending',
            () => setState(() => _filter = 'pending')),
        const SizedBox(width: 8),
        _FilterChip('Done ($doneCount)', _filter == 'done', () => setState(() => _filter = 'done')),
        const Spacer(),
        TextButton.icon(
          onPressed: () => setState(() => _showMap = !_showMap),
          icon: Icon(_showMap ? Icons.visibility_off : Icons.map_outlined, size: 18),
          label: Text(_showMap ? 'Hide Map' : 'Show Map'),
        ),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _Stat(Icons.map_outlined, kBlue, 'TRIP TOTAL', fmtKm(geo.totalMeters))),
        const SizedBox(width: 8),
        Expanded(child: _Stat(Icons.check_circle_outline, kGreen, 'COMPLETED', '$doneCount/${stops.length} ($pct%)')),
        const SizedBox(width: 8),
        Expanded(child: _Stat(Icons.local_shipping_outlined, kAmber, 'REMAINING', fmtKm(remaining))),
      ]),
      const SizedBox(height: 20),
      Text('ASSIGNED ROUTE TIMELINE',
          style: TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
      const SizedBox(height: 10),
      for (final s in shown)
        _TimelineRow(
          number: stops.indexOf(s) + 1,
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

  /// Re-orders the stops that are still pending using nearest-neighbour from the
  /// worker's position (or the last finished stop). Finished stops keep their place.
  Future<void> _optimize(RoutePlan plan, List<RouteStop> stops, Position? position) async {
    final locked = stops.where((s) => s.isDone || s.isCheckedIn).toList();
    final pending = stops.where((s) => s.status == 'pending').toList();
    if (pending.length < 2) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Nothing to optimise')));
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
          .showSnackBar(const SnackBar(content: Text('Route optimised (shortest next stop first)')));
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('SCHEDULED ROUTE PLAN',
              style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 0.6,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(DateFormat('yyyy-MM-dd').format(date),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            ChoiceChip(
                label: const Text('Today'),
                selected: isToday,
                onSelected: (_) => notifier.state = DateTime.now()),
            ChoiceChip(
                label: const Text('Tomorrow'),
                selected: isTomorrow,
                onSelected: (_) => notifier.state = DateTime.now().add(const Duration(days: 1))),
            ActionChip(
              avatar: const Icon(Icons.calendar_month, size: 18),
              label: const Text('Calendar'),
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
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(this.label, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) =>
      ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap());
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _Stat(this.icon, this.color, this.label, this.value);

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 2),
            FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800))),
          ]),
        ),
      );
}

class _TimelineRow extends StatelessWidget {
  final int number;
  final bool isLast;
  final Widget child;
  const _TimelineRow({required this.number, required this.isLast, required this.child});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: 40,
              child: Column(children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: kNavy,
                  child: Text('$number',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: Theme.of(context).colorScheme.outlineVariant),
                  ),
              ]),
            ),
            Expanded(child: child),
          ]),
        ),
      );
}
