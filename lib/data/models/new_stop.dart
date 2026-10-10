import 'route_stop.dart';

/// A stop the admin is adding to a route (before it is saved).
class NewStop {
  final String name;
  final double lat;
  final double lng;
  final double radiusM;
  final double target;
  final List<StopTask> tasks;

  const NewStop({
    required this.name,
    required this.lat,
    required this.lng,
    required this.radiusM,
    required this.target,
    required this.tasks,
  });
}
