import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/geo.dart';
import '../../data/models/new_stop.dart';
import '../../data/models/user_profile.dart';
import '../../providers.dart';
import 'add_stop_sheet.dart';

class CreateRouteScreen extends ConsumerStatefulWidget {
  const CreateRouteScreen({super.key});
  @override
  ConsumerState<CreateRouteScreen> createState() => _CreateRouteScreenState();
}

class _CreateRouteScreenState extends ConsumerState<CreateRouteScreen> {
  UserProfile? _worker;
  DateTime _date = DateTime.now();
  final List<NewStop> _stops = [];
  bool _busy = false;

  Future<void> _add() async {
    final s = await showModalBottomSheet<NewStop>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const AddStopSheet(),
    );
    if (s != null) setState(() => _stops.add(s));
  }

  Future<void> _send() async {
    if (_worker == null || _stops.isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(routeRepoProvider).createRoute(
            workerId: _worker!.uid,
            workerName: _worker!.name,
            date: dateKey(_date),
            stops: _stops,
          );
      if (!mounted) return;
      setState(() => _stops.clear());
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Route for ${_worker!.name} on ${dateKey(_date)} sent')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteExistingRoute(String routeId, String workerName, String dateStr) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_forever, color: Colors.red, size: 36),
        title: const Text('Delete Route?'),
        content: Text(
          'Are you sure you want to delete the planned route for $workerName on $dateStr?\n\nThis will remove all planned stops for this date.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _busy = true);
      try {
        await ref.read(routeRepoProvider).deleteRoute(routeId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Route for $workerName on $dateStr deleted')),
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
        }
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final workers = ref.watch(workersProvider);
    final dateStr = dateKey(_date);
    final existingPlanAsync = _worker == null
        ? null
        : ref.watch(workerRouteProvider((workerId: _worker!.uid, date: dateStr)));

    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          workers.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (list) {
              if (list.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No workers registered yet. Workers can register using the app.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final selectedUid = list.any((w) => w.uid == _worker?.uid) ? _worker?.uid : null;
              return DropdownButtonFormField<String>(
                initialValue: selectedUid,
                decoration: const InputDecoration(labelText: 'Assign to worker'),
                items: [for (final w in list) DropdownMenuItem(value: w.uid, child: Text(w.name))],
                onChanged: (id) {
                  if (id == null) return;
                  setState(() => _worker = list.firstWhere((w) => w.uid == id));
                },
              );
            },
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.calendar_month),
                label: Text(DateFormat('EEE, d MMM yyyy').format(_date)),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime.now().subtract(const Duration(days: 30)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (d != null) setState(() => _date = d);
                },
              ),
            ),
          ]),
          if (existingPlanAsync != null) ...[
            existingPlanAsync.when(
              data: (plan) {
                if (plan == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.red),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Route exists for this date',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Text(
                                  '${_worker?.name} already has a route on $dateStr.',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Delete', style: TextStyle(fontSize: 12)),
                            onPressed: _busy
                                ? null
                                : () => _deleteExistingRoute(plan.id, _worker!.name, dateStr),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(),
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ]),
      ),
      Expanded(
        child: _stops.isEmpty
            ? const Center(child: Text('No stops yet. Tap "Add stop".'))
            : ReorderableListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _stops.length,
                onReorder: (o, n) => setState(() {
                  if (n > o) n -= 1;
                  _stops.insert(n, _stops.removeAt(o));
                }),
                itemBuilder: (_, i) {
                  final s = _stops[i];
                  return Card(
                    key: ValueKey(s),
                    child: ListTile(
                      leading: CircleAvatar(child: Text('${i + 1}')),
                      title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                          '${s.radiusM.round()} m radius • ₹${s.target.round()} • ${s.tasks.length} tasks'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => setState(() => _stops.removeAt(i)),
                      ),
                    ),
                  );
                },
              ),
      ),
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Add stop'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: (_busy || _worker == null || _stops.isEmpty) ? null : _send,
                icon: const Icon(Icons.send),
                label: const Text('Send route'),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }
}
