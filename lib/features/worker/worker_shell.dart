import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/geo.dart';
import '../../data/models/route_plan.dart';
import '../../providers.dart';
import '../../services/notification_service.dart';
import '../../services/permission_gate.dart';
import '../../services/tracking.dart';
import '../common/profile_screen.dart';
import 'my_route_screen.dart';

/// Bottom navigation + starts GPS tracking for TODAY's route once permissions are given.
class WorkerShell extends ConsumerStatefulWidget {
  const WorkerShell({super.key});
  @override
  ConsumerState<WorkerShell> createState() => _WorkerShellState();
}

class _WorkerShellState extends ConsumerState<WorkerShell> {
  int _tab = 0;
  bool _permissionsOk = false;
  RoutePlan? _todayPlan;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      NotificationService.instance.syncToken();
      final ok = await PermissionGate.ensure(context);
      if (!mounted) return;
      setState(() => _permissionsOk = ok);
      _sync();
    });
  }

  void _sync() {
    final tracking = ref.read(trackingProvider.notifier);
    final plan = _todayPlan ?? ref.read(routeProvider(dateKey(DateTime.now()))).valueOrNull;
    if (_permissionsOk) {
      tracking.start(plan, ref.read(profileProvider).valueOrNull?.name ?? 'Worker');
      tracking.updatePlan(plan);
    } else {
      tracking.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tracking always follows TODAY's route, whatever date the screen is showing.
    final todayPlanAsync = ref.watch(routeProvider(dateKey(DateTime.now())));
    _todayPlan = todayPlanAsync.valueOrNull;
    if (_todayPlan != null) {
      ref.watch(stopsProvider(_todayPlan!.id));
    }

    ref.listen<AsyncValue<RoutePlan?>>(routeProvider(dateKey(DateTime.now())), (_, next) {
      _todayPlan = next.valueOrNull;
      Future.microtask(() {
        if (mounted) _sync();
      });
    });

    return Scaffold(
      body: SafeArea(
        child: _tab == 0
            ? MyRouteScreen(
                permissionsOk: _permissionsOk,
                onAskPermissions: () async {
                  final ok = await PermissionGate.ensure(context);
                  if (!mounted) return;
                  setState(() => _permissionsOk = ok);
                  _sync();
                },
              )
            : const ProfileScreen(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.near_me_outlined), selectedIcon: Icon(Icons.near_me), label: 'My Route'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
