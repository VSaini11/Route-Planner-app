import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/geo.dart';
import '../../core/theme.dart';
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
          SnackBar(
            content: Text('✓ Route for ${_worker!.name} on ${dateKey(_date)} successfully dispatched!'),
            backgroundColor: kGreen,
          ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: kRed));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteExistingRoute(String routeId, String workerName, String dateStr) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_forever_rounded, color: kRed, size: 38),
        title: const Text('Delete Existing Route?'),
        content: Text(
          'Are you sure you want to delete the planned route for $workerName on $dateStr?\n\nThis will permanently delete all associated stops.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Route'),
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
          SnackBar(content: Text('Route for $workerName on $dateStr deleted'), backgroundColor: kGreen),
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: kRed));
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final existingPlanAsync = _worker == null
        ? null
        : ref.watch(workerRouteProvider((workerId: _worker!.uid, date: dateStr)));

    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131D2E) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DISPATCH CONFIGURATION',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 0.8,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              workers.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('$e'),
                data: (list) {
                  if (list.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No registered workers. Workers can register using the app.',
                              style: TextStyle(fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  final selectedUid = list.any((w) => w.uid == _worker?.uid) ? _worker?.uid : null;
                  return DropdownButtonFormField<String>(
                    initialValue: selectedUid,
                    decoration: const InputDecoration(
                      labelText: 'Assign to Field Worker',
                      prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                    ),
                    items: [for (final w in list) DropdownMenuItem(value: w.uid, child: Text(w.name, style: const TextStyle(fontWeight: FontWeight.w600)))],
                    onChanged: (id) {
                      if (id == null) return;
                      setState(() => _worker = list.firstWhere((w) => w.uid == id));
                    },
                  );
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: const Icon(Icons.calendar_month_outlined, size: 20),
                label: Text(
                  DateFormat('EEEE, d MMMM yyyy').format(_date),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
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
              if (existingPlanAsync != null) ...[
                existingPlanAsync.when(
                  data: (plan) {
                    if (plan == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: kRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: kRed.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: kRed, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Active Route Assigned',
                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: kRed),
                                  ),
                                  Text(
                                    '${_worker?.name} already has a route for $dateStr.',
                                    style: const TextStyle(fontSize: 11.5),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: kRed,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: const Size(0, 36),
                              ),
                              icon: const Icon(Icons.delete_outline_rounded, size: 16),
                              label: const Text('Delete', style: TextStyle(fontSize: 12)),
                              onPressed: _busy
                                  ? null
                                  : () => _deleteExistingRoute(plan.id, _worker!.name, dateStr),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: LinearProgressIndicator(),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      ),
      Expanded(
        child: _stops.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: kPrimary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add_location_alt_outlined, size: 36, color: kPrimary),
                    ),
                    const SizedBox(height: 12),
                    const Text('No Stops Added Yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                      'Tap "+ Add Stop" below to build the sequence',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12.5),
                    ),
                  ],
                ),
              )
            : ReorderableListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _stops.length,
                onReorder: (o, n) => setState(() {
                  if (n > o) n -= 1;
                  _stops.insert(n, _stops.removeAt(o));
                }),
                itemBuilder: (_, i) {
                  final s = _stops[i];
                  return Container(
                    key: ValueKey(s),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF131D2E) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      leading: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: kPrimary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(fontWeight: FontWeight.w900, color: kPrimary, fontSize: 13),
                          ),
                        ),
                      ),
                      title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      subtitle: Text(
                        '${s.radiusM.round()}m radius • Target: ₹${s.target.round()} • ${s.tasks.length} tasks',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: kRed, size: 20),
                            onPressed: () => setState(() => _stops.removeAt(i)),
                          ),
                          const Icon(Icons.drag_indicator_rounded, color: Colors.grey, size: 20),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              ),
            ),
          ),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 50),
                ),
                onPressed: _add,
                icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                label: const Text('Add Stop'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                  ),
                ),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    minimumSize: const Size(0, 50),
                  ),
                  onPressed: (_busy || _worker == null || _stops.isEmpty) ? null : _send,
                  icon: _busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  label: Text(
                    _busy ? 'Dispatching...' : 'Dispatch Route',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }
}
